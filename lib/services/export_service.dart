import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/color_engine.dart';
import '../data/models.dart';
import 'ffmpeg_gateway.dart';
import 'overlay_renderer.dart';
import 'projects_store.dart';

/// نتيجة التصدير.
class ExportResult {
  final String? outputPath;
  final String? error;
  final String? logTail;
  final bool cancelled;
  ExportResult({this.outputPath, this.error, this.logTail, this.cancelled = false});
}

/// تقدم التصدير.
class ExportProgress {
  final double value; // 0..1
  final String phase;
  ExportProgress(this.value, this.phase);
}

/// مهمة تصدير.
class ExportJob {
  final Project project;
  final int height;
  final int fps;
  final int crf;
  final void Function(ExportProgress progress) onProgress;
  final bool Function() isCancelled;
  final void Function(String line)? onLog;

  ExportJob({
    required this.project,
    required this.height,
    required this.fps,
    required this.crf,
    required this.onProgress,
    required this.isCancelled,
    this.onLog,
  });
}

/// محرك التصدير الحقيقي — FFmpeg على مراحل:
/// 1) توحيد كل مقطع (فلتر/سرعة/تدوير/اقتصاص/كانفس/صوت) → cl{n}.mp4
/// 2) دمج المقاطع (concat copy أو xfade/acrossfade للانتقالات) → base.mp4
/// 3) الطبقات (نص/ملصق PNG) + خلط الصوت → final.mp4
class ExportService {
  /// الأبعاد النهائية (أعداد زوجية).
  static (int, int) canvasSize(AspectKind aspect, int height) {
    final h = (height / 2).ceil() * 2;
    var w = (h * aspect.ratio).round();
    w = (w / 2).ceil() * 2;
    if (w > 4096) w = 4096;
    return (w, h);
  }

  static String _lastLog = '';

  static Future<ExportResult> run(ExportJob job) async {
    final project = job.project;
    if (project.clips.isEmpty) {
      return ExportResult(error: 'لا توجد مقاطع للتصدير');
    }
    final (W, H) = canvasSize(project.canvas.aspect, job.height);

    final tmpBase = await getTemporaryDirectory();
    final work = Directory(p.join(tmpBase.path, 'montagy_export'));
    if (work.existsSync()) work.deleteSync(recursive: true);
    work.createSync(recursive: true);
    final wd = work.path;

    void report(double v, String phase) =>
        job.onProgress(ExportProgress(v.clamp(0, 1), phase));

    Future<ExportResult> fail(String msg) async {
      final logs = _lastLog;
      if (logs.isNotEmpty) {
        try {
          final tmp = await getTemporaryDirectory();
          final tail = logs.length > 20000 ? logs.substring(logs.length - 20000) : logs;
          await File(p.join(tmp.path, 'montagy_export_error.log')).writeAsString(tail);
        } catch (_) {}
      }
      try { work.deleteSync(recursive: true); } catch (_) {}
      return ExportResult(error: msg, logTail: logs.length > 900 ? logs.substring(logs.length - 900) : logs);
    }

    try {
      report(0.01, 'تجهيز المشروع...');

      final clips =
          project.clips.where((c) => File(c.sourcePath).existsSync()).toList();
      if (clips.isEmpty) return ExportResult(error: 'ملفات المقاطع غير موجودة');

      // حسابات التايم لاين
      final durs = clips.map((c) => c.timelineDuration).toList();
      final trans = <(bool, double)>[];
      for (var i = 0; i < clips.length - 1; i++) {
        final hasT = clips[i].transitionOutId != null;
        double td = 0;
        if (hasT) {
          td = clips[i].transitionDuration.clamp(0.15, 2.0);
          final m = math.min(durs[i], durs[i + 1]);
          td = td.clamp(0.15, m / 2.2).toDouble();
        }
        trans.add((hasT, td));
      }
      var t = 0.0;
      for (var i = 0; i < clips.length; i++) {
        t += durs[i] - (i < trans.length ? trans[i].$2 : 0);
      }
      final total = t;
      if (total <= 0.2) return ExportResult(error: 'مدة المشروع قصيرة جداً');
      final totalSrcDur =
          clips.fold<double>(0, (a, c) => a + math.max(c.trimDuration, 0.01));

      // ── الطبقات → PNG ──
      final overlaySpecs = <OverlaySpec>[];
      var pngIndex = 0;
      for (final txt in project.texts) {
        if (txt.text.trim().isEmpty) continue;
        if (job.isCancelled()) return _cancelled(work);
        final f = await OverlayRenderer.renderText(
          txt,
          frameW: W,
          frameH: H,
          outPath: p.join(wd, 'ov$pngIndex.png'),
        );
        overlaySpecs.add(await OverlaySpec.fromOverlay(
            txt.start, txt.end, txt.nx, txt.ny, txt.animIn, txt.animOut,
            txt.animDur, f.path));
        pngIndex++;
      }
      for (final st in project.overlays) {
        if (job.isCancelled()) return _cancelled(work);
        if (st.emoji != null) {
          final f = await OverlayRenderer.renderEmoji(
            st.emoji!,
            relScale: st.scale,
            frameH: H,
            outPath: p.join(wd, 'ov$pngIndex.png'),
          );
          overlaySpecs.add(await OverlaySpec.fromOverlay(
              st.start, st.end, st.nx, st.ny, st.animIn, st.animOut,
              st.animDur, f.path));
        } else if (st.imagePath != null && File(st.imagePath!).existsSync()) {
          final f = await OverlayRenderer.renderImage(
            st.imagePath!,
            relScale: st.scale,
            frameH: H,
            rotationDeg: st.rotation,
            outPath: p.join(wd, 'ov$pngIndex.png'),
          );
          overlaySpecs.add(await OverlaySpec.fromOverlay(
              st.start, st.end, st.nx, st.ny, st.animIn, st.animOut,
              st.animDur, f.path));
        }
        pngIndex++;
      }
      report(0.04, 'تجهيز المشروع...');

      // ── توحيد المقاطع ──
      for (var i = 0; i < clips.length; i++) {
        if (job.isCancelled()) return _cancelled(work);
        final ok = await _transcodeClip(
          job: job,
          clip: clips[i],
          W: W,
          H: H,
          fps: job.fps,
          crf: job.crf,
          bg: project.canvas,
          outPath: p.join(wd, 'cl$i.mp4'),
        );
        if (!ok) {
          return fail('فشل معالجة المقطع ${i + 1} (${clips[i].title})');
        }
        final frac = math
            .max(clips[i].trimDuration, 0.01 / totalSrcDur) /
            totalSrcDur;
        report(0.04 + frac * 0.60, 'معالجة المقاطع ${i + 1}/${clips.length}');
      }

      // ── الدمج ──
      final hasAnyTransition = trans.any((e) => e.$1);
      final String base;
      if (clips.length == 1) {
        base = p.join(wd, 'cl0.mp4');
      } else if (!hasAnyTransition) {
        final listFile = File(p.join(wd, 'list.txt'));
        final buf = StringBuffer();
        for (var i = 0; i < clips.length; i++) {
          buf.writeln("file '${p.join(wd, 'cl$i.mp4')}'");
        }
        await listFile.writeAsString(buf.toString());
        base = p.join(wd, 'base.mp4');
        final rc = await _run(job, [
          '-y', '-f', 'concat', '-safe', '0',
          '-i', listFile.path,
          '-c', 'copy',
          base,
        ]);
        if (rc != 0) return fail('فشل دمج المقاطع');
      } else {
        base = p.join(wd, 'base.mp4');
        final args = _buildMergeArgs(clips, durs, trans, wd, base, job.fps, job.crf);
        final rc = await _run(job, args);
        if (rc != 0) return fail('فشل دمج المقاطع (انتقالات)');
      }
      report(0.80, 'تجميع المونتاج...');

      // ── الطبقات + الصوت ──
      final audioTracks = project.audio
          .where((a) => File(a.path).existsSync() && a.duration > 0.08)
          .toList();

      final outputs = await ProjectsStore.exportsDir();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final safeName =
          project.name.replaceAll(RegExp(r'[^a-zA-Z0-9\-\u0600-\u06FF]'), '_');
      final finalPath = p.join(outputs.path, '${safeName}_$stamp.mp4');

      String resultPath;
      if (overlaySpecs.isNotEmpty || audioTracks.isNotEmpty) {
        final args = _buildFinalArgs(
          base: base,
          overlays: overlaySpecs,
          audio: audioTracks,
          total: total,
          fps: job.fps,
          crf: job.crf,
          outPath: finalPath,
        );
        final rc = await _run(job, args);
        if (rc != 0) return fail('فشل التجميع النهائي');
        resultPath = finalPath;
      } else {
        await File(base).copy(finalPath);
        resultPath = finalPath;
      }
      report(1.0, 'اكتمل ✓');

      try { work.deleteSync(recursive: true); } catch (_) {}
      return ExportResult(outputPath: resultPath);
    } catch (e) {
      return fail('استثناء أثناء التصدير: $e');
    }
  }

  static ExportResult _cancelled(Directory work) {
    try { work.deleteSync(recursive: true); } catch (_) {}
    return ExportResult(cancelled: true);
  }

  // ───────────────────────────────────────────
  // المرحلة 1: توحيد مقطع واحد
  // ───────────────────────────────────────────
  static Future<bool> _transcodeClip({
    required ExportJob job,
    required ClipItem clip,
    required int W,
    required int H,
    required int fps,
    required int crf,
    required CanvasSettings bg,
    required String outPath,
  }) async {
    final srcDur = clip.type == MediaType.photo ? clip.photoDuration : clip.trimDuration;
    final timelineDur = clip.timelineDuration;

    final inputs = <String>[];
    if (clip.type == MediaType.photo) {
      inputs.addAll(['-loop', '1', '-t', _n(srcDur + 0.6), '-i', clip.sourcePath]);
    } else {
      inputs.addAll(['-ss', _n(clip.inPoint), '-i', clip.sourcePath]);
    }
    // صمت مضمون دائماً كمدخل 1
    inputs.addAll([
      '-f', 'lavfi', '-t', _n(timelineDur + 1),
      '-i', 'anullsrc=r=44100:cl=stereo',
    ]);

    // ── سلسلة الفيديو ──
    final pre = <String>[
      'trim=duration=${_n(srcDur)}',
      'setpts=PTS-STARTPTS',
      if (clip.reversed) 'reverse',
      if (clip.rotation == 90) 'transpose=1',
      if (clip.rotation == 180) ...['transpose=1', 'transpose=1'],
      if (clip.rotation == 270) 'transpose=2',
      if (clip.flipH) 'hflip',
      if (clip.flipV) 'vflip',
      if (clip.crop != null)
        'crop=w=iw*${_n(clip.crop!.width)}:h=ih*${_n(clip.crop!.height)}'
            ':x=iw*${_n(clip.crop!.left)}:y=ih*${_n(clip.crop!.top)}',
      if (clip.speed != 1) 'setpts=${_n(1 / clip.speed)}*PTS',
    ];

    final colorChain = ColorFilterResolver.ffmpegChain(
      presetId: clip.filterPreset,
      intensity: clip.filterIntensity,
      adjust: clip.adjust,
    );
    final post = <String>[
      if (colorChain.isNotEmpty) colorChain,
      'fps=$fps',
      'format=yuv420p',
    ];

    final String vChain;
    if (bg.bg == CanvasBg.blur) {
      vChain = '[0:v]${pre.join(',')},split=2[bg][fg];'
          '[bg]scale=$W:$H:force_original_aspect_ratio=increase,'
          'crop=$W:$H,boxblur=22:2,setsar=1[bgo];'
          '[fg]scale=$W:$H:force_original_aspect_ratio=decrease,setsar=1[fgo];'
          '[bgo][fgo]overlay=(W-w)/2:(H-h)/2:eval=init'
          '${post.isEmpty ? '' : ',${post.join(',')}'}[v]';
    } else {
      vChain = '[0:v]${[...pre,
        'scale=$W:$H:force_original_aspect_ratio=decrease,setsar=1',
        'pad=$W:$H:(ow-iw)/2:(oh-ih)/2:color=${_bgColorHex(bg)}',
        ...post,
      ].join(',')}[v]';
    }

    // ── سلسلة الصوت ──
    final String aChain;
    if (clip.type == MediaType.video && clip.hasAudio) {
      final af = <String>[
        'atrim=duration=${_n(srcDur)}',
        'asetpts=PTS-STARTPTS',
        if (clip.reversed) 'areverse',
        ..._atempoChain(clip.speed),
        'volume=${_n(clip.muted ? 0.0 : clip.volume)}',
        'aresample=44100',
        'aformat=sample_fmts=fltp:channel_layouts=stereo',
      ];
      aChain = '[0:a]${af.join(',')}[a]';
    } else {
      aChain = '[1:a]atrim=duration=${_n(timelineDur + 0.1)},asetpts=PTS-STARTPTS,'
          'aformat=sample_fmts=fltp:channel_layouts=stereo[a]';
    }

    final args = <String>[
      '-y',
      ...inputs,
      '-filter_complex', '$vChain;$aChain',
      '-map', '[v]',
      '-map', '[a]',
      '-t', _n(timelineDur + 0.05),
      '-r', '$fps',
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', '$crf',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '160k',
      '-ar', '44100',
      '-ac', '2',
      outPath,
    ];
    final rc = await _run(job, args);
    return rc == 0;
  }

  // ───────────────────────────────────────────
  // المرحلة 2: الدمج مع الانتقالات
  // ───────────────────────────────────────────
  static List<String> _buildMergeArgs(
    List<ClipItem> clips,
    List<double> durs,
    List<(bool, double)> trans,
    String wd,
    String outPath,
    int fps,
    int crf,
  ) {
    final args = <String>['-y'];
    for (var i = 0; i < clips.length; i++) {
      args.addAll(['-i', p.join(wd, 'cl$i.mp4')]);
    }
    final fc = <String>[];
    var vLabel = '[0:v]';
    var aLabel = '[0:a]';
    var visible = durs[0];
    for (var i = 0; i < clips.length - 1; i++) {
      final nextV = '[mv$i]';
      final nextA = '[ma$i]';
      if (trans[i].$1) {
        final off = visible - trans[i].$2;
        fc.add('$vLabel[${i + 1}:v]xfade='
            'transition=${_xfadeName(clips[i].transitionOutId)}:'
            'duration=${_n(trans[i].$2)}:offset=${_n(off)}$nextV');
        fc.add('$aLabel[${i + 1}:a]acrossfade=d=${_n(trans[i].$2)}$nextA');
      } else {
        fc.add('$vLabel[${i + 1}:v]concat=n=2:v=1:a=0$nextV');
        fc.add('$aLabel[${i + 1}:a]concat=n=2:v=0:a=1$nextA');
      }
      vLabel = nextV;
      aLabel = nextA;
      visible = visible + durs[i + 1] - trans[i].$2;
    }
    args.addAll([
      '-filter_complex', fc.join(';'),
      '-map', vLabel,
      '-map', aLabel,
      '-r', '$fps',
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', '$crf',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '160k',
      '-ar', '44100',
      outPath,
    ]);
    return args;
  }

  static String _xfadeName(String? id) {
    switch (id) {
      case 'slideleft': return 'slideleft';
      case 'wiperight': return 'wiperight';
      case 'circleopen': return 'circleopen';
      case 'dissolve': return 'dissolve';
      case 'smoothleft': return 'smoothleft';
      case 'zoomin': return 'zoomin';
      case 'pixelize': return 'pixelize';
      case 'radial': return 'radial';
      default: return 'fade';
    }
  }

  // ───────────────────────────────────────────
  // المرحلة 3: الطبقات + خلط الصوت
  // ───────────────────────────────────────────
  static List<String> _buildFinalArgs({
    required String base,
    required List<OverlaySpec> overlays,
    required List<AudioTrack> audio,
    required double total,
    required int fps,
    required int crf,
    required String outPath,
  }) {
    final args = <String>['-y', '-i', base];
    for (final ov in overlays) {
      args.addAll(['-loop', '1', '-t', _n(total + 0.3), '-i', ov.pngPath]);
    }
    for (final tr in audio) {
      args.addAll([
        '-ss', _n(tr.inPoint),
        '-t', _n(tr.duration + 0.05),
        '-i', tr.path,
      ]);
    }

    final fc = <String>[];

    // سلاسل PNG (شفافية + تلاشي)
    for (var k = 0; k < overlays.length; k++) {
      final ov = overlays[k];
      final chain = <String>['format=rgba'];
      if (ov.animIn != TextAnim.none && ov.animDur > 0.02) {
        chain.add('fade=t=in:st=${_n(ov.start)}:d=${_n(ov.animDur)}:alpha=1');
      }
      if (ov.animOut != TextAnim.none && ov.animDur > 0.02) {
        final st = ov.end - ov.animDur;
        if (st > ov.start + 0.05) {
          chain.add('fade=t=out:st=${_n(st)}:d=${_n(ov.animDur)}:alpha=1');
        }
      }
      fc.add('[${1 + k}:v]${chain.join(',')}[ov$k]');
    }

    // سلسلة التركيب
    var vLabel = '[0:v]';
    for (var k = 0; k < overlays.length; k++) {
      final ov = overlays[k];
      final isLast = k == overlays.length - 1;
      final next = isLast ? '[vout]' : '[vo$k]';
      fc.add('$vLabel[ov$k]overlay=x=${ov.xExpr()}:y=${ov.yExpr()}:'
          'enable=${_between(ov.start, ov.end)}$next');
      vLabel = next;
    }

    // سلسلة الصوت
    var aOut = '[0:a]';
    if (audio.isNotEmpty) {
      final mixLabels = <String>['[0:a]'];
      final audioBase = 1 + overlays.length;
      for (var m = 0; m < audio.length; m++) {
        final tr = audio[m];
        final chain = <String>[
          'atrim=duration=${_n(tr.duration)}',
          'asetpts=PTS-STARTPTS',
          'volume=${_n(tr.volume)}',
        ];
        if (tr.fadeIn > 0.05) {
          chain.add('afade=t=in:st=0:d=${_n(tr.fadeIn)}');
        }
        if (tr.fadeOut > 0.05) {
          chain.add(
              'afade=t=out:st=${_n(math.max(tr.duration - tr.fadeOut, 0))}:d=${_n(tr.fadeOut)}');
        }
        final delayMs = (tr.startAt * 1000).round();
        if (delayMs > 0) chain.add('adelay=$delayMs:all=1');
        fc.add('[${audioBase + m}:a]${chain.join(',')}[am$m]');
        mixLabels.add('[am$m]');
      }
      aOut = '[aout]';
      fc.add('${mixLabels.join()}amix=inputs=${mixLabels.length}:'
          'duration=first:normalize=0$aOut');
    }

    args.addAll([
      '-filter_complex', fc.join(';'),
      '-map', vLabel,
      '-map', aOut,
      '-t', _n(total + 0.05),
      '-r', '$fps',
      '-c:v', 'libx264',
      '-preset', 'veryfast',
      '-crf', '$crf',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '160k',
      '-ar', '44100',
      outPath,
    ]);
    return args;
  }

  static String _between(double a, double b) => "'between(t,${_n(a)},${_n(b)})'";

  // ── تشغيل FFmpeg ──
  static Future<int> _run(ExportJob job, List<String> args) async {
    final buf = StringBuffer();
    final completer = Completer<int>();

    await FFmpegKit.executeWithArgumentsAsync(
      args,
      (s) async {
        final rc = await s.getReturnCode();
        final code = rc?.getValue() ?? -1;
        if (!completer.isCompleted) completer.complete(code);
      },
      (log) {
        final line = log.getMessage();
        buf.writeln(line);
        if (buf.length > 80000) {
          final s = buf.toString();
          buf.clear();
          buf.writeln('...\n${s.substring(s.length - 40000)}');
        }
      },
      (stats) {
        job.onLog?.call('${stats.getTime()}ms');
      },
    );
    final rc = await completer.future;
    _lastLog = buf.toString();
    if (job.isCancelled()) {
      try { await FFmpegKit.cancel(); } catch (_) {}
    }
    return rc;
  }

  static List<String> _atempoChain(double speed) {
    if ((speed - 1).abs() < 0.001) return [];
    final parts = <String>[];
    var s = speed;
    while (s > 2.001) {
      parts.add('atempo=2.0');
      s /= 2.0;
    }
    while (s < 0.499) {
      parts.add('atempo=0.5');
      s *= 2.0;
    }
    parts.add('atempo=${_n(s)}');
    return parts;
  }

  static String _n(double v) {
    if (v.isNaN || v.isInfinite) return '0';
    var s = v.toStringAsFixed(3);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    if (s.isEmpty || s == '-' || s == '-0') s = '0';
    return s;
  }

  static String _bgColorHex(CanvasSettings bg) {
    switch (bg.bg) {
      case CanvasBg.white: return 'white';
      case CanvasBg.custom: return '0x${_hex(bg.customColor)}';
      default: return 'black';
    }
  }

  static String _hex(Color c) =>
      c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
}

/// مواصفات طبقة جاهزة للتركيب.
class OverlaySpec {
  final String pngPath;
  final double start, end;
  final double nx, ny;
  final TextAnim animIn, animOut;
  final double animDur;

  OverlaySpec({
    required this.pngPath,
    required this.start,
    required this.end,
    required this.nx,
    required this.ny,
    required this.animIn,
    required this.animOut,
    required this.animDur,
  });

  static Future<OverlaySpec> fromOverlay(
    double start,
    double end,
    double nx,
    double ny,
    TextAnim animIn,
    TextAnim animOut,
    double animDur,
    String pngPath,
  ) async {
    return OverlaySpec(
      pngPath: pngPath,
      start: start,
      end: end,
      nx: nx,
      ny: ny,
      animIn: animIn,
      animOut: animOut,
      animDur: animDur,
    );
  }

  String xExpr() {
    final baseX = '(${_nn(nx)}*W-w/2)';
    final inEnd = start + animDur;
    if (animIn == TextAnim.slideRight) {
      return "'$baseX+if(lt(t,${_nn(inEnd)}),(1-(t-${_nn(start)})/${_nn(animDur)})*W,0)'";
    }
    if (animIn == TextAnim.slideLeft) {
      return "'$baseX-if(lt(t,${_nn(inEnd)}),(1-(t-${_nn(start)})/${_nn(animDur)})*W,0)'";
    }
    return baseX;
  }

  String yExpr() {
    final baseY = '(${_nn(ny)}*H-h/2)';
    final inEnd = start + animDur;
    if (animIn == TextAnim.slideUp) {
      return "'$baseY+if(lt(t,${_nn(inEnd)}),(1-(t-${_nn(start)})/${_nn(animDur)})*H,0)'";
    }
    if (animIn == TextAnim.slideDown) {
      return "'$baseY-if(lt(t,${_nn(inEnd)}),(1-(t-${_nn(start)})/${_nn(animDur)})*H,0)'";
    }
    return baseY;
  }

  static String _nn(double v) => ExportService._n(v);
}
