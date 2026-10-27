import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'ffmpeg_gateway.dart';
import 'storage_service.dart';

class MediaInfo {
  final double duration;
  final int width;
  final int height;
  final bool hasAudio;
  const MediaInfo({required this.duration, required this.width, required this.height, this.hasAudio = true});
}

/// Export quality tiers.
enum ExportQuality { high, medium, low }

/// v1.1 export settings — resolution ladder + fps + bitrate control.
class ExportSettings {
  final int width; // 0 = auto → source dims (capped to 2160)
  final int height;
  final int fps; // 24 | 30 | 60
  final ExportQuality quality;
  final double? customMbps; // overrides CRF when set

  const ExportSettings({
    this.width = 0,
    this.height = 0,
    this.fps = 30,
    this.quality = ExportQuality.high,
    this.customMbps,
  });
}

/// The media-processing engine: probe, thumbnails, trim, speed, reverse,
/// freeze, rotate/mirror/flip, crop, Ken-Burns, chroma-key, look filters,
/// manual grade (brightness/contrast/…/vignette/grain), pitch & EQ voice FX,
/// transitions (xfade), audio mixing, ASS caption burn-in and the staged
/// export pipeline with progress + cancellation.
class FfmpegService {
  FfmpegService._();
  static final instance = FfmpegService._();
  final _uuid = const Uuid();

  // Cancellation
  FFmpegSession? _current;
  void cancel() => _current?.cancel();

  // ---------------- Basics ----------------

  Future<MediaInfo> probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) {
      return const MediaInfo(duration: 0, width: 1920, height: 1080);
    }
    final streams = info.getStreams();
    var w = 0, h = 0;
    var hasAudio = false;
    for (final s in streams) {
      if (s.getType() == 'video') {
        w = int.tryParse('${s.getWidth()}') ?? 0;
        h = int.tryParse('${s.getHeight()}') ?? 0;
      } else if (s.getType() == 'audio') {
        hasAudio = true;
      }
    }
    final dur = double.tryParse('${info.getDuration()}') ?? 0;
    return MediaInfo(duration: dur, width: w == 0 ? 1920 : w, height: h == 0 ? 1080 : h, hasAudio: hasAudio);
  }

  Future<String> thumbnail(String videoPath, {double atSec = 0.5}) async {
    final dir = await StorageService.instance.tmpDir();
    final out = '${dir.path}/thumb_${_uuid.v4()}.jpg';
    await _run([
      '-y', '-ss', atSec.toStringAsFixed(2), '-i', videoPath,
      '-frames:v', '1', '-vf', 'scale=540:-2', '-q:v', '4', out,
    ]);
    return File(out).existsSync() ? out : '';
  }

  /// Extract audio track from a video (for "use this sound" flows).
  Future<String> extractAudio(String videoPath, {String format = 'm4a'}) async {
    final dir = await StorageService.instance.tmpDir();
    final out = '${dir.path}/audio_${_uuid.v4()}.$format';
    final codec = format == 'mp3' ? 'libmp3lame' : 'aac';
    await _run(['-y', '-i', videoPath, '-vn', '-c:a', codec, '-b:a', '192k', out]);
    return out;
  }

  /// Copy bundled caption fonts into a real dir so libass (fontsdir) can use them.
  Future<String> ensureFontsDir() async {
    final dir = Directory('${(await StorageService.instance.root()).path}/fonts');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    const fonts = [
      'assets/fonts/Tajawal-Regular.ttf', 'assets/fonts/Tajawal-Bold.ttf',
      'assets/fonts/Almarai-Regular.ttf', 'assets/fonts/Almarai-Bold.ttf',
      'assets/fonts/Anton-Regular.ttf', 'assets/fonts/BebasNeue-Regular.ttf',
      'assets/fonts/Lalezar-Regular.ttf',
    ];
    for (final a in fonts) {
      final name = p.basename(a);
      final f = File('${dir.path}/$name');
      if (!f.existsSync()) {
        final data = await rootBundle.load(a);
        await f.writeAsBytes(data.buffer.asUint8List());
      }
    }
    return dir.path;
  }

  // ---------------- Export pipeline ----------------

  /// Full export:
  ///  Stage A — normalize every clip (all v1.1 per-clip tools + looks + audio FX)
  ///  Stage B — concat with xfade transitions
  ///  Stage C — mix music + burn ASS captions (single encode)
  Future<String> exportProject({
    required List<Map<String, dynamic>> clipSpecs,
    required String outPath,
    required ExportSettings settings,
    required double totalDuration,
    String? assPath,
    List<Map<String, dynamic>> musicSpecs = const [],
    required void Function(double progress, String stage) onProgress,
  }) async {
    final tmp = await StorageService.instance.tmpDir();
    var targetW = settings.width;
    var targetH = settings.height;
    if (targetW <= 0 || targetH <= 0) {
      final info = await probe((clipSpecs.first['path'] as String?) ?? '');
      // cap "auto" to 4K and make both dims even
      final scale = math.min(1.0, 2160 / math.max(info.width, info.height));
      targetW = ((info.width * scale) ~/ 2) * 2;
      targetH = ((info.height * scale) ~/ 2) * 2;
      if (targetW < 2 || targetH < 2) {
        targetW = 1920;
        targetH = 1080;
      }
    }
    final crf = switch (settings.quality) {
      ExportQuality.high => '20',
      ExportQuality.medium => '25',
      ExportQuality.low => '30',
    };
    final useBitrate = settings.customMbps != null && settings.customMbps! > 0;
    final bitrate = useBitrate ? '${(settings.customMbps! * 1000).round()}k' : null;
    final fps = settings.fps;
    final stageWeights = <String, double>{'A': 0.45, 'B': 0.25, 'C': 0.30};
    var stageDone = 0.0;
    List<String> vEncode({required bool withAudio}) => [
          '-c:v', 'libx264', '-preset', 'veryfast',
          if (useBitrate) ...['-b:v', bitrate!] else ...['-crf', crf],
          '-pix_fmt', 'yuv420p',
          if (withAudio) ...['-c:a', 'aac', '-b:a', '160k', '-ar', '44100'],
        ];

    // ---- Stage A: normalize clips ----
    final normalized = <String>[];
    for (var i = 0; i < clipSpecs.length; i++) {
      final s = clipSpecs[i];
      final out = '${tmp}/norm_$i.mp4';
      final vf = _stageAVideoFilters(s, targetW, targetH, fps);
      final srcPath = s['path'] as String;
      final srcHasAudio = (await probe(srcPath)).hasAudio;
      final muted = s['mute'] == true || ((s['volume'] as double?) ?? 1.0) == 0;
      final speed = (s['speed'] as double?) ?? 1.0;
      final args = <String>[
        '-y',
        '-ss', (s['trimStart'] as double).toStringAsFixed(3),
        '-t', ((s['trimEnd'] as double) - (s['trimStart'] as double)).toStringAsFixed(3),
        '-i', srcPath,
      ];
      if (srcHasAudio) {
        // keep a (possibly silent) audio stream on every normalized clip so
        // downstream concat/mixing graphs always find [i:a]
        args.addAll(['-af', muted ? 'volume=0' : _stageAAudioFilters(s)]);
      } else {
        args.addAll([
          '-f', 'lavfi', '-i', 'anullsrc=r=44100:cl=stereo', '-shortest',
          '-map', '0:v', '-map', '1:a',
        ]);
      }
      args.addAll(['-vf', vf, ...vEncode(withAudio: true), out]);
      await _run(args, onTime: (t) {
        final clipDur = ((s['trimEnd'] as double) - (s['trimStart'] as double)) / speed +
            ((s['freezeDur'] as double?) ?? 0);
        onProgress(
          stageDone + stageWeights['A']! * (clipDur <= 0 ? 0 : (t / clipDur).clamp(0.0, 1.0) / clipSpecs.length),
          'A',
        );
      });
      normalized.add(out);
    }
    stageDone += stageWeights['A']!;
    onProgress(stageDone, 'A');

    // ---- Stage B: concat (+ xfade transitions) ----
    String base;
    if (normalized.length == 1) {
      base = normalized.first;
    } else {
      base = '${tmp}/concat.mp4';
      await _concatWithTransitions(normalized, clipSpecs, base, vEncode(withAudio: true),
          (t) => onProgress(stageDone + stageWeights['B']! * t, 'B'));
    }
    stageDone += stageWeights['B']!;
    onProgress(stageDone, 'B');

    // ---- Stage C: music mix + captions burn ----
    final hasMusic = musicSpecs.isNotEmpty;
    final hasAss = assPath != null && File(assPath).existsSync();
    final fontsDir = hasAss ? await ensureFontsDir() : null;

    if (!hasMusic && !hasAss) {
      await File(base).copy(outPath);
    } else {
      final args = <String>['-y', '-i', base];
      for (final m in musicSpecs) {
        args.addAll(['-i', m['path'] as String]);
      }
      final fc = StringBuffer();
      var audioIdx = 0; // 0 = main video audio
      if (hasMusic) {
        fc.write('[0:a]volume=1.0[a0];');
        for (var i = 0; i < musicSpecs.length; i++) {
          final m = musicSpecs[i];
          final vol = (m['volume'] as double?) ?? 0.8;
          final fadeIn = (m['fadeIn'] as double?) ?? 0.5;
          final fadeOut = (m['fadeOut'] as double?) ?? 1.0;
          final startAt = (m['startAt'] as double?) ?? 0;
          final dur = (m['duration'] as double?) ?? totalDuration;
          final adur = (dur - startAt).clamp(0.5, 1e9);
          fc.write(
              '[${i + 1}:a]volume=${vol.toStringAsFixed(2)},afade=t=in:st=0:d=${fadeIn.toStringAsFixed(2)},afade=t=out:st=${(adur - fadeOut).clamp(0, 1e9).toStringAsFixed(2)}:d=${fadeOut.toStringAsFixed(2)},adelay=${(startAt * 1000).round()}|${(startAt * 1000).round()}[m$i];');
        }
        final mixIns = [for (var i = 0; i <= musicSpecs.length; i++) 'a$i'].join('');
        fc.write('[$mixIns]amix=inputs=${musicSpecs.length + 1}:duration=first:dropout_transition=2:normalize=0[aout]');
        args.addAll(['-filter_complex', fc.toString(), '-map', '0:v', '-map', '[aout]']);
      } else {
        args.addAll(['-map', '0:v', '-map', '0:a?']);
      }
      if (hasAss) {
        final esc = _escapeForSubtitlesFilter(assPath);
        args.addAll([
          '-vf',
          "subtitles='$esc':fontsdir='$fontsDir'",
        ]);
      }
      args.addAll([...vEncode(withAudio: true), '-movflags', '+faststart', outPath]);
      await _run(args, onTime: (t) => onProgress(stageDone + stageWeights['C']! * (t / totalDuration).clamp(0.0, 1.0), 'C'));
    }
    onProgress(1.0, 'DONE');
    return outPath;
  }

  // ---------------- Stage-A video filter builder ----------------

  /// Builds the complete per-clip video filtergraph from a clip spec map.
  String _stageAVideoFilters(Map<String, dynamic> s, int W, int H, int fps) {
    final f = <String>[];
    final speed = (s['speed'] as double?) ?? 1.0;
    final reverse = s['reverse'] == true;

    // 1) timing: reverse → speed → freeze
    final srcLen = ((s['trimEnd'] as double) - (s['trimStart'] as double));
    if (reverse && srcLen <= 90) {
      f.add('reverse');
    }
    if (speed != 1.0) {
      f.add('setpts=${(1 / speed).toStringAsFixed(5)}*PTS');
    }
    final freeze = (s['freezeDur'] as double?) ?? 0;
    if (freeze > 0) {
      f.add('tpad=stop_mode=clone:stop_duration=${freeze.toStringAsFixed(2)}');
    }

    // 2) geometry: rotate → mirror/flip → crop → ken-burns
    final rotate = (s['rotate'] as int?) ?? 0;
    if (rotate == 90) f.add('transpose=1');
    if (rotate == 180) f.add('transpose=1,transpose=1');
    if (rotate == 270) f.add('transpose=2');
    if (s['mirror'] == true) f.add('hflip');
    if (s['flipV'] == true) f.add('vflip');
    final cropAspect = (s['cropAspect'] as double?) ?? 0;
    if (cropAspect > 0) {
      final ca = cropAspect.toStringAsFixed(4);
      f.add("crop=w='min(iw,ih*$ca)':h='min(ih,iw/$ca)'");
    }
    final kb = (s['kenBurns'] as String?) ?? '';
    if (kb.isNotEmpty) {
      final dur = srcLen / speed + freeze;
      final frames = (dur * fps).round().clamp(2, 100000);
      switch (kb) {
        case 'zoomIn':
          f.add("zoompan=z='min(1+0.22*in/$frames,1.25)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${W}x$H:fps=$fps");
          break;
        case 'zoomOut':
          f.add("zoompan=z='max(1.25-0.22*in/$frames,1.0)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=${W}x$H:fps=$fps");
          break;
        case 'panLeft':
          f.add("zoompan=z='1.25':x='(iw-iw/zoom)*(1-in/$frames)':y='(ih-ih/zoom)/2':d=1:s=${W}x$H:fps=$fps");
          break;
        case 'panRight':
          f.add("zoompan=z='1.25':x='(iw-iw/zoom)*(in/$frames)':y='(ih-ih/zoom)/2':d=1:s=${W}x$H:fps=$fps");
          break;
      }
    }

    // 3) chroma key (green screen)
    if (s['chromaEnabled'] == true) {
      final color = (s['chromaColor'] as String?) ?? '22DD44';
      final sim = ((s['chromaSimilarity'] as double?) ?? 0.14).toStringAsFixed(3);
      final blend = ((s['chromaBlend'] as double?) ?? 0.08).toStringAsFixed(3);
      f.add('chromakey=0x$color:$sim:$blend');
    }

    // 4) look filter (preset)
    if ((s['filter'] as String?)?.isNotEmpty == true) {
      f.add(s['filter'] as String);
    }

    // 5) manual grade
    final eqParts = <String>[];
    final brightness = (s['brightness'] as double?) ?? 0;
    final contrast = (s['contrast'] as double?) ?? 1;
    final saturation = (s['saturation'] as double?) ?? 1;
    if (brightness != 0) eqParts.add('brightness=${brightness.toStringAsFixed(3)}');
    if (contrast != 1) eqParts.add('contrast=${contrast.toStringAsFixed(3)}');
    if (saturation != 1) eqParts.add('saturation=${saturation.toStringAsFixed(3)}');
    if (eqParts.isNotEmpty) f.add('eq=${eqParts.join(':')}');
    final warmth = (s['warmth'] as double?) ?? 0;
    if (warmth != 0) {
      final w = warmth.toStringAsFixed(3);
      f.add('colorbalance=rs=${w}:bs=${(-warmth).toStringAsFixed(3)}');
    }
    final sharpen = (s['sharpen'] as double?) ?? 0;
    if (sharpen > 0) {
      f.add('unsharp=5:5:${sharpen.toStringAsFixed(2)}:5:5:0.0');
    }
    final vignette = (s['vignette'] as double?) ?? 0;
    if (vignette > 0) {
      f.add('vignette=angle=${(0.15 + vignette * 1.05).toStringAsFixed(3)}');
    }
    final grain = (s['grain'] as double?) ?? 0;
    if (grain > 0) {
      f.add('noise=alls=${(grain * 28).round()}:allf=t+u');
    }

    // 6) canvas: fps + (scale/pad) or blur-fill background
    f.add('fps=$fps');
    if (s['bgBlur'] == true) {
      f.add('split[bgsrc][fgsrc];'
          '[bgsrc]scale=$W:$H:force_original_aspect_ratio=increase,crop=$W:$H,gblur=sigma=20[bgb];'
          '[fgsrc]scale=$W:-2[fgs];'
          '[bgb][fgs]overlay=(W-w)/2:(H-h)/2');
    } else {
      f.add('scale=$W:$H:force_original_aspect_ratio=decrease');
      f.add('pad=$W:$H:(ow-iw)/2:(oh-ih)/2');
    }
    return f.join(',');
  }

  // ---------------- Stage-A audio filter builder ----------------

  String _stageAAudioFilters(Map<String, dynamic> s) {
    final parts = <String>[];
    if (s['reverse'] == true) parts.add('areverse');
    final speed = (s['speed'] as double?) ?? 1.0;
    final pitch = (s['pitch'] as double?) ?? 0;
    if (pitch != 0) {
      final ratio = math.pow(2.0, pitch / 12.0);
      final r = ratio.toStringAsFixed(5);
      // normalize → shift → compensate duration
      parts.add('aresample=48000');
      parts.add('asetrate=48000*$r');
      parts.add('aresample=48000');
      if (speed == 1.0) {
        parts.add('atempo=${(1 / ratio).toStringAsFixed(5)}');
      }
    }
    if (speed != 1.0) {
      parts.add(_atempoChain(speed));
    }
    final bass = (s['bass'] as double?) ?? 0;
    if (bass != 0) parts.add('bass=g=${bass.toStringAsFixed(1)}:f=110:w=0.6');
    final treble = (s['treble'] as double?) ?? 0;
    if (treble != 0) parts.add('treble=g=${treble.toStringAsFixed(1)}:f=8000:w=0.6');
    if (s['echo'] == true) parts.add('aecho=0.8:0.88:60|120:0.35|0.22');
    final vol = (s['volume'] as double?) ?? 1.0;
    parts.add('volume=${vol.toStringAsFixed(2)}');
    return parts.join(',');
  }

  String _atempoChain(double speed) {
    var s = speed.clamp(0.25, 4.0);
    final parts = <String>[];
    while (s > 2.0) {
      parts.add('atempo=2.0');
      s /= 2.0;
    }
    while (s < 0.5) {
      parts.add('atempo=0.5');
      s /= 0.5;
    }
    parts.add('atempo=${s.toStringAsFixed(4)}');
    return parts.join(',');
  }

  /// xfade chain across N normalized clips (+ acrossfade for audio).
  /// If any clip was exported without audio we fall back to video-only concat.
  Future<void> _concatWithTransitions(
    List<String> files,
    List<Map<String, dynamic>> specs,
    String out,
    List<String> encodeArgs,
    void Function(double) onProgress,
  ) async {
    final n = files.length;
    final allHaveAudio = !specs.any((s) => s['mute'] == true || ((s['volume'] as double?) ?? 1) == 0);
    final fc = StringBuffer();
    String prevV = '0:v';
    var prevA = '0:a';
    var cursor = 0.0;
    for (var i = 1; i < n; i++) {
      final spec = specs[i - 1];
      final tr = (spec['transition'] as Map?)?.cast<String, dynamic>() ?? {};
      final trId = (tr['id'] as String?) ?? '';
      final trDur = ((tr['duration'] as num?)?.toDouble()) ?? 0.6;
      final outV = i == n - 1 ? 'vout' : 'v$i';
      final outA = i == n - 1 ? 'aout' : 'a$i';
      final specDur = ((spec['trimEnd'] as double) - (spec['trimStart'] as double)) /
          ((spec['speed'] as double?) ?? 1.0);
      if (trId.isEmpty) {
        fc.write('[$prevV][$i:v]concat=n=2:v=1:a=0[$outV];');
        if (allHaveAudio) fc.write('[$prevA][$i:a]concat=n=2:v=0:a=1[$outA];');
        cursor += specDur;
      } else {
        cursor += specDur - trDur;
        fc.write('[$prevV][$i:v]xfade=transition=$trId:duration=${trDur.toStringAsFixed(2)}:offset=${cursor.clamp(0, 1e9).toStringAsFixed(2)}[$outV];');
        if (allHaveAudio) fc.write('[$prevA][$i:a]acrossfade=d=${trDur.toStringAsFixed(2)}[$outA];');
      }
      prevV = outV;
      prevA = outA;
    }
    final complex = fc.toString().replaceAll(RegExp(r';$'), '');
    final args = <String>[
      '-y',
      for (final f in files) ...['-i', f],
      '-filter_complex', complex,
      '-map', '[vout]',
      if (allHaveAudio) ...['-map', '[aout]'] else ...['-an'],
      ...encodeArgs,
      out,
    ];
    await _run(args, onTime: (t) => onProgress(0.5));
  }

  String _escapeForSubtitlesFilter(String path) {
    return path
        .replaceAll(r'\', r'\\')
        .replaceAll(':', r'\:')
        .replaceAll("'", r"\'")
        .replaceAll('[', r'\[')
        .replaceAll(']', r'\]');
  }

  // ---------------- Smart tools (AI-ish local analysis) ----------------

  /// Detect silent ranges [start, end] inside a media file.
  Future<List<List<double>>> detectSilences(String path,
      {double thresholdDb = -30, double minDur = 0.4}) async {
    final session = await FFmpegKit.execute(
        '-i "$path" -af silencedetect=noise=${thresholdDb.toStringAsFixed(0)}dB:d=${minDur.toStringAsFixed(2)} -f null -');
    final logs = await session.getAllLogsAsString() ?? '';
    final starts = RegExp(r'silence_start:\s*([0-9.]+)').allMatches(logs).map((m) => double.parse(m.group(1)!)).toList();
    final ends = RegExp(r'silence_end:\s*([0-9.]+)').allMatches(logs).map((m) => double.parse(m.group(1)!)).toList();
    final out = <List<double>>[];
    for (var i = 0; i < starts.length; i++) {
      out.add([starts[i], i < ends.length ? ends[i] : -1]);
    }
    return out;
  }

  /// Detect scene-change timestamps inside a media file.
  Future<List<double>> detectScenes(String path, {double threshold = 0.3}) async {
    final session = await FFmpegKit.execute(
        '-i "$path" -vf "select=gt(scene\\,${threshold.toStringAsFixed(2)}),showinfo" -f null -');
    final logs = await session.getAllLogsAsString() ?? '';
    return RegExp(r'pts_time:([0-9.]+)')
        .allMatches(logs)
        .map((m) => double.parse(m.group(1)!))
        .toList();
  }

  // ---------------- Runner ----------------

  Future<void> _run(List<String> args, {void Function(double seconds)? onTime}) async {
    final cmd = args.join(' ');
    if (onTime != null) {
      FFmpegKitConfig.enableStatisticsCallback((stats) {
        onTime(stats.getTime() / 1000.0);
      });
    }
    final session = await FFmpegKit.execute(cmd);
    _current = session;
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      final logs = await session.getAllLogsAsString();
      throw Exception('FFmpeg failed (${rc?.getValue()}): ${_tail(logs, 800)}');
    }
    if (onTime != null) {
      try {
        FFmpegKitConfig.enableStatisticsCallback((_) {});
      } catch (_) {}
    }
  }

  String _tail(String? s, int n) {
    if (s == null) return '';
    return s.length <= n ? s : s.substring(s.length - n);
  }
}
