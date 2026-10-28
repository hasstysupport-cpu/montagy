/// كتالوج المؤثرات — نمط CapCut "Effects".
/// كل مؤثر له:
/// 1) سلسلة FFmpeg حقيقية تُطبَّق في التصدير (بالشدة)
/// 2) تمثيل معاينة مبسّط في Flutter (نوع + بارامتر)
class EffectPreset {
  final String id;
  final String name;
  final String emoji;
  final String category;

  const EffectPreset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
  });

  /// سلسلة FFmpeg بالشدة i (0..1). فارغة = بلا تغيير.
  static String ffmpegChain(String id, double intensity) {
    final i = intensity.clamp(0.0, 1.0);
    switch (id) {
      case 'softblur':
        return 'gblur=sigma=${_n(2 + 8 * i)}';
      case 'deepblur':
        return 'gblur=sigma=${_n(12 + 20 * i)}';
      case 'grain':
        return 'noise=alls=${_n(8 + 26 * i)}:allf=t';
      case 'pixelate':
        // نقسم التكبير حسب الشدة (24 إطار بكسل عند أقصى شدة)
        final px = _n(6 + 22 * (1 - i));
        return 'scale=iw/$px:ih/$px:flags=neighbor,scale=iw:ih:flags=neighbor';
      case 'sharpen':
        return 'unsharp=5:5:${_n(0.4 + 1.1 * i)}';
      case 'mirror':
        return 'crop=iw/2:ih:0:0,split[m][o];[o]hflip[mf];[m][mf]hstack';
      case 'glow':
        return 'split[gl_a][gl_b];[gl_b]gblur=sigma=${_n(8 + 12 * i)}[gl_bb];'
            '[gl_a][gl_bb]blend=all_mode=screen:all_opacity=${_n(0.2 + 0.35 * i)}';
      case 'neon':
        return 'hue=h=${_n(8 + 14 * i)}:s=${_n(1.4 + 1.2 * i)}';
      case 'shake':
        // اهتزاز الكاميرا — الإزاحة عبر crop بتعبيرات زمنية
        final padV = 3 + 14 * i;
        return 'crop=iw-${_n(2 * padV)}:ih-${_n(2 * padV)}:'
            "'${_n(padV)}+${_n(padV)}*sin(17*t)':'${_n(padV)}+${_n(padV)}*cos(23*t)'";
      case 'dreamy':
        // حلمي — توهج + صبغة وردية خفيفة
        return 'split[a][b];[b]gblur=sigma=16[bb];'
            '[a][bb]blend=all_mode=screen:all_opacity=${_n(0.25 + 0.3 * i)},'
            'colorbalance=rm=${_n(0.04 * i)}:gm=${_n(0.02 * i)}:bm=${_n(0.05 * i)}';
      default:
        return '';
    }
  }

  static String _n(double v) {
    var s = v.toStringAsFixed(3);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s.isEmpty || s == '-' ? '0' : s;
  }
}

class EffectsCatalog {
  static const List<EffectPreset> all = [
    // ── ضبابي ──
    EffectPreset(id: 'softblur', name: 'ضبابي ناعم', emoji: '🌫️', category: 'ضبابي'),
    EffectPreset(id: 'deepblur', name: 'ضبابي عميق', emoji: '💧', category: 'ضبابي'),
    // ── جو فيلم ──
    EffectPreset(id: 'grain', name: 'حبيبات فيلم', emoji: '🎞️', category: 'فيلم'),
    EffectPreset(id: 'dreamy', name: 'حلمي', emoji: '✨', category: 'فيلم'),
    EffectPreset(id: 'glow', name: 'توهج', emoji: '🌟', category: 'فيلم'),
    // ── حدة وألوان ──
    EffectPreset(id: 'sharpen', name: 'حدة عالية', emoji: '💠', category: 'ألوان'),
    EffectPreset(id: 'neon', name: 'نيون', emoji: '🌈', category: 'ألوان'),
    // ── بكسل ومرآة ──
    EffectPreset(id: 'pixelate', name: 'بكسل', emoji: '🧩', category: 'تحويل'),
    EffectPreset(id: 'mirror', name: 'مرآة', emoji: '🪞', category: 'تحويل'),
    // ── حركة ──
    EffectPreset(id: 'shake', name: 'اهتزاز', emoji: '📳', category: 'حركة'),
  ];

  static EffectPreset? byId(String id) {
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// سلسلة FFmpeg لكل مؤثرات مقطع (ترتيب ثابت حسب الكتالوج).
  static String chainsForClip(Map<String, double> effects) {
    final parts = <String>[];
    for (final e in all) {
      final i = effects[e.id];
      if (i != null && i > 0.01) {
        final chain = EffectPreset.ffmpegChain(e.id, i);
        if (chain.isNotEmpty) parts.add(chain);
      }
    }
    return parts.join(',');
  }
}
