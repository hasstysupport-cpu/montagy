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

/// لوحة الفلاتر — 42 فلتر LUT حقيقي بتصنيفات CapCut + شدة + تطبيق على الكل.
class FilterPanel extends StatelessWidget {
  const FilterPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final clip = state.selectedClip ?? state.project.clips.firstOrNull;
    if (clip == null) {
      return const PanelScroll(child: PanelHint('أضف مقطعاً أولاً'));
    }

    final currentId = FilterPresets.resolveId(clip.filterPreset);
    final currentCat = FilterPresets.byId(currentId)?.category ?? 'شائع';
    var cat = currentCat;

    return StatefulBuilder(builder: (context, setPanel) {
      return PanelScroll(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // التصنيفات (نمط CapCut)
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: FilterCategories.all.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final c = FilterCategories.all[i];
                  final selected = c == cat;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setPanel(() => cat = c),
                    labelStyle: AppFont.w(selected ? 700 : 500, size: 12,
                        color: selected ? Colors.white : null),
                    selectedColor: context.accent,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
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
              height: 128,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterThumb(
                    name: 'الأصلية',
                    thumbPath: clip.thumbPath,
                    thumbAsset: null,
                    matrix: null,
                    selected: clip.filterPreset == null,
                    onTap: () => state.updateClip(
                        clip.copyWith(filterPreset: null, clearFilter: true)),
                  ),
                  for (final f in FilterPresets.byCategory(cat))
                    _FilterThumb(
                      name: f.name,
                      thumbPath: clip.thumbPath,
                      thumbAsset: f.thumbAsset,
                      matrix: ColorFilterResolver.previewMatrix(
                        presetId: f.id,
                        intensity: 1,
                        adjust: ColorParams.neutral(),
                      ),
                      selected: currentId == f.id,
                      onTap: () => state.updateClip(
                          clip.copyWith(filterPreset: f.id),
                          structural: true),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _FilterThumb extends StatelessWidget {
  final String name;
  final String? thumbPath;
  final String? thumbAsset;
  final List<double>? matrix;
  final bool selected;
  final VoidCallback onTap;

  const _FilterThumb({
    required this.name,
    required this.thumbPath,
    required this.thumbAsset,
    required this.matrix,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    Widget? image;
    final fileOk = thumbPath != null && File(thumbPath!).existsSync();
    if (fileOk) {
      image = Image.file(
        File(thumbPath!),
        fit: BoxFit.cover,
        cacheWidth: 148,
        errorBuilder: (_, __, ___) => _assetOrIcon(),
      );
    } else {
      image = _assetOrIcon();
    }

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
              child: matrix == null
                  ? image
                  : ColorFiltered(
                      colorFilter: ColorFilter.matrix(matrix!),
                      child: image,
                    ),
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

  Widget _assetOrIcon() {
    if (thumbAsset != null) {
      return Image.asset(
        thumbAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.movie_filter_outlined, size: 26),
      );
    }
    return const Icon(Icons.movie_filter_outlined, size: 26);
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
