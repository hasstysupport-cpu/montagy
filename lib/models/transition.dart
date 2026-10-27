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
  // Core set
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
  // ---- v1.1 pack (all safe xfade names, ffmpeg >= 4.3) ----
  static const circleClose = TransitionSpec(id: 'circleclose');
  static const circleCrop = TransitionSpec(id: 'circlecrop');
  static const rectCrop = TransitionSpec(id: 'rectcrop');
  static const distance = TransitionSpec(id: 'distance');
  static const fadeBlack = TransitionSpec(id: 'fadeblack');
  static const fadeWhite = TransitionSpec(id: 'fadewhite');
  static const smoothRight = TransitionSpec(id: 'smoothright');
  static const smoothUp = TransitionSpec(id: 'smoothup');
  static const smoothDown = TransitionSpec(id: 'smoothdown');
  static const horzOpen = TransitionSpec(id: 'horzopen');
  static const horzClose = TransitionSpec(id: 'horzclose');
  static const vertOpen = TransitionSpec(id: 'vertopen');
  static const vertClose = TransitionSpec(id: 'vertclose');
  static const diagTL = TransitionSpec(id: 'diagtl');
  static const diagBR = TransitionSpec(id: 'diagbr');
  static const squeezeH = TransitionSpec(id: 'squeezeh');
  static const squeezeV = TransitionSpec(id: 'squeezev');
  static const wipeUp = TransitionSpec(id: 'wipeup');
  static const slideRight = TransitionSpec(id: 'slideright');
  static const slideDown = TransitionSpec(id: 'slidedown');
  static const fadeGrays = TransitionSpec(id: 'fadegrays');

  static const List<TransitionSpec> all = [
    none, fade, dissolve, wipeLeft, wipeRight, wipeUp, slideLeft, slideRight, slideDown,
    circleOpen, circleClose, circleCrop, rectCrop, pixelize, distance,
    fadeBlack, fadeWhite, fadeGrays, smoothLeft, smoothRight, smoothUp, smoothDown,
    horzOpen, horzClose, vertOpen, vertClose, diagTL, diagBR,
    squeezeH, squeezeV, zoomIn, hBlur, radial,
  ];
}
