import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/filter.dart';
import '../../../../state/editor_controller.dart';

class FiltersPanel extends ConsumerWidget {
  const FiltersPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final currentFilter = st.project.clips.firstOrNull?.filterId ?? 'original';
    final intensity = st.project.clips.firstOrNull?.filterIntensity ?? 0.8;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('tool_filters'), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(context.tr('intensity'), style: GoogleFonts.cairo(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: intensity,
                  onChanged: (v) => ctrl.updateClip(0, (c) => c.filterIntensity = v, snapshot: false),
                  onChangeEnd: (v) => ctrl.updateClip(0, (c) => c.filterIntensity = v),
                ),
              ),
            ],
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.8),
              itemCount: Filters.all.length,
              itemBuilder: (context, i) {
                final f = Filters.all[i];
                final active = currentFilter == f.id;
                return GestureDetector(
                  onTap: () {
                    for (var c = 0; c < st.project.clips.length; c++) {
                      ctrl.updateClip(c, (clip) => clip.filterId = f.id);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: active ? AppColors.accent : Colors.transparent, width: 2),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              gradient: LinearGradient(
                                colors: [f.swatch1, f.swatch2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                f.id == 'original' ? Icons.circle_outlined : Icons.auto_awesome,
                                color: Colors.white.withOpacity(.9),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _name(context, f.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.cairo(
                            fontSize: 9,
                            color: active ? AppColors.accent : AppColors.textDim,
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

  String _name(BuildContext context, String id) => switch (id) {
        'original' => context.tr('filter_original'),
        'vivid' => context.tr('filter_vivid'),
        'cinematic' => context.tr('filter_cinematic'),
        'bw' => context.tr('filter_bw'),
        'vintage' => context.tr('filter_vintage'),
        'cool' => context.tr('filter_cool'),
        'warm' => context.tr('filter_warm'),
        'fade' => context.tr('filter_fade'),
        'noir' => context.tr('filter_noir'),
        'neondream' => context.tr('filter_neondream'),
        _ => id,
      };
}

extension _FirstX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
