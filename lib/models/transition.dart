/// xfade transition between consecutive clips.
class TransitionSpec {
  final String id; // xfade filter name ('' = none)
  final double duration; // seconds

  const TransitionSpec({required this.id, this.duration = 0.6});

  Map<String, dynamic> toJson() => {'id': id, 'duration': duration};

  factory TransitionSpec.fromJson(Map<String, dynamic> j) => TransitionSpec(
        id: j['id'] as String? ?? '',
        duration: (j['duration'] as num?)?.toDouble() ?? 0.6,
      );

  bool get isNone => id.isEmpty;
}

class Transitions {
  Transitions._();
  static const none = TransitionSpec(id: '');
  static const fade = TransitionSpec(id: 'fade');
  static const dissolve = TransitionSpec(id: 'dissolve');
  static const wipeLeft = TransitionSpec(id: 'wipeleft');
  static const wipeRight = TransitionSpec(id: 'wiperight');
  static const slideLeft = TransitionSpec(id: 'slideleft');
  static const circleOpen = TransitionSpec(id: 'circleopen');
  static const pixelize = TransitionSpec(id: 'pixelize');
  static const smoothLeft = TransitionSpec(id: 'smoothleft');
  static const zoomIn = TransitionSpec(id: 'zoomin');
  static const hBlur = TransitionSpec(id: 'hblur');
  static const radial = TransitionSpec(id: 'radial');

  static const List<TransitionSpec> all = [
    none, fade, dissolve, wipeLeft, wipeRight, slideLeft,
    circleOpen, pixelize, smoothLeft, zoomIn, hBlur, radial,
  ];
}
