import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../state/editor_controller.dart';

/// v1.1 — manual color grade & look adjustments for the clip under the
/// playhead: brightness / contrast / saturation / warmth / sharpen /
/// vignette / grain (CapCut "Adjust" parity).
class AdjustPanel extends ConsumerWidget {
  const AdjustPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final idx = ctrl.clipIndexAtPlayhead();
    if (idx == -1) {
      return Center(child: Text(context.tr('no_clip_hint'),
          style: GoogleFonts.cairo(color: AppColors.textDim, fontSize: 13)));
    }
    final c = st.project.clips[idx];

    Widget slider(String label, double value, double min, double max,
        double def, ValueChanged<double> onChanged) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          SizedBox(
              width: 78,
              child: Text(label,
                  style: GoogleFonts.cairo(
                      fontSize: 11.5, color: AppColors.textDim))),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min, max: max,
              activeColor: AppColors.primary,
              onChanged: (v) => onChanged(v),
            ),
          ),
          GestureDetector(
            onTap: () => onChanged(def),
            child: Icon(Icons.restart_alt,
                size: 16, color: value == def ? AppColors.border : AppColors.textDim),
          ),
        ]),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(context.tr('adjust'),
              style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDim)),
          GestureDetector(
            onTap: () => ctrl.updateClip(idx, (c) {
              c.brightness = 0; c.contrast = 1; c.saturation = 1;
              c.warmth = 0; c.sharpen = 0; c.vignette = 0; c.grain = 0;
            }),
            child: Text(context.tr('reset_all'),
                style: GoogleFonts.cairo(fontSize: 11, color: AppColors.accent)),
          ),
        ]),
        const SizedBox(height: 4),
        slider(context.tr('brightness'), c.brightness, -0.3, 0.3, 0,
            (v) => ctrl.updateClip(idx, (c) => c.brightness = v, snapshot: false)),
        slider(context.tr('contrast'), c.contrast, 0.5, 2.0, 1,
            (v) => ctrl.updateClip(idx, (c) => c.contrast = v, snapshot: false)),
        slider(context.tr('saturation'), c.saturation, 0, 3.0, 1,
            (v) => ctrl.updateClip(idx, (c) => c.saturation = v, snapshot: false)),
        slider(context.tr('warmth'), c.warmth, -1, 1, 0,
            (v) => ctrl.updateClip(idx, (c) => c.warmth = v, snapshot: false)),
        slider(context.tr('sharpen'), c.sharpen, 0, 2, 0,
            (v) => ctrl.updateClip(idx, (c) => c.sharpen = v, snapshot: false)),
        slider(context.tr('vignette'), c.vignette, 0, 1, 0,
            (v) => ctrl.updateClip(idx, (c) => c.vignette = v, snapshot: false)),
        slider(context.tr('grain'), c.grain, 0, 1, 0,
            (v) => ctrl.updateClip(idx, (c) => c.grain = v, snapshot: false)),
      ]),
    );
  }
}
