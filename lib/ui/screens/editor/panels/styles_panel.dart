import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/caption.dart';
import '../../../../models/caption_style.dart';
import '../../../../state/editor_controller.dart';
import '../widgets/caption_renderer.dart';

/// Live style gallery — every card renders REAL caption text with the style,
/// exactly like the burned output will look.
class StylesPanel extends ConsumerWidget {
  const StylesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final sampleText = 'كابتشن تجريبي | Sample';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('style_gallery'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.62),
              itemCount: CaptionStylePresets.all.length,
              itemBuilder: (context, i) {
                final style = CaptionStylePresets.all[i];
                final active = st.project.captionStyleId == style.id;
                return GestureDetector(
                  onTap: () => ctrl.setCaptionStyleEverywhere(style.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? AppColors.accent : Colors.transparent, width: 2),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF3A3A52), Color(0xFF16161F)],
                              ),
                            ),
                            child: Center(
                              child: buildCaptionWidget(
                                segment: CaptionSegment(
                                  id: 'preview',
                                  text: sampleText,
                                  start: 0,
                                  end: 10,
                                  styleId: style.id,
                                ),
                                style: style,
                                t: 0.5, // mid-sample (karaoke first words lit)
                                videoHeightPx: 130,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Text(
                            context.tr('style_${style.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              color: active ? AppColors.accent : AppColors.textDim,
                              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
