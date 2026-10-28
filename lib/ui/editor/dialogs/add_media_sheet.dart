import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../services/projects_store.dart';
import '../editor_screen.dart';

/// شيت إضافة وسائط (فيديو / صور) — مع رسائل أخطاء واضحة.
Future<void> showAddMediaSheet(BuildContext context) async {
  final state = EditorScope.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: AppFont.w(700, size: 15).make('إضافة إلى المشروع'),
            ),
            ListTile(
              leading: const Icon(Icons.movie_creation_outlined),
              title: const Text(S.pickVideos),
              onTap: () => Navigator.pop(ctx, 'video'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text(S.pickPhotos),
              onTap: () => Navigator.pop(ctx, 'image'),
            ),
          ],
        ),
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  List<String> paths;
  try {
    final result = await FilePicker.platform.pickFiles(
      type: action == 'video' ? FileType.video : FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    paths = result.paths.whereType<String>().toList();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تعذر فتح المعرض: $e'),
        backgroundColor: Colors.red.withValues(alpha: 0.85),
      ));
    }
    return;
  }
  if (paths.isEmpty) return;

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
        content: Text('جارٍ الاستيراد...'), duration: Duration(seconds: 1)),
  );

  final clips = await ProjectsStore.importFiles(paths);
  if (clips.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'تعذر استيراد الملفات (${paths.length} ملف) — تأكد أن الفيديو بصيغة مدعومة (mp4/mov) ويحتوي مقطعاً صالحاً'),
        backgroundColor: Colors.red.withValues(alpha: 0.85),
        duration: const Duration(seconds: 3),
      ));
    }
    return;
  }
  if (clips.length < paths.length) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('تم استيراد ${clips.length} من ${paths.length}'),
        duration: const Duration(milliseconds: 1400),
      ));
    }
  }
  await state.addClips(clips);
}
