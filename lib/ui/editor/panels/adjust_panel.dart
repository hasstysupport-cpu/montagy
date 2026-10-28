import 'package:flutter/material.dart';

import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/models.dart';
import '../../widgets/common.dart';
import '../editor_screen.dart';

/// لوحة التعديل اللوني — سطوع/تباين/تشبع/دفء/صبغة/تلاشي/تظليل.
class AdjustPanel extends StatelessWidget {
  const AdjustPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final clip = state.selectedClip ?? state.project.clips.firstOrNull;
    if (clip == null) {
      return const PanelScroll(child: PanelHint('أضف مقطعاً أولاً'));
    }
    final a = clip.adjust;

    return PanelScroll(
      child: Column(
        children: [
          LabeledSlider(
            label: S.brightness,
            value: a.brightness,
            min: -1,
            max: 1,
            display: (v) => v.toStringAsFixed(2),
            onChanged: (v) => state.updateClip(
                clip.copyWith(adjust: a.copyWith(brightness: v))),
          ),
          LabeledSlider(
            label: S.contrast,
            value: a.contrast,
            min: -1,
            max: 1,
            display: (v) => v.toStringAsFixed(2),
            onChanged: (v) => state.updateClip(
                clip.copyWith(adjust: a.copyWith(contrast: v))),
          ),
          LabeledSlider(
            label: S.saturation,
            value: a.saturation,
            min: -1,
            max: 1,
            display: (v) => v.toStringAsFixed(2),
            onChanged: (v) => state.updateClip(
                clip.copyWith(adjust: a.copyWith(saturation: v))),
          ),
          LabeledSlider(
            label: S.warmth,
            value: a.warmth,
            min: -1,
            max: 1,
            display: (v) => v >= 0 ? '+${v.toStringAsFixed(2)}' : v.toStringAsFixed(2),
            onChanged: (v) => state.updateClip(
                clip.copyWith(adjust: a.copyWith(warmth: v))),
          ),
          LabeledSlider(
            label: S.tint,
            value: a.tint,
            min: -1,
            max: 1,
            display: (v) => v >= 0 ? '+${v.toStringAsFixed(2)}' : v.toStringAsFixed(2),
            onChanged: (v) => state.updateClip(
                clip.copyWith(adjust: a.copyWith(tint: v))),
          ),
          LabeledSlider(
            label: S.fade,
            value: a.fade,
            min: 0,
            max: 1,
            display: (v) => v.toStringAsFixed(2),
            onChanged: (v) => state.updateClip(
                clip.copyWith(adjust: a.copyWith(fade: v))),
          ),
          LabeledSlider(
            label: S.vignette,
            value: a.vignette,
            min: 0,
            max: 1,
            display: (v) => v.toStringAsFixed(2),
            onChanged: (v) => state.updateClip(
                clip.copyWith(adjust: a.copyWith(vignette: v))),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 17),
                  label: AppFont.w(600, size: 12.5).make(S.reset),
                  onPressed: a.isNeutral
                      ? null
                      : () => state.updateClip(
                          clip.copyWith(adjust: ColorParams.neutral())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.select_all, size: 17),
                  label: AppFont.w(600, size: 12.5).make(S.applyToAll),
                  onPressed: () {
                    for (final c in state.project.clips) {
                      state.updateClip(
                          c.copyWith(adjust: a));
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
