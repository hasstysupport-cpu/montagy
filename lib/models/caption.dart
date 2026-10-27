import 'caption_style.dart';

/// One timed word (used for karaoke highlighting).
class TimedWord {
  final String text;
  final double start; // seconds, absolute on timeline
  final double end;

  const TimedWord({required this.text, required this.start, required this.end});

  Map<String, dynamic> toJson() => {'t': text, 's': start, 'e': end};

  factory TimedWord.fromJson(Map<String, dynamic> j) => TimedWord(
        text: j['t'] as String? ?? '',
        start: (j['s'] as num?)?.toDouble() ?? 0,
        end: (j['e'] as num?)?.toDouble() ?? 0,
      );

  TimedWord copyWith({String? text, double? start, double? end}) =>
      TimedWord(text: text ?? this.text, start: start ?? this.start, end: end ?? this.end);
}

/// A single caption line shown between [start] and [end].
class CaptionSegment {
  final String id;
  String text;
  double start;
  double end;
  CaptionPosition position;
  double fontSizeScale; // multiplier on top of the style
  List<TimedWord> words; // optional — karaoke timing
  String styleId;

  CaptionSegment({
    required this.id,
    required this.text,
    required this.start,
    required this.end,
    this.position = CaptionPosition.bottom,
    this.fontSizeScale = 1.0,
    List<TimedWord>? words,
    required this.styleId,
  }) : words = words ?? const [];

  double get duration => (end - start).clamp(0.05, 3600);

  /// Split text into evenly-timed words (fallback when no word data exists).
  void distributeWords() {
    final parts = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) {
      words = [];
      return;
    }
    final totalChars = parts.fold<int>(0, (a, w) => a + w.length);
    final d = duration;
    var t = start;
    words = [
      for (var i = 0; i < parts.length; i++)
        () {
          final share = d * (parts[i].length / totalChars);
          final w = TimedWord(text: parts[i], start: t, end: t + share);
          t += share;
          return w;
        }(),
    ];
  }

  CaptionSegment copyWith({
    String? text,
    double? start,
    double? end,
    CaptionPosition? position,
    double? fontSizeScale,
    List<TimedWord>? words,
    String? styleId,
  }) =>
      CaptionSegment(
        id: id,
        text: text ?? this.text,
        start: start ?? this.start,
        end: end ?? this.end,
        position: position ?? this.position,
        fontSizeScale: fontSizeScale ?? this.fontSizeScale,
        words: words ?? this.words,
        styleId: styleId ?? this.styleId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'start': start,
        'end': end,
        'position': position.name,
        'fontSizeScale': fontSizeScale,
        'words': words.map((w) => w.toJson()).toList(),
        'styleId': styleId,
      };

  factory CaptionSegment.fromJson(Map<String, dynamic> j) => CaptionSegment(
        id: j['id'] as String,
        text: j['text'] as String? ?? '',
        start: (j['start'] as num?)?.toDouble() ?? 0,
        end: (j['end'] as num?)?.toDouble() ?? 0,
        position: CaptionPosition.values.firstWhere(
          (p) => p.name == j['position'],
          orElse: () => CaptionPosition.bottom,
        ),
        fontSizeScale: (j['fontSizeScale'] as num?)?.toDouble() ?? 1.0,
        words: ((j['words'] as List?) ?? [])
            .map((w) => TimedWord.fromJson(w as Map<String, dynamic>))
            .toList(),
        styleId: j['styleId'] as String? ?? 'tiktok_karaoke',
      );
}
