import 'dart:ui';

/// Montagy Motion-Graphics DSL — compact JSON the AI can generate and the
/// built-in engine renders on top of the video.
///
/// Example element:
/// {
///   "type": "text",            // text | emoji | shape
///   "text": "اشترك في القناة",
///   "emoji": "🔥",
///   "shape": "pill",           // pill | rect | circle | underline
///   "start": 0.0, "end": 3.0,
///   "x": 0.5, "y": 0.2,        // relative 0..1
///   "fontSizePct": 8,
///   "font": "Tajawal",
///   "color": "#FFFFFF",
///   "accent": "#22D3EE",
///   "anim": "popIn",           // popIn | fadeIn | slideUp | slideDown | typewriter | pulse | shake | wipe
///   "loop": false
/// }
class MotionElement {
  final String type;
  final String text;
  final String emoji;
  final String shape;
  final double start;
  final double end;
  final double x;
  final double y;
  final double fontSizePct;
  final String font;
  final Color color;
  final Color accent;
  final String anim;
  final bool loop;

  const MotionElement({
    required this.type,
    this.text = '',
    this.emoji = '',
    this.shape = 'pill',
    required this.start,
    required this.end,
    this.x = 0.5,
    this.y = 0.5,
    this.fontSizePct = 7,
    this.font = 'Tajawal',
    this.color = const Color(0xFFFFFFFF),
    this.accent = const Color(0xFF22D3EE),
    this.anim = 'fadeIn',
    this.loop = false,
  });

  factory MotionElement.fromJson(Map<String, dynamic> j) => MotionElement(
        type: (j['type'] as String? ?? 'text'),
        text: j['text'] as String? ?? '',
        emoji: j['emoji'] as String? ?? '',
        shape: j['shape'] as String? ?? 'pill',
        start: (j['start'] as num?)?.toDouble() ?? 0,
        end: (j['end'] as num?)?.toDouble() ?? 3,
        x: (j['x'] as num?)?.toDouble() ?? 0.5,
        y: (j['y'] as num?)?.toDouble() ?? 0.5,
        fontSizePct: (j['fontSizePct'] as num?)?.toDouble() ?? 7,
        font: j['font'] as String? ?? 'Tajawal',
        color: _parseColor(j['color']) ?? const Color(0xFFFFFFFF),
        accent: _parseColor(j['accent']) ?? const Color(0xFF22D3EE),
        anim: j['anim'] as String? ?? 'fadeIn',
        loop: j['loop'] as bool? ?? false,
      );

  static Color? _parseColor(dynamic v) {
    if (v == null) return null;
    var s = v.toString().replaceFirst('#', '');
    if (s.length == 6) s = 'FF$s';
    final val = int.tryParse(s, radix: 16);
    return val == null ? null : Color(val);
  }
}

/// A full motion scene = a list of timed elements.
class MotionScene {
  final String name;
  final List<MotionElement> elements;

  const MotionScene({required this.name, required this.elements});

  factory MotionScene.fromJson(Map<String, dynamic> j) => MotionScene(
        name: j['name'] as String? ?? 'Scene',
        elements: ((j['elements'] as List?) ?? [])
            .map((e) => MotionElement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'elements': elements
            .map((e) => {
                  'type': e.type,
                  'text': e.text,
                  'emoji': e.emoji,
                  'shape': e.shape,
                  'start': e.start,
                  'end': e.end,
                  'x': e.x,
                  'y': e.y,
                  'fontSizePct': e.fontSizePct,
                  'font': e.font,
                  'color': '#${e.color.value.toRadixString(16).padLeft(8, '0').substring(2)}',
                  'accent': '#${e.accent.value.toRadixString(16).padLeft(8, '0').substring(2)}',
                  'anim': e.anim,
                  'loop': e.loop,
                })
            .toList(),
      };
}
