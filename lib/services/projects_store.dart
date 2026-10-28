import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../data/models.dart';
import 'ffmpeg_gateway.dart';

/// تخزين المشاريع + استيراد الوسائط + فحصها.
class ProjectsStore {
  static const _uuid = Uuid();

  static Future<Directory> _root() async {
    final app = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(app.path, 'projects'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> mediaDir() async {
    final app = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(app.path, 'media'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> thumbsDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(p.join(tmp.path, 'thumbs'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> exportsDir() async {
    final app = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(app.path, 'exports'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  // ── المشاريع ──

  static Future<List<Project>> listAll() async {
    final root = await _root();
    final projects = <Project>[];
    for (final f in root.listSync()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          final map =
              jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          if (map['v'] == 2) projects.add(Project.fromJson(map));
        } catch (_) {}
      }
    }
    projects.sort((a, b) => b.modified.compareTo(a.modified));
    return projects;
  }

  static Future<void> save(Project project) async {
    project.modified = DateTime.now();
    final root = await _root();
    final f = File(p.join(root.path, '${project.id}.json'));
    await f.writeAsString(jsonEncode(project.toJson()));
  }

  static Future<void> delete(Project project) async {
    final root = await _root();
    final f = File(p.join(root.path, '${project.id}.json'));
    if (f.existsSync()) f.deleteSync();
  }

  static String newId() => _uuid.v4();

  // ── استيراد الوسائط ──

  /// ينسخ الملفات المختارة إلى مساحة التطبيق وينشئ المقاطع.
  static Future<List<ClipItem>> importFiles(List<String> paths) async {
    final media = await mediaDir();
    final clips = <ClipItem>[];
    for (final path in paths) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final ext = p.extension(path).toLowerCase();
      final isVideo =
          ['.mp4', '.mov', '.mkv', '.avi', '.webm', '.3gp', '.m4v'].contains(ext);
      final isImage =
          ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp'].contains(ext);
      if (!isVideo && !isImage) continue;

      final id = newId();
      final dest = p.join(media.path, '$id$ext');
      try {
        await file.copy(dest);
      } catch (_) {
        continue;
      }

      if (isVideo) {
        final info = await probeVideo(dest);
        final dur = info?.$1 ?? 0;
        if (dur <= 0) {
          try { File(dest).deleteSync(); } catch (_) {}
          continue;
        }
        final thumb = await makeThumb(dest);
        clips.add(ClipItem(
          id: newId(),
          type: MediaType.video,
          sourcePath: dest,
          title: p.basenameWithoutExtension(path),
          inPoint: 0,
          outPoint: dur,
          sourceDuration: dur,
          sourceSize: info?.$2 ?? Size.zero,
          hasAudio: info?.$3 ?? true,
          thumbPath: thumb,
        ));
      } else {
        clips.add(ClipItem(
          id: newId(),
          type: MediaType.photo,
          sourcePath: dest,
          title: p.basenameWithoutExtension(path),
          photoDuration: 3,
          sourceDuration: 3,
          hasAudio: false,
          thumbPath: dest,
        ));
      }
    }
    return clips;
  }

  static Future<String?> makeThumb(String videoPath,
      {int timeMs = 0, int maxHeight = 160, int quality = 70}) async {
    try {
      final dir = await thumbsDir();
      return await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: dir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: maxHeight,
        quality: quality,
        timeMs: timeMs,
      );
    } catch (_) {
      return null;
    }
  }

  /// فحص الفيديو: (المدة، الأبعاد، به صوت؟)
  static Future<(double, Size, bool)?> probeVideo(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      if (info == null) return null;
      final dur = double.tryParse(info.getDuration() ?? '') ?? 0;
      var size = Size.zero;
      var hasAudio = false;
      final streams = info.getStreams();
      for (final s in streams) {
        if (s.getType() == 'video' && size == Size.zero) {
          final w = s.getWidth() ?? 0;
          final h = s.getHeight() ?? 0;
          size = Size(w.toDouble(), h.toDouble());
        }
        if (s.getType() == 'audio') hasAudio = true;
      }
      return (dur, size, hasAudio);
    } catch (_) {
      return null;
    }
  }

  /// نسخ ملف صوت/صورة إلى مساحة التطبيق.
  static Future<String?> importAsset(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    final media = await mediaDir();
    final dest = p.join(media.path, '${newId()}${p.extension(path)}');
    try {
      await file.copy(dest);
      return dest;
    } catch (_) {
      return null;
    }
  }

  static Future<(int, int)> cacheSizes() async {
    final tmp = await getTemporaryDirectory();
    final thumbs = Directory(p.join(tmp.path, 'thumbs'));
    var thumbBytes = 0;
    if (thumbs.existsSync()) {
      thumbBytes = thumbs
          .listSync()
          .fold<int>(0, (a, f) => a + (f is File ? f.lengthSync() : 0));
    }
    final media = await mediaDir();
    var mediaBytes = 0;
    if (media.existsSync()) {
      mediaBytes = media
          .listSync()
          .fold<int>(0, (a, f) => a + (f is File ? f.lengthSync() : 0));
    }
    return (thumbBytes, mediaBytes);
  }

  static Future<void> clearThumbCache() async {
    final tmp = await getTemporaryDirectory();
    final thumbs = Directory(p.join(tmp.path, 'thumbs'));
    if (thumbs.existsSync()) thumbs.deleteSync(recursive: true);
  }
}
