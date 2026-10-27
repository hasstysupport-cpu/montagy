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
