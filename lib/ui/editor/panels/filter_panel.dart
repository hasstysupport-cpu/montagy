import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/color_engine.dart';
import '../../../data/filter_presets.dart';
import '../../../data/models.dart';
import '../../widgets/common.dart';
import '../editor_screen.dart';

/// لوحة الفلاتر — 44 فلتراً بمعاينة فورية + شدة + تطبيق على الكل.
class FilterPanel extends StatelessWidget {
  const FilterPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final clip = state.selectedClip ?? state.project.clips.firstOrNull;
    if (clip == null) {
      return const PanelScroll(child: PanelHint('أضف مقطعاً أولاً'));
    }

    final thumbOk = clip.thumbPath != null && File(clip.thumbPath!).existsSync();

    return PanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LabeledSlider(
                  label: 'الشدة',
                  value: clip.filterIntensity,
                  min: 0,
                  max: 1,
                  display: (v) => '${(v * 100).round()}%',
                  onChanged: (v) => state.updateClip(
                      clip.copyWith(filterIntensity: v)),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => state.applyFilterToAll(
                    clip.filterPreset, clip.filterIntensity),
                child: AppFont.w(700, size: 11.5, color: context.accent)
                    .make(S.applyToAll),
              ),
            ],
          ),
          SizedBox(
            height: 116,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterThumb(
                  name: 'الأصلية',
                  thumbPath: clip.thumbPath,
                  selected: clip.filterPreset == null,
                  onTap: () => state.updateClip(
                      clip.copyWith(filterPreset: null, clearFilter: true)),
                  preset: null,
                ),
                for (final f in FilterPresets.all)
                  _FilterThumb(
                    name: f.name,
                    thumbPath: clip.thumbPath,
                    selected: clip.filterPreset == f.id,
                    preset: f,
                    onTap: () => state.updateClip(
                        clip.copyWith(filterPreset: f.id),
                        structural: true),
                  ),
              ],
            ),
          ),
          if (!thumbOk)
            PanelHint(dark ? '' : ''),
        ],
      ),
    );
  }
}

class _FilterThumb extends StatelessWidget {
  final String name;
  final String? thumbPath;
  final FilterPreset? preset;
  final bool selected;
  final VoidCallback onTap;

  const _FilterThumb({
    required this.name,
    required this.thumbPath,
    required this.selected,
    required this.onTap,
    this.preset,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final matrix = preset == null
        ? null
        : ColorEngine.matrix(
            ColorEngine.resolve(preset!.params, 1, ColorParams.neutral()));

    final thumbOk = thumbPath != null && File(thumbPath!).existsSync();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 84,
        margin: const EdgeInsets.only(left: 10),
        child: Column(
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? context.accent : Colors.transparent,
                  width: 2.4,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: thumbOk
                  ? (matrix == null
                      ? Image.file(
                          File(thumbPath!),
                          fit: BoxFit.cover,
                          cacheWidth: 148,
                          errorBuilder: (_, __, ___) =>
                              const SizedBox.shrink(),
                        )
                      : ColorFiltered(
                          colorFilter: ColorFilter.matrix(matrix),
                          child: Image.file(
                            File(thumbPath!),
                            fit: BoxFit.cover,
                            cacheWidth: 148,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ))
                  : const Icon(Icons.movie_filter_outlined, size: 26),
            ),
            const SizedBox(height: 5),
            Text(
              name,
              style: AppFont.w(selected ? 700 : 500, size: 10,
                  color: selected ? context.accent : null),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
