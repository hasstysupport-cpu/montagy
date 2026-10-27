import 'dart:io';

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

/// The media-processing engine: probe, thumbnails, trim, speed, filters,
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
  ///  Stage A — normalize every clip (trim, speed, filter, volume, size, fps)
  ///  Stage B — concat with xfade transitions
  ///  Stage C — mix music + burn ASS captions (single encode)
  Future<String> exportProject({
    required List<Map<String, dynamic>> clipSpecs, // see editor_controller.buildExportSpecs
    required String outPath,
    required int targetW,
    required int targetH,
    required double totalDuration, // timeline seconds (A+B)
    required ExportQuality quality,
    String? assPath,
    List<Map<String, dynamic>> musicSpecs = const [],
    required void Function(double progress, String stage) onProgress,
  }) async {
    final tmp = await StorageService.instance.tmpDir();
    final crf = switch (quality) {
      ExportQuality.high => '20',
      ExportQuality.medium => '25',
      ExportQuality.low => '30',
    };
    final stageWeights = <String, double>{'A': 0.45, 'B': 0.25, 'C': 0.30};
    var stageDone = 0.0;

    // ---- Stage A: normalize clips ----
    final normalized = <String>[];
    for (var i = 0; i < clipSpecs.length; i++) {
      final s = clipSpecs[i];
      final out = '${tmp}/norm_$i.mp4';
      final filters = <String>[
        'fps=30',
        'scale=$targetW:$targetH:force_original_aspect_ratio=decrease',
        'pad=$targetW:$targetH:(ow-iw)/2:(oh-ih)/2',
        if ((s['filter'] as String?)?.isNotEmpty == true) s['filter'] as String,
      ];
      final speed = (s['speed'] as double?) ?? 1.0;
      final args = <String>[
        '-y',
        '-ss', (s['trimStart'] as double).toStringAsFixed(3),
        '-t', ((s['trimEnd'] as double) - (s['trimStart'] as double)).toStringAsFixed(3),
        '-i', s['path'] as String,
      ];
      if (speed != 1.0) {
        filters.add('setpts=${(1 / speed).toStringAsFixed(5)}*PTS');
      }
      final vol = (s['volume'] as double?) ?? 1.0;
      if (s['mute'] == true || vol == 0) {
        args.addAll(['-an']);
      } else {
        args.addAll([
          '-af',
          if (speed != 1.0) '${_atempoChain(speed)},volume=${vol.toStringAsFixed(2)}' else 'volume=${vol.toStringAsFixed(2)}',
        ]);
      }
      args.addAll([
        '-vf', filters.join(','),
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', crf, '-pix_fmt', 'yuv420p',
        if (s['mute'] != true && vol != 0) ...['-c:a', 'aac', '-b:a', '128k', '-ar', '44100'],
        out,
      ]);
      await _run(args, onTime: (t) {
        final clipDur = ((s['trimEnd'] as double) - (s['trimStart'] as double)) / speed;
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
      await _concatWithTransitions(normalized, clipSpecs, base, crf,
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
        // main audio
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
              '[$audioIdx:a]volume=${vol.toStringAsFixed(2)},afade=t=in:st=0:d=${fadeIn.toStringAsFixed(2)},afade=t=out:st=${(adur - fadeOut).clamp(0, 1e9).toStringAsFixed(2)}:d=${fadeOut.toStringAsFixed(2)},adelay=${(startAt * 1000).round()}|${(startAt * 1000).round()}[m$i];');
          audioIdx++;
        }
        final mixIns = [for (var i = 0; i <= musicSpecs.length; i++) 'a$i'].join('');
        fc.write('[$mixIns]amix=inputs=${musicSpecs.length + 1}:duration=first:dropout_transition=2[aout]');
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
      args.addAll([
        '-c:v', 'libx264', '-preset', 'veryfast', '-crf', crf, '-pix_fmt', 'yuv420p',
        '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', outPath,
      ]);
      await _run(args, onTime: (t) => onProgress(stageDone + stageWeights['C']! * (t / totalDuration).clamp(0.0, 1.0), 'C'));
    }
    onProgress(1.0, 'DONE');
    return outPath;
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
    String crf,
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
      '-c:v', 'libx264', '-preset', 'veryfast', '-crf', crf, '-pix_fmt', 'yuv420p',
      if (allHaveAudio) ...['-c:a', 'aac', '-b:a', '128k'],
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
