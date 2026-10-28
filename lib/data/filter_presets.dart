import 'models.dart';

/// كتالوج الفلاتر — 44 فلتراً.
/// الأسماء مستوحاة من كتالوج InShot الأصلي المستخرج من كود التطبيق
/// (table_cinema01..05, table_film01..05, table_skin01..05, table_moss01..03, ...)
/// مع إضافات بأسلوب CapCut.
class FilterPreset {
  final String id;
  final String name;
  final ColorParams params;
  const FilterPreset(this.id, this.name, this.params);
}

class FilterPresets {
  static const List<FilterPreset> all = [
    // ── نظيف ──
    FilterPreset('clean', 'نظيف', ColorParams(brightness: 0.10, contrast: 0.06, saturation: 0.06)),
    FilterPreset('natural', 'طبيعي', ColorParams(brightness: 0.05, contrast: 0.03, saturation: -0.04)),

    // ── سينما (cinema01..05) ──
    FilterPreset('cinema1', 'سينما ١', ColorParams(contrast: 0.16, saturation: -0.08, warmth: -0.06, vignette: 0.30)),
    FilterPreset('cinema2', 'سينما ٢', ColorParams(contrast: 0.22, saturation: -0.14, warmth: 0.10, tint: -0.05, vignette: 0.38)),
    FilterPreset('cinema3', 'سينما ٣', ColorParams(contrast: 0.14, saturation: -0.06, warmth: -0.14, vignette: 0.25)),
    FilterPreset('cinema4', 'سينما ٤', ColorParams(contrast: 0.25, saturation: -0.18, warmth: 0.04, fade: 0.10, vignette: 0.45)),
    FilterPreset('cinema5', 'سينما ٥', ColorParams(contrast: 0.18, saturation: -0.10, tint: 0.08, vignette: 0.42)),

    // ── فيلم (film01..05) ──
    FilterPreset('film1', 'فيلم ١', ColorParams(brightness: 0.04, contrast: -0.06, saturation: -0.10, warmth: 0.16, fade: 0.22)),
    FilterPreset('film2', 'فيلم ٢', ColorParams(contrast: -0.04, saturation: -0.16, warmth: 0.22, fade: 0.30)),
    FilterPreset('film3', 'فيلم ٣', ColorParams(brightness: 0.06, contrast: -0.10, saturation: -0.22, warmth: 0.10, fade: 0.38)),
    FilterPreset('film4', 'فيلم ٤', ColorParams(contrast: 0.06, saturation: -0.08, tint: -0.10, fade: 0.26)),
    FilterPreset('film5', 'فيلم ٥', ColorParams(brightness: 0.03, contrast: 0.10, saturation: -0.12, warmth: -0.12, fade: 0.18)),

    // ── بشرة (skin01..05) ──
    FilterPreset('skin1', 'بشرة ١', ColorParams(brightness: 0.12, contrast: -0.06, saturation: 0.04, warmth: 0.10)),
    FilterPreset('skin2', 'بشرة ٢', ColorParams(brightness: 0.15, contrast: -0.10, saturation: -0.04, warmth: 0.16)),
    FilterPreset('skin3', 'بشرة ٣', ColorParams(brightness: 0.10, contrast: -0.04, saturation: 0.02, warmth: 0.06, tint: 0.05)),
    FilterPreset('skin4', 'بشرة ٤', ColorParams(brightness: 0.18, contrast: -0.12, saturation: -0.08, warmth: 0.12, fade: 0.08)),
    FilterPreset('skin5', 'بشرة ٥', ColorParams(brightness: 0.08, contrast: -0.02, saturation: 0.06, warmth: 0.20)),

    // ── طحلب (moss01..03) ──
    FilterPreset('moss1', 'طحلب ١', ColorParams(saturation: -0.06, tint: -0.18, contrast: 0.08)),
    FilterPreset('moss2', 'طحلب ٢', ColorParams(saturation: -0.12, tint: -0.24, warmth: -0.08, fade: 0.12)),
    FilterPreset('moss3', 'طحلب ٣', ColorParams(saturation: 0.02, tint: -0.20, warmth: 0.06, contrast: 0.10)),

    // ── أجواء InShot الأصلية ──
    FilterPreset('warm', 'دافئ', ColorParams(warmth: 0.30, brightness: 0.06, saturation: 0.08)),
    FilterPreset('bright', 'ساطع', ColorParams(brightness: 0.22, contrast: 0.04, saturation: 0.05)),
    FilterPreset('dark', 'داكن', ColorParams(brightness: -0.12, contrast: 0.14, saturation: -0.08, vignette: 0.30)),
    FilterPreset('antique', 'عتيق', ColorParams(contrast: 0.08, saturation: -0.30, warmth: 0.20, fade: 0.30)),
    FilterPreset('vintage', 'ريترو', ColorParams(saturation: -0.22, warmth: 0.14, tint: 0.06, fade: 0.34, contrast: 0.04)),
    FilterPreset('pink', 'وردي', ColorParams(brightness: 0.08, saturation: 0.10, tint: 0.22, warmth: 0.08)),
    FilterPreset('latte', 'لاتيه', ColorParams(brightness: 0.06, saturation: -0.10, warmth: 0.24, fade: 0.14)),
    FilterPreset('cocoa', 'كاكاو', ColorParams(brightness: -0.02, saturation: -0.06, warmth: 0.28, contrast: 0.06, fade: 0.10)),
    FilterPreset('gold', 'ذهبي', ColorParams(brightness: 0.08, saturation: 0.06, warmth: 0.36, contrast: 0.04)),
    FilterPreset('grape', 'عنب', ColorParams(saturation: 0.08, tint: 0.14, warmth: -0.14, contrast: 0.10)),
    FilterPreset('lomo', 'لومو', ColorParams(contrast: 0.28, saturation: 0.18, vignette: 0.55)),
    FilterPreset('dew', 'ندى', ColorParams(brightness: 0.10, saturation: 0.04, warmth: -0.16, contrast: 0.02)),
    FilterPreset('harvest', 'حصاد', ColorParams(saturation: 0.12, warmth: 0.22, contrast: 0.08, brightness: 0.02)),
    FilterPreset('ginkgo', 'جنكو', ColorParams(saturation: 0.06, warmth: 0.18, tint: -0.10)),
    FilterPreset('circus', 'سيرك', ColorParams(contrast: 0.20, saturation: 0.24, warmth: -0.06)),
    FilterPreset('memo', 'مذكرة', ColorParams(contrast: -0.10, saturation: -0.36, fade: 0.42, brightness: 0.10)),
    FilterPreset('story', 'حكاية', ColorParams(contrast: 0.10, saturation: -0.04, warmth: 0.08, fade: 0.16, vignette: 0.20)),
    FilterPreset('time', 'زمن', ColorParams(contrast: 0.06, saturation: -0.40, warmth: 0.24, fade: 0.26)),

    // ── أبيض وأسود ──
    FilterPreset('mono', 'أبيض وأسود', ColorParams(monochrome: 1, contrast: 0.10)),
    FilterPreset('noir', 'نوار', ColorParams(monochrome: 1, contrast: 0.34, vignette: 0.50, brightness: -0.04)),
    FilterPreset('monoSoft', 'رمادي ناعم', ColorParams(monochrome: 1, contrast: -0.08, fade: 0.20, brightness: 0.08)),

    // ── إضافات CapCut-style ──
    FilterPreset('peach', 'خوخي', ColorParams(brightness: 0.12, saturation: 0.06, tint: 0.16, warmth: 0.14)),
    FilterPreset('sakura', 'ساكورا', ColorParams(brightness: 0.14, saturation: 0.10, tint: 0.28, contrast: -0.04)),
    FilterPreset('food', 'طعام', ColorParams(saturation: 0.20, warmth: 0.16, contrast: 0.10)),
    FilterPreset('cyberpunk', 'سيبربانك', ColorParams(contrast: 0.30, saturation: 0.30, tint: -0.18, warmth: -0.20, vignette: 0.35)),
    FilterPreset('crisp', 'حاد', ColorParams(contrast: 0.18, saturation: 0.08, brightness: 0.04)),
    FilterPreset('coolBlue', 'أزرق بارد', ColorParams(warmth: -0.30, saturation: 0.05, contrast: 0.06)),
  ];

  static FilterPreset? byId(String? id) {
    if (id == null) return null;
    for (final f in all) {
      if (f.id == id) return f;
    }
    return null;
  }
}

/// كتالوج الانتقالات (xfade).
class TransitionPreset {
  final String id;
  final String name;
  final String xfadeName;
  const TransitionPreset(this.id, this.name, this.xfadeName);
}

class TransitionPresets {
  static const List<TransitionPreset> all = [
    TransitionPreset('fade', 'تلاشي', 'fade'),
    TransitionPreset('fadeblack', 'لأسود', 'fadeblack'),
    TransitionPreset('fadewhite', 'لأبيض', 'fadewhite'),
    TransitionPreset('slideleft', 'انزلاق', 'slideleft'),
    TransitionPreset('slideright', 'انزلاق يمين', 'slideright'),
    TransitionPreset('slideup', 'انزلاق لأعلى', 'slideup'),
    TransitionPreset('slidedown', 'انزلاق لأسفل', 'slidedown'),
    TransitionPreset('wiperight', 'مسح يمين', 'wiperight'),
    TransitionPreset('wipeleft', 'مسح يسار', 'wipeleft'),
    TransitionPreset('wipeup', 'مسح لأعلى', 'wipeup'),
    TransitionPreset('wipedown', 'مسح لأسفل', 'wipedown'),
    TransitionPreset('circleopen', 'دائرة', 'circleopen'),
    TransitionPreset('circleclose', 'دائرة مغلقة', 'circleclose'),
    TransitionPreset('circlecrop', 'قص دائري', 'circlecrop'),
    TransitionPreset('rectopen', 'مستطيل', 'rectopen'),
    TransitionPreset('rectclose', 'مستطيل مغلق', 'rectclose'),
    TransitionPreset('rectcrop', 'قص مستطيل', 'rectcrop'),
    TransitionPreset('dissolve', 'تذويب', 'dissolve'),
    TransitionPreset('pixelize', 'بكسل', 'pixelize'),
    TransitionPreset('smoothleft', 'ناعم يسار', 'smoothleft'),
    TransitionPreset('smoothright', 'ناعم يمين', 'smoothright'),
    TransitionPreset('smoothup', 'ناعم أعلى', 'smoothup'),
    TransitionPreset('smoothdown', 'ناعم أسفل', 'smoothdown'),
    TransitionPreset('zoomin', 'تكبير', 'zoomin'),
    TransitionPreset('radial', 'شعاعي', 'radial'),
    TransitionPreset('distance', 'مسافة', 'distance'),
    TransitionPreset('hblur', 'ضبابي', 'hblur'),
    TransitionPreset('diagtl', 'قطري أعلى-يسار', 'diagtl'),
    TransitionPreset('diagbr', 'قطري أسفل-يمين', 'diagbr'),
    TransitionPreset('hlslice', 'شرائح أفقية', 'hlslice'),
    TransitionPreset('hrslice', 'شرائح أفقية عكسية', 'hrslice'),
    TransitionPreset('vuslice', 'شرائح رأسية', 'vuslice'),
    TransitionPreset('vdslice', 'شرائح رأسية عكسية', 'vdslice'),
    TransitionPreset('squeezeh', 'انضغاط أفقي', 'squeezeh'),
    TransitionPreset('squeezev', 'انضغاط رأسي', 'squeezev'),
  ];

  static TransitionPreset? byId(String? id) {
    if (id == null) return null;
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }
}
