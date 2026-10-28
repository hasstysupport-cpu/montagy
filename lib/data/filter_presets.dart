import 'models.dart';

/// كتالوج الفلاتر — 42 فلتر LUT حقيقي (ملفات .cube مبنية في التطبيق).
/// التصنيفات مستوحاة من كتالوج InShot الأصلي المستخرج من كود التطبيق
/// (cinema01..05, film01..05, skin01..05, moss01..03, table_warm, table_lomo, ...)
/// مع تنظيم بنمط CapCut + صور معاينة مُضمّنة.
class FilterPreset {
  final String id;
  final String name;
  final String category;
  final String? thumbAsset; // صورة معاينة مُضمّنة (احتياطي لو مفيش ثامب للمقطع)
  final ColorParams? params; // للاحتياطي فقط (فلاتر قديمة بارامترية)
  const FilterPreset(this.id, this.name, this.category,
      {this.thumbAsset, this.params});
}

class FilterCategories {
  static const List<String> all = [
    'شائع',
    'سينما',
    'فيلم',
    'ريترو',
    'أبيض وأسود',
    'دافئ وبارد',
    'طعام',
    'طبيعة',
    'بورتريه',
    'أحلام',
  ];
}

class FilterPresets {
  static const List<FilterPreset> all = [
    // ── شائع ──
    FilterPreset('clear', 'واضح', 'شائع', thumbAsset: 'assets/filters/clear.png'),
    FilterPreset('bright', 'مشرق', 'شائع', thumbAsset: 'assets/filters/bright.png'),
    FilterPreset('soft', 'ناعم', 'شائع', thumbAsset: 'assets/filters/soft.png'),
    FilterPreset('natural', 'طبيعي', 'شائع', thumbAsset: 'assets/filters/natural.png'),
    FilterPreset('glow', 'توهج', 'شائع', thumbAsset: 'assets/filters/glow.png'),

    // ── سينما ──
    FilterPreset('cinema01', 'سينما ١', 'سينما', thumbAsset: 'assets/filters/cinema01.png'),
    FilterPreset('cinema02', 'سينما ٢', 'سينما', thumbAsset: 'assets/filters/cinema02.png'),
    FilterPreset('cinema03', 'سينما ٣', 'سينما', thumbAsset: 'assets/filters/cinema03.png'),
    FilterPreset('cinema04', 'سينما ٤', 'سينما', thumbAsset: 'assets/filters/cinema04.png'),
    FilterPreset('cinema05', 'سينما ٥', 'سينما', thumbAsset: 'assets/filters/cinema05.png'),

    // ── فيلم ──
    FilterPreset('film01', 'فيلم ١', 'فيلم', thumbAsset: 'assets/filters/film01.png'),
    FilterPreset('film02', 'فيلم ٢', 'فيلم', thumbAsset: 'assets/filters/film02.png'),
    FilterPreset('film03', 'فيلم ٣', 'فيلم', thumbAsset: 'assets/filters/film03.png'),
    FilterPreset('film04', 'فيلم ٤', 'فيلم', thumbAsset: 'assets/filters/film04.png'),
    FilterPreset('film05', 'فيلم ٥', 'فيلم', thumbAsset: 'assets/filters/film05.png'),

    // ── ريترو ──
    FilterPreset('lomo', 'لومو', 'ريترو', thumbAsset: 'assets/filters/lomo.png'),
    FilterPreset('vintage', 'ريترو', 'ريترو', thumbAsset: 'assets/filters/vintage.png'),
    FilterPreset('antique', 'عتيق', 'ريترو', thumbAsset: 'assets/filters/antique.png'),
    FilterPreset('retro90', 'تسعينات', 'ريترو', thumbAsset: 'assets/filters/retro90.png'),
    FilterPreset('faded', 'باهت', 'ريترو', thumbAsset: 'assets/filters/faded.png'),

    // ── أبيض وأسود ──
    FilterPreset('mono', 'أبيض وأسود', 'أبيض وأسود', thumbAsset: 'assets/filters/mono.png'),
    FilterPreset('monoSoft', 'رمادي ناعم', 'أبيض وأسود', thumbAsset: 'assets/filters/monoSoft.png'),
    FilterPreset('noir', 'نوار', 'أبيض وأسود', thumbAsset: 'assets/filters/noir.png'),
    FilterPreset('silver', 'فضي', 'أبيض وأسود', thumbAsset: 'assets/filters/silver.png'),
    FilterPreset('sepia', 'سيبيا', 'أبيض وأسود', thumbAsset: 'assets/filters/sepia.png'),

    // ── دافئ وبارد ──
    FilterPreset('warm', 'دافئ', 'دافئ وبارد', thumbAsset: 'assets/filters/warm.png'),
    FilterPreset('sunset', 'غروب', 'دافئ وبارد', thumbAsset: 'assets/filters/sunset.png'),
    FilterPreset('golden', 'ذهبي', 'دافئ وبارد', thumbAsset: 'assets/filters/golden.png'),
    FilterPreset('cool', 'بارد', 'دافئ وبارد', thumbAsset: 'assets/filters/cool.png'),
    FilterPreset('ice', 'ثلجي', 'دافئ وبارد', thumbAsset: 'assets/filters/ice.png'),

    // ── طعام ──
    FilterPreset('foodWarm', 'طعام دافئ', 'طعام', thumbAsset: 'assets/filters/foodWarm.png'),
    FilterPreset('fresh', 'منعش', 'طعام', thumbAsset: 'assets/filters/fresh.png'),

    // ── طبيعة ──
    FilterPreset('moss', 'طحلب', 'طبيعة', thumbAsset: 'assets/filters/moss.png'),
    FilterPreset('forest', 'غابة', 'طبيعة', thumbAsset: 'assets/filters/forest.png'),
    FilterPreset('sky', 'سماء', 'طبيعة', thumbAsset: 'assets/filters/sky.png'),
    FilterPreset('harvest', 'حصاد', 'طبيعة', thumbAsset: 'assets/filters/harvest.png'),

    // ── بورتريه ──
    FilterPreset('skin01', 'بشرة ١', 'بورتريه', thumbAsset: 'assets/filters/skin01.png'),
    FilterPreset('skin02', 'بشرة ٢', 'بورتريه', thumbAsset: 'assets/filters/skin02.png'),
    FilterPreset('skin03', 'بشرة ٣', 'بورتريه', thumbAsset: 'assets/filters/skin03.png'),

    // ── أحلام ──
    FilterPreset('dreamy', 'حلمي', 'أحلام', thumbAsset: 'assets/filters/dreamy.png'),
    FilterPreset('pastel', 'باستيل', 'أحلام', thumbAsset: 'assets/filters/pastel.png'),
    FilterPreset('candy', 'حلوى', 'أحلام', thumbAsset: 'assets/filters/candy.png'),
  ];

  static FilterPreset? byId(String? id) {
    if (id == null) return null;
    for (final f in all) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// خريطة الأسماء القديمة (مشاريع v2.x) إلى فلاتر الـ LUT الجديدة.
  static const Map<String, String> _legacyMap = {
    'clean': 'clear',
    'cinema1': 'cinema01',
    'cinema2': 'cinema02',
    'cinema3': 'cinema03',
    'cinema4': 'cinema04',
    'cinema5': 'cinema05',
    'film1': 'film01',
    'film2': 'film02',
    'film3': 'film03',
    'film4': 'film04',
    'film5': 'film05',
    'skin1': 'skin01',
    'skin2': 'skin02',
    'skin3': 'skin03',
    'skin4': 'skin02',
    'skin5': 'skin01',
    'moss1': 'moss',
    'moss2': 'forest',
    'moss3': 'moss',
    'dark': 'cinema04',
    'pink': 'candy',
    'latte': 'golden',
    'cocoa': 'film04',
    'gold': 'golden',
    'grape': 'cool',
    'dew': 'fresh',
    'ginkgo': 'harvest',
    'circus': 'candy',
    'memo': 'faded',
    'story': 'film03',
    'time': 'sepia',
    'peach': 'skin02',
    'sakura': 'pastel',
    'food': 'foodWarm',
    'cyberpunk': 'cinema01',
    'crisp': 'clear',
    'coolBlue': 'cool',
  };

  /// يحول أي معرّف (قديم أو جديد) إلى معرّف LUT حقيقي.
  static String? resolveId(String? id) {
    if (id == null) return null;
    if (byId(id) != null) return id;
    final mapped = _legacyMap[id];
    return (mapped != null && byId(mapped) != null) ? mapped : null;
  }

  static List<FilterPreset> byCategory(String cat) =>
      all.where((f) => f.category == cat).toList();
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
