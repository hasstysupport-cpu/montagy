import 'package:flutter/material.dart';

/// How a caption animates in the preview & how it is burned via ASS.
enum CaptionAnim { none, karaoke, pop, typewriter, wave, slideUp }

/// Vertical anchor of a caption block on the video.
enum CaptionPosition { top, center, bottom }

/// A complete caption look — serialized with the project.
@immutable
class CaptionStyle {
  final String id;
  final String fontFamily; // bundled font family (also used by libass)
  final double fontSizePct; // % of video height
  final Color textColor;
  final Color highlightColor; // karaoke active word / accent
  final Color strokeColor;
  final double strokeWidth;
  final Color? bgColor; // box behind text
  final double bgOpacity;
  final Color shadowColor;
  final double blur; // neon glow amount
  final bool bold;
  final bool uppercase;
  final CaptionAnim anim;
  final double letterSpacing;

  const CaptionStyle({
    required this.id,
    required this.fontFamily,
    this.fontSizePct = 6.5,
    this.textColor = Colors.white,
    this.highlightColor = const Color(0xFF22D3EE),
    this.strokeColor = Colors.black,
    this.strokeWidth = 0,
    this.bgColor,
    this.bgOpacity = 0.75,
    this.shadowColor = Colors.transparent,
    this.blur = 0,
    this.bold = true,
    this.uppercase = false,
    this.anim = CaptionAnim.none,
    this.letterSpacing = 0,
  });

  CaptionStyle copyWith({
    String? fontFamily,
    double? fontSizePct,
    Color? textColor,
    Color? highlightColor,
    Color? strokeColor,
    double? strokeWidth,
    Color? bgColor,
    double? bgOpacity,
    Color? shadowColor,
    double? blur,
    bool? bold,
    bool? uppercase,
    CaptionAnim? anim,
    double? letterSpacing,
  }) =>
      CaptionStyle(
        id: id,
        fontFamily: fontFamily ?? this.fontFamily,
        fontSizePct: fontSizePct ?? this.fontSizePct,
        textColor: textColor ?? this.textColor,
        highlightColor: highlightColor ?? this.highlightColor,
        strokeColor: strokeColor ?? this.strokeColor,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        bgColor: bgColor ?? this.bgColor,
        bgOpacity: bgOpacity ?? this.bgOpacity,
        shadowColor: shadowColor ?? this.shadowColor,
        blur: blur ?? this.blur,
        bold: bold ?? this.bold,
        uppercase: uppercase ?? this.uppercase,
        anim: anim ?? this.anim,
        letterSpacing: letterSpacing ?? this.letterSpacing,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fontFamily': fontFamily,
        'fontSizePct': fontSizePct,
        'textColor': textColor.value,
        'highlightColor': highlightColor.value,
        'strokeColor': strokeColor.value,
        'strokeWidth': strokeWidth,
        'bgColor': bgColor?.value,
        'bgOpacity': bgOpacity,
        'shadowColor': shadowColor.value,
        'blur': blur,
        'bold': bold,
        'uppercase': uppercase,
        'anim': anim.name,
        'letterSpacing': letterSpacing,
      };

  factory CaptionStyle.fromJson(Map<String, dynamic> j) => CaptionStyle(
        id: j['id'] as String,
        fontFamily: j['fontFamily'] as String? ?? 'Tajawal',
        fontSizePct: (j['fontSizePct'] as num?)?.toDouble() ?? 6.5,
        textColor: Color(j['textColor'] as int? ?? 0xFFFFFFFF),
        highlightColor: Color(j['highlightColor'] as int? ?? 0xFF22D3EE),
        strokeColor: Color(j['strokeColor'] as int? ?? 0xFF000000),
        strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 0,
        bgColor: j['bgColor'] == null ? null : Color(j['bgColor'] as int),
        bgOpacity: (j['bgOpacity'] as num?)?.toDouble() ?? 0.75,
        shadowColor: Color(j['shadowColor'] as int? ?? 0x00000000),
        blur: (j['blur'] as num?)?.toDouble() ?? 0,
        bold: j['bold'] as bool? ?? true,
        uppercase: j['uppercase'] as bool? ?? false,
        anim: CaptionAnim.values.firstWhere(
          (a) => a.name == j['anim'],
          orElse: () => CaptionAnim.none,
        ),
        letterSpacing: (j['letterSpacing'] as num?)?.toDouble() ?? 0,
      );
}

/// The built-in style gallery (12 styles, VEED/CapCut-grade).
class CaptionStylePresets {
  CaptionStylePresets._();

  static const tiktokKaraoke = CaptionStyle(
    id: 'tiktok_karaoke',
    fontFamily: 'Tajawal',
    fontSizePct: 7.0,
    textColor: Colors.white,
    highlightColor: Color(0xFF22D3EE),
    strokeWidth: 2.4,
    strokeColor: Colors.black,
    anim: CaptionAnim.karaoke,
    uppercase: true,
  );

  static const youtubeClassic = CaptionStyle(
    id: 'youtube_classic',
    fontFamily: 'Almarai',
    fontSizePct: 5.5,
    textColor: Colors.white,
    strokeColor: Colors.black,
    strokeWidth: 1.6,
    anim: CaptionAnim.none,
  );

  static const neon = CaptionStyle(
    id: 'neon',
    fontFamily: 'BebasNeue',
    fontSizePct: 8.0,
    textColor: Color(0xFFF0ABFC),
    highlightColor: Color(0xFF22D3EE),
    shadowColor: Color(0xFFD946EF),
    blur: 14,
    strokeWidth: 1.2,
    strokeColor: Color(0xFF4C1D95),
    anim: CaptionAnim.karaoke,
    uppercase: true,
  );

  static const box = CaptionStyle(
    id: 'box',
    fontFamily: 'Almarai',
    fontSizePct: 6.0,
    textColor: Colors.white,
    bgColor: Color(0xFF8B5CF6),
    bgOpacity: 0.92,
    highlightColor: Color(0xFFFBBF24),
    anim: CaptionAnim.none,
  );

  static const pop = CaptionStyle(
    id: 'pop',
    fontFamily: 'Anton',
    fontSizePct: 8.5,
    textColor: Colors.white,
    highlightColor: Color(0xFFF472B6),
    strokeColor: Colors.black,
    strokeWidth: 3.0,
    anim: CaptionAnim.pop,
    uppercase: true,
  );

  static const typewriter = CaptionStyle(
    id: 'typewriter',
    fontFamily: 'Changa',
    fontSizePct: 6.0,
    textColor: Color(0xFF34D399),
    strokeColor: Colors.black,
    strokeWidth: 1.2,
    anim: CaptionAnim.typewriter,
  );

  static const gradient = CaptionStyle(
    id: 'gradient',
    fontFamily: 'Tajawal',
    fontSizePct: 7.0,
    textColor: Color(0xFF8B5CF6),
    highlightColor: Color(0xFFF472B6),
    strokeWidth: 0,
    shadowColor: Color(0x66000000),
    blur: 6,
    anim: CaptionAnim.wave,
  );

  static const luxeOutline = CaptionStyle(
    id: 'outline',
    fontFamily: 'BebasNeue',
    fontSizePct: 9.0,
    textColor: Color(0x00000000), // hollow text (stroke only)
    strokeColor: Colors.white,
    strokeWidth: 2.2,
    highlightColor: Color(0xFFFBBF24),
    anim: CaptionAnim.karaoke,
    uppercase: true,
  );

  static const gaming = CaptionStyle(
    id: 'gaming',
    fontFamily: 'Anton',
    fontSizePct: 7.5,
    textColor: Color(0xFF22D3EE),
    highlightColor: Color(0xFFFDE047),
    strokeColor: Color(0xFF111827),
    strokeWidth: 2.6,
    shadowColor: Color(0xFF7C3AED),
    blur: 8,
    anim: CaptionAnim.pop,
    uppercase: true,
  );

  static const podcast = CaptionStyle(
    id: 'podcast',
    fontFamily: 'Almarai',
    fontSizePct: 5.8,
    textColor: Colors.white,
    bgColor: Color(0xFF000000),
    bgOpacity: 0.55,
    highlightColor: Color(0xFFFBBF24),
    anim: CaptionAnim.karaoke,
  );

  static const wave = CaptionStyle(
    id: 'wave',
    fontFamily: 'Lalezar',
    fontSizePct: 7.2,
    textColor: Color(0xFFFDE047),
    strokeColor: Color(0xFF7C2D12),
    strokeWidth: 2.0,
    anim: CaptionAnim.wave,
  );

  static const minimal = CaptionStyle(
    id: 'minimal',
    fontFamily: 'Tajawal',
    fontSizePct: 5.2,
    textColor: Colors.white,
    strokeWidth: 0,
    shadowColor: Color(0x88000000),
    blur: 4,
    bold: false,
    anim: CaptionAnim.slideUp,
  );

  static const List<CaptionStyle> all = [
    tiktokKaraoke,
    youtubeClassic,
    neon,
    box,
    pop,
    typewriter,
    gradient,
    luxeOutline,
    gaming,
    podcast,
    wave,
    minimal,
  ];

  static CaptionStyle byId(String id) =>
      all.firstWhere((s) => s.id == id, orElse: () => tiktokKaraoke);
}
