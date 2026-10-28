import 'dart:io';

import 'ffmpeg_gateway.dart';
import 'projects_store.dart';

/// توليد شرائط مصغرات المقاطع (6 إطارات لكل مقطع) — نمط CapCut.
class ThumbStrip {
  /// يولد N مصغرات موزعة على مدى القص ويعيد مساراتها.
  static Future<List<String>> generate({
    required String sourcePath,
    required double from,
    required double to,
    int count = 6,
  }) async {
    if (!File(sourcePath).existsSync()) return const [];
    if (to <= from) return const [];
    try {
      final dir = await ProjectsStore.thumbsDir();
      final stripDir = Directory('${dir.path}/strip');
      if (!stripDir.existsSync()) stripDir.createSync(recursive: true);
      final key = ProjectsStore.newId();
      final out = <String>[];

      final step = (to - from) / count;
      for (var i = 0; i < count; i++) {
        final at = from + step * (i + 0.5);
        final path = '${stripDir.path}/${key}_$i.jpg';
        final session = await FFmpegKit.executeWithArguments([
          '-y',
          '-ss', at.toStringAsFixed(2),
          '-i', sourcePath,
          '-frames:v', '1',
          '-vf', 'scale=112:-2',
          '-q:v', '6',
          path,
        ]);
        final rc = await session.getReturnCode();
        if (ReturnCode.isSuccess(rc) && File(path).existsSync()) {
          out.add(path);
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
