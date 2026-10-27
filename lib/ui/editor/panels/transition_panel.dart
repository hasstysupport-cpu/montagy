import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../widgets/common.dart';
import '../dialogs/transition_sheet.dart';
import '../editor_screen.dart';

/// لوحة الانتقالات — قائمة الفواصل بين المقاطع.
class TransitionPanel extends StatelessWidget {
  const TransitionPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    if (state.project.clips.length < 2) {
      return const PanelScroll(
        child: PanelHint('أضف مقطعين على الأقل لتطبيق الانتقالات'),
      );
    }

    return PanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PanelHint(S.transitionHint),
          for (var i = 0; i < state.project.clips.length - 1; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => showTransitionSheet(context, state.project.clips[i]),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: dark
                        ? AppColors.darkSurfaceHi
                        : AppColors.lightSurfaceHi,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: state.project.clips[i].transitionOutId != null
                              ? AppColors.brandGradient
                              : null,
                          color:
                              state.project.clips[i].transitionOutId != null
                                  ? null
                                  : (dark
                                      ? AppColors.darkBorder
                                      : AppColors.lightBorder),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.swap_horiz,
                            size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'بين ${state.project.clips[i].title} و ${state.project.clips[i + 1].title}',
                              style: AppFont.w(600, size: 12.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppFont.w(400, size: 10,
                                    color: dark
                                        ? AppColors.darkTextDim
                                        : AppColors.lightTextDim)
                                .make(
                              state.project.clips[i].transitionOutId != null
                                  ? 'انتقال مُطبَّق • ${state.project.clips[i].transitionDuration.toStringAsFixed(1)}s'
                                  : S.noTransition,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_left, size: 18),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
