import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/project.dart';

/// Local-first project storage: one JSON per project under
/// <appDocuments>/montagy/projects/, media stays where the user picked it.
class StorageService {
  StorageService._();
  static final instance = StorageService._();
  final _uuid = const Uuid();

  Directory? _root;

  Future<Directory> root() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory('${docs.path}/montagy');
    await _root!.create(recursive: true);
    return _root!;
  }

  Future<Directory> projectsDir() async {
    final d = Directory('${(await root()).path}/projects');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<Directory> exportsDir() async {
    final d = Directory('${(await root()).path}/exports');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  Future<Directory> tmpDir() async {
    final d = Directory('${(await root()).path}/tmp');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Copy picked media into app storage so project files never dangle.
  Future<String> importMedia(String srcPath) async {
    final mediaDir = Directory('${(await root()).path}/media');
    if (!mediaDir.existsSync()) mediaDir.createSync(recursive: true);
    final name = '${_uuid.v4()}${_ext(srcPath)}';
    final dst = '${mediaDir.path}/$name';
    await File(srcPath).copy(dst);
    return dst;
  }

  String _ext(String p) {
    final i = p.lastIndexOf('.');
    return i == -1 ? '.mp4' : p.substring(i);
  }

  Future<String> newThumbPath(String projectId) async {
    final thumbs = Directory('${(await root()).path}/thumbs');
    if (!thumbs.existsSync()) thumbs.createSync(recursive: true);
    return '${thumbs.path}/$projectId.jpg';
  }

  Future<List<VideoProject>> listProjects() async {
    final dir = await projectsDir();
    final out = <VideoProject>[];
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          out.add(VideoProject.fromJson(jsonDecode(await f.readAsString())));
        } catch (_) {/* skip corrupt file */}
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<void> saveProject(VideoProject p) async {
    final dir = await projectsDir();
    final f = File('${dir.path}/${p.id}.json');
    await f.writeAsString(const JsonEncoder.withIndent(' ').convert(p.toJson()));
  }

  Future<void> deleteProject(String id) async {
    final dir = await projectsDir();
    final f = File('${dir.path}/$id.json');
    if (f.existsSync()) await f.delete();
  }

  Future<VideoProject> duplicateProject(VideoProject p) async {
    final copy = VideoProject(
      id: _uuid.v4(),
      name: '${p.name} (copy)',
      clips: p.clips,
      captions: p.captions,
      overlays: p.overlays,
      audioTracks: p.audioTracks,
      thumbPath: p.thumbPath,
      captionStyleId: p.captionStyleId,
    );
    await saveProject(copy);
    return copy;
  }
}
