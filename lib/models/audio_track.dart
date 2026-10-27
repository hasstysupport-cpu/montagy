/// A background music / audio track laid over the project timeline.
class AudioTrack {
  final String id;
  String path;
  String name;
  double startAt; // where on the timeline it starts
  double volume; // 0..2
  double fadeIn; // seconds
  double fadeOut; // seconds

  AudioTrack({
    required this.id,
    required this.path,
    required this.name,
    this.startAt = 0,
    this.volume = 0.8,
    this.fadeIn = 0.5,
    this.fadeOut = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'startAt': startAt,
        'volume': volume,
        'fadeIn': fadeIn,
        'fadeOut': fadeOut,
      };

  factory AudioTrack.fromJson(Map<String, dynamic> j) => AudioTrack(
        id: j['id'] as String,
        path: j['path'] as String? ?? '',
        name: j['name'] as String? ?? 'Music',
        startAt: (j['startAt'] as num?)?.toDouble() ?? 0,
        volume: (j['volume'] as num?)?.toDouble() ?? 0.8,
        fadeIn: (j['fadeIn'] as num?)?.toDouble() ?? 0.5,
        fadeOut: (j['fadeOut'] as num?)?.toDouble() ?? 1.0,
      );
}
