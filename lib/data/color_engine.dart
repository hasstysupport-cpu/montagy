import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'lut_matrices.dart';
import 'filter_presets.dart';
import 'models.dart';

/// محرك الألوان: يحول بارامترات الفلتر والتعديل اللوني إلى:
/// 1) مصفوفة 5x4 للمعاينة الفورية (ColorFiltered)
/// 2) سلسلة فلاتر FFmpeg مكافئة للتصدير النهائي
///
/// البارامترات كلها normalized: 0 = بلا تغيير.
class ColorEngine {
  /// يدمج الفلتر (بشدة intensity) + التعديلات اليدوية في بارامترات نهائية.
  static ColorParams resolve(ColorParams preset, double intensity,
      ColorParams adjust) {
    double mix(double base, double pre, double adj) =>
        base + (pre * intensity) + adj;
    return ColorParams(
      brightness: _cl(mix(0, preset.brightness, adjust.brightness)),
      contrast: _cl(mix(0, preset.contrast, adjust.contrast)),
      saturation: _cl(mix(0, preset.saturation, adjust.saturation)),
      warmth: _cl(mix(0, preset.warmth, adjust.warmth)),
      tint: _cl(mix(0, preset.tint, adjust.tint)),
      fade: _cl(mix(0, preset.fade, math.max(adjust.fade, 0))),
      vignette: _cl(mix(0, preset.vignette, math.max(adjust.vignette, 0))),
      monochrome: _cl(mix(0, preset.monochrome, 0)),
    );
  }

  static double _cl(double v, [double lo = -1, double hi = 1]) =>
      v.clamp(lo, hi).toDouble();

  /// يبني مصفوفة 4x5 (20 قيمة) لـ ColorFiltered.
  static List<double> matrix(ColorParams p) {
    // نبدأ بالمحايد
    List<double> m = [
      1.0, 0.0, 0.0, 0.0, 0.0, //
      0.0, 1.0, 0.0, 0.0, 0.0, //
      0.0, 0.0, 1.0, 0.0, 0.0, //
      0.0, 0.0, 0.0, 1.0, 0.0, //
    ];

    // أبيض وأسود (monochrome)
    if (p.monochrome > 0) {
      const lum = [0.213, 0.715, 0.072];
      final t = p.monochrome;
      final mono = [
        lum[0] * t + (1 - t), lum[1] * t, lum[2] * t, 0.0, 0.0, //
        lum[0] * t, lum[1] * t + (1 - t), lum[2] * t, 0.0, 0.0, //
        lum[0] * t, lum[1] * t, lum[2] * t + (1 - t), 0.0, 0.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ];
      m = _mul(mono, m);
    }

    // سطوع (إزاحة)
    if (p.brightness != 0) {
      final b = p.brightness * 0.35;
      m = _mul([
        1.0, 0.0, 0.0, 0.0, b, //
        0.0, 1.0, 0.0, 0.0, b, //
        0.0, 0.0, 1.0, 0.0, b, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ], m);
    }

    // تلاشي (رفع الأسود + خفض التباين قليلاً) — نفذها قبل التباين
    if (p.fade > 0) {
      final f = p.fade;
      final lift = f * 0.14;
      final scale = 1 - f * 0.22;
      m = _mul([
        scale, 0.0, 0.0, 0.0, lift, //
        0.0, scale, 0.0, 0.0, lift, //
        0.0, 0.0, scale, 0.0, lift, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ], m);
    }

    // تباين حول 0.5
    if (p.contrast != 0) {
      final c = 1 + p.contrast;
      final o = 0.5 * (1 - c);
      m = _mul([
        c, 0.0, 0.0, 0.0, o, //
        0.0, c, 0.0, 0.0, o, //
        0.0, 0.0, c, 0.0, o, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ], m);
    }

    // تشبع
    if (p.saturation != 0) {
      final s = 1 + p.saturation;
      const lr = 0.213, lg = 0.715, lb = 0.072;
      m = _mul([
        lr * (1 - s) + s, lg * (1 - s), lb * (1 - s), 0.0, 0.0, //
        lr * (1 - s), lg * (1 - s) + s, lb * (1 - s), 0.0, 0.0, //
        lr * (1 - s), lg * (1 - s), lb * (1 - s) + s, 0.0, 0.0, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ], m);
    }

    // دفء (أحمر لأعلى، أزرق لأسفل)
    if (p.warmth != 0) {
      final w = p.warmth;
      m = _mul([
        1.0, 0.0, 0.0, 0.0, w * 0.10, //
        0.0, 1.0, 0.0, 0.0, w * 0.015, //
        0.0, 0.0, 1.0, 0.0, -w * 0.10, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ], m);
    }

    // صبغة (أخضر ↔ أرجواني)
    if (p.tint != 0) {
      final t = p.tint;
      m = _mul([
        1.0, 0.0, 0.0, 0.0, t * 0.045, //
        0.0, 1.0, 0.0, 0.0, -t * 0.09, //
        0.0, 0.0, 1.0, 0.0, t * 0.045, //
        0.0, 0.0, 0.0, 1.0, 0.0, //
      ], m);
    }

    // إبرازات/ظلال
    if (p.highlights != 0 || p.shadows != 0) {
      m = _mul(hiLoMatrix(p.highlights, p.shadows), m);
    }

    // دورة الهوى
    if (p.hue != 0) {
      m = _mul(hueMatrix(p.hue), m);
    }

    return m;
  }

  /// ضرب مصفوفتين 4x5 (a يُطبق قبل b).
  static List<double> _mul(List<double> a, List<double> b) {
    // نمثل كل مصفوفة كصفوف [r0..r3] مع عمود إزاحة
    List<double> row(List<double> m, int i) =>
        [m[i * 5], m[i * 5 + 1], m[i * 5 + 2], m[i * 5 + 3], m[i * 5 + 4]];
    List<double> out = List.filled(20, 0.0);
    for (int i = 0; i < 4; i++) {
      final ai = row(a, i);
      for (int j = 0; j < 5; j++) {
        double v = 0;
        for (int k = 0; k < 4; k++) {
          v += ai[k] * b[k * 5 + j];
        }
        // عمود الإزاحة
        if (j == 4) v += ai[4];
        out[i * 5 + j] = v;
      }
    }
    out[3 * 5 + 3] = 1;
    out[3 * 5 + 4] = 0;
    return out;
  }

  /// مصفوفة دورة الهوى (hue rotation) — h: -1..1 ← 180°..
  static List<double> hueMatrix(double h) {
    final a = h * math.pi; // -180°..180° بالراديان
    final cos = math.cos(a), sin = math.sin(a);
    // مصفوفة hue-rotate القياسية (W3C)
    const lr = 0.213, lg = 0.715, lb = 0.072;
    return [
      lr + cos * (1 - lr) + sin * (-lr), lg + cos * (-lg) + sin * (-lg),
      lb + cos * (-lb) + sin * (1 - lb), 0, 0, //
      lr + cos * (-lr) + sin * (0.143), lg + cos * (1 - lg) + sin * (0.140),
      lb + cos * (-lb) + sin * (-0.283), 0, 0, //
      lr + cos * (-lr) + sin * (-(1 - lr)), lg + cos * (-lg) + sin * (lg),
      lb + cos * (1 - lb) + sin * (lb), 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  /// إبرازات/ظلال عبر gamma تقريبي (غير خطي في التصدير، خطي تقريبي هنا).
  static List<double> hiLoMatrix(double hi, double lo) {
    // الإبرازات: تكبير المناطق الفاتحة، الظلال: رفع المناطق الغامقة
    final hg = hi, sg = lo;
    // تدرج ناعم: نوّع الميل حسب القيمة عبر مزيج هوية + إزاحة موزونة
    var m = List<double>.from([
      1.0, 0, 0, 0, 0, //
      0, 1.0, 0, 0, 0, //
      0, 0, 1.0, 0, 0, //
      0, 0, 0, 1, 0, //
    ]);
    // الإبرازات: زيادة الميل على القنوات مع خصم نصف النقطة ليبقى المنتصف ثابتاً
    if (hg != 0) {
      final k = 1 + hg * 0.35;
      final o = hg * 0.12;
      m = _mul([
        k, 0, 0, 0, o, //
        0, k, 0, 0, o, //
        0, 0, k, 0, o, //
        0, 0, 0, 1, 0, //
      ], m);
    }
    if (sg != 0) {
      // الظلال: إزاحة لأسفل/لأعلى مع تقليل الميل قليلاً عند السالب
      final k = 1 + sg * 0.28;
      final o = sg * 0.16;
      m = _mul([
        k, 0, 0, 0, o, //
        0, k, 0, 0, o, //
        0, 0, k, 0, o, //
        0, 0, 0, 1, 0, //
      ], m);
    }
    return m;
  }

  /// حدة عبر unsharp (تُستخدم في التصدير فقط).
  static String sharpenChain(double sharpen) {
    if (sharpen <= 0) return '';
    final amt = (sharpen * 1.6).clamp(0.1, 1.8).toStringAsFixed(2);
    return 'unsharp=5:5:$amt:5:5:0.0';
  }

  /// سلسلة فلاتر FFmpeg المكافئة (بدون vignette — تُضاف منفصلة عند الحاجة).
  static String ffmpegChain(ColorParams p) {
    final parts = <String>[];
    // eq: brightness [-1,1] — نستخدم جزءاً من مدى مطابقة للمعاينة
    final b = p.brightness * 0.35 + p.fade * 0.14;
    final c = (1 + p.contrast) * (1 - p.fade * 0.22);
    final sat = (1 + p.saturation).clamp(0, 3).toDouble();
    if (b != 0 || c != 1 || sat != 1 || p.monochrome > 0) {
      parts.add(
          'eq=brightness=${b.toStringAsFixed(3)}:contrast=${c.toStringAsFixed(3)}:saturation=${p.monochrome > 0.5 ? 0 : sat.toStringAsFixed(3)}');
    }
    // دفء + صبغة عبر colorbalance
    final w = p.warmth, t = p.tint;
    if (w != 0 || t != 0) {
      parts.add('colorbalance='
          'rs=${(w * 0.10).toStringAsFixed(3)}:'
          'bs=${(-w * 0.10).toStringAsFixed(3)}:'
          'rm=${(w * 0.05).toStringAsFixed(3)}:'
          'bm=${(-w * 0.05).toStringAsFixed(3)}:'
          'gs=${(-t * 0.09).toStringAsFixed(3)}:'
          'gm=${(t * 0.03).toStringAsFixed(3)}');
    }
    // إبرازات/ظلال عبر نطاقات colorbalance
    final hi = p.highlights, lo = p.shadows;
    if (hi != 0 || lo != 0) {
      final cb = <String>[
        if (lo != 0) ...[
          'rs=${(lo * 0.22).toStringAsFixed(3)}',
          'gs=${(lo * 0.22).toStringAsFixed(3)}',
          'bs=${(lo * 0.22).toStringAsFixed(3)}',
        ],
        if (hi != 0) ...[
          'rh=${(hi * 0.22).toStringAsFixed(3)}',
          'gh=${(hi * 0.22).toStringAsFixed(3)}',
          'bh=${(hi * 0.22).toStringAsFixed(3)}',
        ],
      ].join(':');
      parts.add('colorbalance=$cb');
    }
    // دورة الهوى
    if (p.hue != 0) {
      parts.add('hue=h=${(p.hue * 180).toStringAsFixed(1)}');
    }
    if (p.vignette > 0) {
      // angle من PI/5 (خفيف) إلى PI/2.6 (قوي)
      final angle = math.pi / 5 + p.vignette * (math.pi / 2.6 - math.pi / 5);
      parts.add('vignette=angle=${angle.toStringAsFixed(3)}');
    }
    if (parts.isEmpty) return '';
    return parts.join(',');
  }
}

/// يجمع الفلتر المختار + شدته + تعديلات المقطع ويحسب القيم النهائية والفلتر للمعاينة.
class ColorFilterResolver {
  /// مصفوفة المعاينة الحية: LUT حقيقي (مصفوفة مُناسَبة) × مصفوفة التعديلات.
  static List<double>? previewMatrix({
    required String? presetId,
    required double intensity,
    required ColorParams adjust,
  }) {
    final String? lutId = FilterPresets.resolveId(presetId);
    final lutMatrix = lutId == null ? null : kLutPreviewMatrices[lutId];
    List<double> m;
    if (lutMatrix != null) {
      // مزج الشدة: lerp بين مصفوفة الهوية ومصفوفة الـ LUT
      final t = intensity.clamp(0, 1).toDouble();
      final m3 = List<double>.generate(
          20, (i) => (i % 5 == i ~/ 5) ? 1.0 : 0.0); // هوية
      m = List<double>.generate(
          20,
          (i) => (1 - t) * m3[i] + t * lutMatrix[i]);
    } else if (presetId != null) {
      // احتياطي: فلتر بارامتري قديم
      final preset = FilterPresets.byId(presetId)?.params;
      m = ColorEngine.matrix(
          ColorEngine.resolve(preset ?? ColorParams.neutral(),
              intensity.clamp(0, 1), ColorParams.neutral()));
    } else {
      m = List<double>.generate(20, (i) => (i % 5 == i ~/ 5) ? 1.0 : 0.0);
    }
    // التعديلات اليدوية فوق الفلتر
    if (!adjust.isNeutral) {
      m = ColorEngine._mul(ColorEngine.matrix(adjust), m);
    }
    return m;
  }

  static double vignetteOf({
    required String? presetId,
    required double intensity,
    required ColorParams adjust,
  }) {
    return adjust.vignette;
  }

  /// سلسلة التصدير: lut3d (فلتر حقيقي بشدة دقيقة) + سلسلة التعديلات.
  static String ffmpegChain({
    required String? presetId,
    required double intensity,
    required ColorParams adjust,
  }) {
    final parts = <String>[];
    final String? lutId = FilterPresets.resolveId(presetId);
    if (lutId != null) {
      final path = LutResolver.localPath(lutId, intensity);
      if (path != null) {
        parts.add("lut3d=file='$path':interp=linear");
      }
    } else if (presetId != null) {
      final preset = FilterPresets.byId(presetId)?.params;
      if (preset != null) {
        final legacy = ColorEngine.ffmpegChain(
            ColorEngine.resolve(preset, intensity.clamp(0, 1), ColorParams.neutral()));
        if (legacy.isNotEmpty) parts.add(legacy);
      }
    }
    final adj = ColorEngine.ffmpegChain(adjust);
    if (adj.isNotEmpty) parts.add(adj);
    final sharp = ColorEngine.sharpenChain(adjust.sharpen);
    if (sharp.isNotEmpty) parts.add(sharp);
    return parts.join(',');
  }
}

/// يحوّل مسارات LUT من assets إلى ملفات حقيقية لتستخدمها ffmpeg،
/// مع دعم الشدة عبر توليد LUT مُداخَل (identity ↔ lut) — دقة كاملة لأي نسبة.
class LutResolver {
  static final Map<String, String> _cache = {};

  static String? localPath(String lutId, [double intensity = 1]) {
    final pct = _pctBucket(intensity);
    return _cache['$lutId@$pct'];
  }

  static int _pctBucket(double intensity) {
    // 5% تقريب — يقلل عدد الملفات المولدة مع دقة كافية جداً
    return ((intensity.clamp(0, 1) * 20).round() * 5);
  }

  static Future<String?> ensureExtracted(String lutId,
      [double intensity = 1]) async {
    final pct = _pctBucket(intensity);
    final key = '$lutId@$pct';
    if (_cache.containsKey(key)) return _cache[key];
    try {
      final dir = await getTemporaryDirectory();
      final lutDir = Directory('${dir.path}/luts');
      if (!await lutDir.exists()) await lutDir.create(recursive: true);
      final t = pct / 100.0;
      String path;
      if (t >= 0.995) {
        final data = await rootBundle.load('assets/luts/$lutId.cube');
        final f = File('${lutDir.path}/$lutId.cube');
        if (!await f.exists()) await f.writeAsBytes(data.buffer.asUint8List());
        path = f.path;
      } else {
        // LUT مُداخَل: out = (1-t)*identity(in) + t*lut(in) لكل مدخل
        // نقرأ حجم الشبكة من LUT_3D_SIZE ثم نحسب إحداثيات كل مدخل بالترتيب
        // (ترتيب .cube: الأحمر الخارجي ثم الأخضر ثم الأزرق الأسرع).
        final src = await rootBundle.loadString('assets/luts/$lutId.cube');
        final f = File('${lutDir.path}/${lutId}_i$pct.cube');
        if (!await f.exists()) {
          int? n;
          int i = 0;
          final buf = StringBuffer();
          for (final line in src.split('\n')) {
            final s = line.trim();
            if (s.startsWith('LUT_3D_SIZE')) {
              n = int.tryParse(s.split(RegExp(r'\s+')).last);
              buf.writeln(line);
              continue;
            }
            if (s.isEmpty || s.startsWith('#') || s.startsWith('DOMAIN')) {
              buf.writeln(line);
              continue;
            }
            final parts = s.split(RegExp(r'\s+'));
            if (parts.length == 3 && n != null && n > 1) {
              try {
                final lr = double.parse(parts[0]);
                final lg = double.parse(parts[1]);
                final lb = double.parse(parts[2]);
                final bIdx = i % n;
                final gIdx = (i ~/ n) % n;
                final rIdx = i ~/ (n * n);
                final d = (n - 1).toDouble();
                final ir = rIdx / d, ig = gIdx / d, ib = bIdx / d;
                i++;
                buf.writeln(
                    '${((1 - t) * ir + t * lr).toStringAsFixed(6)} ${((1 - t) * ig + t * lg).toStringAsFixed(6)} ${((1 - t) * ib + t * lb).toStringAsFixed(6)}');
              } catch (_) {
                buf.writeln(line);
              }
            } else {
              buf.writeln(line);
            }
          }
          await f.writeAsString(buf.toString());
        }
        path = f.path;
      }
      _cache[key] = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  /// استخراج كل الـ LUTs المطلوبة للمشروع قبل التصدير (id + شدة).
  static Future<void> prepareAll(List<(String, double)> entries) async {
    for (final (id, intensity) in entries) {
      await ensureExtracted(id, intensity);
    }
  }
}
