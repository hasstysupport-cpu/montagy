import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/font_catalog.dart';
import '../../../data/models.dart';
import '../../../editor/editor_state.dart';
import '../../../services/projects_store.dart';
import '../editor_screen.dart';

/// لوحة الملصقات — إيموجي + صور.
class StickerPanel extends StatelessWidget {
  const StickerPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final categories = EmojiCatalog.categories.entries.toList();

    return SizedBox(
      height: 148,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(context, state),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: AppFont.w(600, size: 12.5).make(S.imageOverlay),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: DefaultTabController(
              length: categories.length,
              child: Column(
                children: [
                  SizedBox(
                    height: 34,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      dividerColor: Colors.transparent,
                      labelStyle: AppFont.w(700, size: 11.5),
                      unselectedLabelStyle: AppFont.w(500, size: 11.5),
                      tabs: [
                        for (final c in categories)
                          Tab(text: c.key.trim()),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        for (final c in categories)
                          GridView.builder(
                            scrollDirection: Axis.horizontal,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 4,
                              crossAxisSpacing: 4,
                              childAspectRatio: 1.0,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            itemCount: c.value.length,
                            itemBuilder: (ctx, i) => GestureDetector(
                              onTap: () => _addEmoji(context, state, c.value[i]),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.darkSurfaceHi
                                      : AppColors.lightSurfaceHi,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    c.value[i],
                                    style: const TextStyle(fontSize: 22),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addEmoji(BuildContext context, EditorState state, String emoji) {
    final t = state.projectTime;
    state.addSticker(ImageOverlay(
      id: ProjectsStore.newId(),
      emoji: emoji,
      start: t,
      end: (t + 3).clamp(t, state.totalDuration),
      animIn: TextAnim.fade,
      animOut: TextAnim.fade,
    ));
  }

  Future<void> _pickImage(BuildContext context, EditorState state) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.paths.isEmpty) return;
    final path = result.paths.whereType<String>().first;
    final imported = await ProjectsStore.importAsset(path);
    if (imported == null || !context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر استيراد الصورة')),
      );
      return;
    }
    if (!File(imported).existsSync()) return;
    final t = state.projectTime;
    state.addSticker(ImageOverlay(
      id: ProjectsStore.newId(),
      imagePath: imported,
      start: t,
      end: (t + 3).clamp(t, state.totalDuration),
      animIn: TextAnim.fade,
      animOut: TextAnim.fade,
    ));
  }
}
