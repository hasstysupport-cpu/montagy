import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/transition.dart';
import '../../../../state/editor_controller.dart';

class TransitionsPanel extends ConsumerWidget {
  const TransitionsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final current = st.project.clips.firstOrNull?.transitionToNext.id ?? '';

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('tool_transitions'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text('${context.tr('transition')} (${st.project.clips.length} clips)',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textDim)),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.95),
              itemCount: Transitions.all.length,
              itemBuilder: (context, i) {
                final tr = Transitions.all[i];
                final active = current == tr.id;
                return GestureDetector(
                  onTap: () {
                    for (var c = 0; c < st.project.clips.length; c++) {
                      ctrl.updateClip(c, (clip) => clip.transitionToNext = TransitionSpec(id: tr.id));
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary.withOpacity(.18) : AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppColors.primary : Colors.transparent, width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_icon(tr.id), size: 24,
                            color: active ? AppColors.primary : AppColors.textDim),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            _name(context, tr.id),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.cairo(
                                fontSize: 9.5,
                                color: active ? AppColors.primary : AppColors.textDim),
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

  IconData _icon(String id) => switch (id) {
        '' => Icons.block,
        'fade' => Icons.blur_on,
        'dissolve' => Icons.grain,
        'wipeleft' => Icons.west,
        'wiperight' => Icons.east,
        'slideleft' => Icons.chevron_left,
        'circleopen' => Icons.radio_button_unchecked,
        'pixelize' => Icons.apps,
        'smoothleft' => Icons.waves,
        'zoomin' => Icons.zoom_in,
        'hblur' => Icons.blur_linear,
        'radial' => Icons.brightness_5,
        _ => Icons.swap_horiz,
      };

  String _name(BuildContext context, String id) => switch (id) {
        '' => context.tr('no_transition'),
        'fade' => context.tr('tr_fade'),
        'dissolve' => context.tr('tr_dissolve'),
        'wipeleft' => context.tr('tr_wipeleft'),
        'wiperight' => context.tr('tr_wiperight'),
        'slideleft' => context.tr('tr_slideleft'),
        'circleopen' => context.tr('tr_circleopen'),
        'pixelize' => context.tr('tr_pixelize'),
        'smoothleft' => context.tr('tr_smoothleft'),
        'zoomin' => context.tr('tr_zoomin'),
        'hblur' => context.tr('tr_hblur'),
        'radial' => context.tr('tr_radial'),
        _ => id,
      };
}

extension _FirstW<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
