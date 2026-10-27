import 'dart:ui';

/// Draggable text / emoji / sticker overlaid on the video for a time range.
class OverlayItem {
  final String id;
  String text;
  bool isEmoji;
  double start;
  double end;
  double x; // 0..1 relative to video width (center of item)
  double y; // 0..1 relative to video height
  double scale;
  double rotationDeg;
  Color color;
  double fontSizePct;
  String fontFamily;
  Color? bgColor;
  double bgOpacity;
  double strokeWidth;
  Color strokeColor;
  double opacity;
  String anim; // '', 'fadeIn', 'pop', 'slideUp', 'neonPulse'

  OverlayItem({
    required this.id,
    required this.text,
    this.isEmoji = false,
    required this.start,
    required this.end,
    this.x = 0.5,
    this.y = 0.5,
    this.scale = 1.0,
    this.rotationDeg = 0,
    this.color = Colors.white,
    this.fontSizePct = 7,
    this.fontFamily = 'Tajawal',
    this.bgColor,
    this.bgOpacity = 0.6,
    this.strokeWidth = 0,
    this.strokeColor = Colors.black,
    this.opacity = 1,
    this.anim = 'fadeIn',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isEmoji': isEmoji,
        'start': start,
        'end': end,
        'x': x,
        'y': y,
        'scale': scale,
        'rotationDeg': rotationDeg,
        'color': color.value,
        'fontSizePct': fontSizePct,
        'fontFamily': fontFamily,
        'bgColor': bgColor?.value,
        'bgOpacity': bgOpacity,
        'strokeWidth': strokeWidth,
        'strokeColor': strokeColor.value,
        'opacity': opacity,
        'anim': anim,
      };

  factory OverlayItem.fromJson(Map<String, dynamic> j) => OverlayItem(
        id: j['id'] as String,
        text: j['text'] as String? ?? '',
        isEmoji: j['isEmoji'] as bool? ?? false,
        start: (j['start'] as num?)?.toDouble() ?? 0,
        end: (j['end'] as num?)?.toDouble() ?? 5,
        x: (j['x'] as num?)?.toDouble() ?? 0.5,
        y: (j['y'] as num?)?.toDouble() ?? 0.5,
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
        rotationDeg: (j['rotationDeg'] as num?)?.toDouble() ?? 0,
        color: Color(j['color'] as int? ?? 0xFFFFFFFF),
        fontSizePct: (j['fontSizePct'] as num?)?.toDouble() ?? 7,
        fontFamily: j['fontFamily'] as String? ?? 'Tajawal',
        bgColor: j['bgColor'] == null ? null : Color(j['bgColor'] as int),
        bgOpacity: (j['bgOpacity'] as num?)?.toDouble() ?? 0.6,
        strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 0,
        strokeColor: Color(j['strokeColor'] as int? ?? 0xFF000000),
        opacity: (j['opacity'] as num?)?.toDouble() ?? 1,
        anim: j['anim'] as String? ?? 'fadeIn',
      );

  OverlayItem copyWith({
    String? text,
    double? start,
    double? end,
    double? x,
    double? y,
    double? scale,
    double? rotationDeg,
    Color? color,
    double? fontSizePct,
    String? fontFamily,
    Color? bgColor,
    double? bgOpacity,
    double? strokeWidth,
    Color? strokeColor,
    double? opacity,
    String? anim,
  }) =>
      OverlayItem(
        id: id,
        text: text ?? this.text,
        isEmoji: isEmoji,
        start: start ?? this.start,
        end: end ?? this.end,
        x: x ?? this.x,
        y: y ?? this.y,
        scale: scale ?? this.scale,
        rotationDeg: rotationDeg ?? this.rotationDeg,
        color: color ?? this.color,
        fontSizePct: fontSizePct ?? this.fontSizePct,
        fontFamily: fontFamily ?? this.fontFamily,
        bgColor: bgColor ?? this.bgColor,
        bgOpacity: bgOpacity ?? this.bgOpacity,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        strokeColor: strokeColor ?? this.strokeColor,
        opacity: opacity ?? this.opacity,
        anim: anim ?? this.anim,
      );
}
