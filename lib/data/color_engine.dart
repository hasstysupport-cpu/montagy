import 'dart:math' as math;


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
  static List<double> previewMatrix({
    required String? presetId,
    required double intensity,
    required ColorParams adjust,
  }) {
    final preset = presetId == null
        ? ColorParams.neutral()
        : (FilterPresets.byId(presetId)?.params ?? ColorParams.neutral());
    return ColorEngine.matrix(
        ColorEngine.resolve(preset, intensity.clamp(0, 1), adjust));
  }

  static double vignetteOf({
    required String? presetId,
    required double intensity,
    required ColorParams adjust,
  }) {
    final preset = presetId == null
        ? ColorParams.neutral()
        : (FilterPresets.byId(presetId)?.params ?? ColorParams.neutral());
    return ColorEngine.resolve(preset, intensity.clamp(0, 1), adjust).vignette;
  }

  static String ffmpegChain({
    required String? presetId,
    required double intensity,
    required ColorParams adjust,
  }) {
    final preset = presetId == null
        ? ColorParams.neutral()
        : (FilterPresets.byId(presetId)?.params ?? ColorParams.neutral());
    return ColorEngine.ffmpegChain(
        ColorEngine.resolve(preset, intensity.clamp(0, 1), adjust));
  }
}
