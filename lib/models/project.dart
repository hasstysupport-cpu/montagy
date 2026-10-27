import 'audio_track.dart';
import 'caption.dart';
import 'filter.dart';
import 'overlay_item.dart';
import 'transition.dart';

/// One source video inside the timeline (trimmed range of a file).
class VideoClip {
  final String id;
  String path;
  String name;
  double sourceDuration;
  double trimStart; // in-file start
  double trimEnd; // in-file end
  double speed; // 0.25 .. 4
  double volume; // 0..2 (0 = muted)
  String filterId; // FilterPreset id
  double filterIntensity; // 0..1
  TransitionSpec transitionToNext;

  // ---- v1.1 transform & effects (CapCut/InShot parity) ----
  int rotate; // 0 | 90 | 180 | 270
  bool mirror; // horizontal flip
  bool flipV; // vertical flip
  bool reverse; // play backwards
  double freezeDur; // freeze-frame seconds appended at the end (0 = off)
  double cropAspect; // 0 = off, else w/h (1 = 1:1, 0.8 = 4:5, 1.7778 = 16:9, 0.5625 = 9:16)
  String kenBurns; // '' | zoomIn | zoomOut | panLeft | panRight
  bool chromaEnabled; // green-screen removal
  String chromaColor; // RRGGBB hex (default green)
  double chromaSimilarity; // 0.05..0.4
  double chromaBlend; // 0..0.4
  double brightness; // -0.3..0.3 (0 = default)
  double contrast; // 0.5..2.0 (1 = default)
  double saturation; // 0..3.0 (1 = default)
  double warmth; // -1..1
  double sharpen; // 0..2 (0 = off)
  double vignette; // 0..1 (0 = off)
  double grain; // 0..1 (0 = off)
  double pitch; // semitones -12..12 (0 = default)
  double bass; // dB -12..12
  double treble; // dB -12..12
  bool echo; // echo/robot voice effect

  bool get hasVisualExtras =>
      rotate != 0 ||
      mirror ||
      flipV ||
      reverse ||
      freezeDur > 0 ||
      cropAspect > 0 ||
      kenBurns.isNotEmpty ||
      chromaEnabled ||
      vignette > 0 ||
      grain > 0 ||
      brightness != 0 ||
      contrast != 1 ||
      saturation != 1 ||
      warmth != 0 ||
      sharpen > 0;

  bool get hasAudioExtras => pitch != 0 || bass != 0 || treble != 0 || echo;

  VideoClip({
    required this.id,
    required this.path,
    required this.name,
    required this.sourceDuration,
    this.trimStart = 0,
    double? trimEnd,
    this.speed = 1.0,
    this.volume = 1.0,
    this.filterId = 'original',
    this.filterIntensity = 0.8,
    this.transitionToNext = Transitions.none,
    this.rotate = 0,
    this.mirror = false,
    this.flipV = false,
    this.reverse = false,
    this.freezeDur = 0,
    this.cropAspect = 0,
    this.kenBurns = '',
    this.chromaEnabled = false,
    this.chromaColor = '22DD44',
    this.chromaSimilarity = 0.14,
    this.chromaBlend = 0.08,
    this.brightness = 0,
    this.contrast = 1,
    this.saturation = 1,
    this.warmth = 0,
    this.sharpen = 0,
    this.vignette = 0,
    this.grain = 0,
    this.pitch = 0,
    this.bass = 0,
    this.treble = 0,
    this.echo = false,
  }) : trimEnd = trimEnd ?? sourceDuration;

  double get sourceLength => (trimEnd - trimStart).clamp(0.05, 1e9);
  double get timelineLength => sourceLength / speed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'sourceDuration': sourceDuration,
        'trimStart': trimStart,
        'trimEnd': trimEnd,
        'speed': speed,
        'volume': volume,
        'filterId': filterId,
        'filterIntensity': filterIntensity,
        'transitionToNext': transitionToNext.toJson(),
        'rotate': rotate,
        'mirror': mirror,
        'flipV': flipV,
        'reverse': reverse,
        'freezeDur': freezeDur,
        'cropAspect': cropAspect,
        'kenBurns': kenBurns,
        'chromaEnabled': chromaEnabled,
        'chromaColor': chromaColor,
        'chromaSimilarity': chromaSimilarity,
        'chromaBlend': chromaBlend,
        'brightness': brightness,
        'contrast': contrast,
        'saturation': saturation,
        'warmth': warmth,
        'sharpen': sharpen,
        'vignette': vignette,
        'grain': grain,
        'pitch': pitch,
        'bass': bass,
        'treble': treble,
        'echo': echo,
      };

  factory VideoClip.fromJson(Map<String, dynamic> j) => VideoClip(
        id: j['id'] as String,
        path: j['path'] as String? ?? '',
        name: j['name'] as String? ?? 'Clip',
        sourceDuration: (j['sourceDuration'] as num?)?.toDouble() ?? 0,
        trimStart: (j['trimStart'] as num?)?.toDouble() ?? 0,
        trimEnd: (j['trimEnd'] as num?)?.toDouble(),
        speed: (j['speed'] as num?)?.toDouble() ?? 1,
        volume: (j['volume'] as num?)?.toDouble() ?? 1,
        filterId: j['filterId'] as String? ?? 'original',
        filterIntensity: (j['filterIntensity'] as num?)?.toDouble() ?? 0.8,
        transitionToNext: TransitionSpec.fromJson(
            (j['transitionToNext'] as Map?)?.cast<String, dynamic>() ?? {}),
        rotate: (j['rotate'] as num?)?.toInt() ?? 0,
        mirror: j['mirror'] as bool? ?? false,
        flipV: j['flipV'] as bool? ?? false,
        reverse: j['reverse'] as bool? ?? false,
        freezeDur: (j['freezeDur'] as num?)?.toDouble() ?? 0,
        cropAspect: (j['cropAspect'] as num?)?.toDouble() ?? 0,
        kenBurns: j['kenBurns'] as String? ?? '',
        chromaEnabled: j['chromaEnabled'] as bool? ?? false,
        chromaColor: j['chromaColor'] as String? ?? '22DD44',
        chromaSimilarity: (j['chromaSimilarity'] as num?)?.toDouble() ?? 0.14,
        chromaBlend: (j['chromaBlend'] as num?)?.toDouble() ?? 0.08,
        brightness: (j['brightness'] as num?)?.toDouble() ?? 0,
        contrast: (j['contrast'] as num?)?.toDouble() ?? 1,
        saturation: (j['saturation'] as num?)?.toDouble() ?? 1,
        warmth: (j['warmth'] as num?)?.toDouble() ?? 0,
        sharpen: (j['sharpen'] as num?)?.toDouble() ?? 0,
        vignette: (j['vignette'] as num?)?.toDouble() ?? 0,
        grain: (j['grain'] as num?)?.toDouble() ?? 0,
        pitch: (j['pitch'] as num?)?.toDouble() ?? 0,
        bass: (j['bass'] as num?)?.toDouble() ?? 0,
        treble: (j['treble'] as num?)?.toDouble() ?? 0,
        echo: j['echo'] as bool? ?? false,
      );

  VideoClip copyWith({
    String? path,
    String? name,
    double? trimStart,
    double? trimEnd,
    double? speed,
    double? volume,
    String? filterId,
    double? filterIntensity,
    TransitionSpec? transitionToNext,
    int? rotate,
    bool? mirror,
    bool? flipV,
    bool? reverse,
    double? freezeDur,
    double? cropAspect,
    String? kenBurns,
    bool? chromaEnabled,
    String? chromaColor,
    double? chromaSimilarity,
    double? chromaBlend,
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    double? sharpen,
    double? vignette,
    double? grain,
    double? pitch,
    double? bass,
    double? treble,
    bool? echo,
  }) =>
      VideoClip(
        id: id,
        path: path ?? this.path,
        name: name ?? this.name,
        sourceDuration: sourceDuration,
        trimStart: trimStart ?? this.trimStart,
        trimEnd: trimEnd ?? this.trimEnd,
        speed: speed ?? this.speed,
        volume: volume ?? this.volume,
        filterId: filterId ?? this.filterId,
        filterIntensity: filterIntensity ?? this.filterIntensity,
        transitionToNext: transitionToNext ?? this.transitionToNext,
        rotate: rotate ?? this.rotate,
        mirror: mirror ?? this.mirror,
        flipV: flipV ?? this.flipV,
        reverse: reverse ?? this.reverse,
        freezeDur: freezeDur ?? this.freezeDur,
        cropAspect: cropAspect ?? this.cropAspect,
        kenBurns: kenBurns ?? this.kenBurns,
        chromaEnabled: chromaEnabled ?? this.chromaEnabled,
        chromaColor: chromaColor ?? this.chromaColor,
        chromaSimilarity: chromaSimilarity ?? this.chromaSimilarity,
        chromaBlend: chromaBlend ?? this.chromaBlend,
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        warmth: warmth ?? this.warmth,
        sharpen: sharpen ?? this.sharpen,
        vignette: vignette ?? this.vignette,
        grain: grain ?? this.grain,
        pitch: pitch ?? this.pitch,
        bass: bass ?? this.bass,
        treble: treble ?? this.treble,
        echo: echo ?? this.echo,
      );
}

/// The whole editing project — saved as one JSON file per project.
class VideoProject {
  final String id;
  String name;
  List<VideoClip> clips;
  List<CaptionSegment> captions;
  List<OverlayItem> overlays;
  List<AudioTrack> audioTracks;
  String thumbPath; // generated after import
  final DateTime createdAt;
  DateTime updatedAt;
  String captionStyleId; // project-wide default style

  VideoProject({
    required this.id,
    required this.name,
    required this.clips,
    List<CaptionSegment>? captions,
    List<OverlayItem>? overlays,
    List<AudioTrack>? audioTracks,
    this.thumbPath = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.captionStyleId = 'tiktok_karaoke',
  })  : captions = captions ?? [],
        overlays = overlays ?? [],
        audioTracks = audioTracks ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  double get totalDuration =>
      clips.fold(0, (acc, c) => acc + c.timelineLength);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'clips': clips.map((c) => c.toJson()).toList(),
        'captions': captions.map((c) => c.toJson()).toList(),
        'overlays': overlays.map((o) => o.toJson()).toList(),
        'audioTracks': audioTracks.map((a) => a.toJson()).toList(),
        'thumbPath': thumbPath,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'captionStyleId': captionStyleId,
      };

  factory VideoProject.fromJson(Map<String, dynamic> j) => VideoProject(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Project',
        clips: ((j['clips'] as List?) ?? [])
            .map((c) => VideoClip.fromJson(c as Map<String, dynamic>))
            .toList(),
        captions: ((j['captions'] as List?) ?? [])
            .map((c) => CaptionSegment.fromJson(c as Map<String, dynamic>))
            .toList(),
        overlays: ((j['overlays'] as List?) ?? [])
            .map((o) => OverlayItem.fromJson(o as Map<String, dynamic>))
            .toList(),
        audioTracks: ((j['audioTracks'] as List?) ?? [])
            .map((a) => AudioTrack.fromJson(a as Map<String, dynamic>))
            .toList(),
        thumbPath: j['thumbPath'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int? ?? 0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updatedAt'] as int? ?? 0),
        captionStyleId: j['captionStyleId'] as String? ?? 'tiktok_karaoke',
      );

  VideoProject copyWith({
    String? name,
    List<VideoClip>? clips,
    List<CaptionSegment>? captions,
    List<OverlayItem>? overlays,
    List<AudioTrack>? audioTracks,
    String? thumbPath,
    String? captionStyleId,
  }) =>
      VideoProject(
        id: id,
        name: name ?? this.name,
        clips: clips ?? this.clips,
        captions: captions ?? this.captions,
        overlays: overlays ?? this.overlays,
        audioTracks: audioTracks ?? this.audioTracks,
        thumbPath: thumbPath ?? this.thumbPath,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        captionStyleId: captionStyleId ?? this.captionStyleId,
      );
}
