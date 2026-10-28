import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../widgets/common.dart';
import '../dialogs/text_edit_sheet.dart';
import '../editor_screen.dart';

/// لوحة النصوص — إضافة + قائمة النصوص الحالية.
class TextPanel extends StatelessWidget {
  const TextPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final texts = state.project.texts;

    return PanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => showTextEditSheet(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: AppFont.w(700, size: 13.5).make(S.addText),
                ),
              ),
            ],
          ),
          if (texts.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: texts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final t = texts[i];
                  final selected = state.selectedTextId == t.id;
                  return GestureDetector(
                    onTap: () {
                      state.selectText(t.id);
                      state.seekTo(t.start + 0.01);
                    },
                    onDoubleTap: () => showTextEditSheet(context, t),
                    onLongPress: () => showTextEditSheet(context, t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? context.accent.withValues(alpha: 0.16)
                            : Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkSurfaceHi
                                : AppColors.lightSurfaceHi,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              selected ? context.accent : Colors.transparent,
                          width: 1.6,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            t.text.isEmpty ? '(نص)' : t.text,
                            style: TextStyle(
                              fontFamily: t.fontFamily,
                              fontSize: 12,
                              color: selected ? context.accent : null,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            S.durationLabel(t.start),
                            style: AppFont.w(500,
                                size: 10, color: AppColors.cyan),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const PanelHint('اضغط ضغطة مطولة على أي نص لتحريره — اسحبه في المعاينة لتحريكه'),
          ],
        ],
      ),
    );
  }
}
