import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/models.dart';
import '../../widgets/common.dart';
import '../editor_screen.dart';

/// حوار السرعة (شرائح + سلايدر دقيق).
Future<void> showSpeedSheet(BuildContext context, ClipItem clip) async {
  final state = EditorScope.of(context);
  final speeds = <double>[0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4];
  var value = clip.speed.clamp(0.25, 4).toDouble();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppFont.w(800, size: 17).make(S.speed),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AppFont.w(800, size: 14, color: Colors.white)
                      .make(S.speedLabel(value)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: speeds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final v = speeds[i];
                  final sel = (v - value).abs() < 0.01;
                  return ChoiceChip(
                    label: Text(S.speedLabel(v)),
                    selected: sel,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setSheet(() => value = v);
                    },
                    selectedColor: ctx.accent,
                    showCheckmark: false,
                    labelStyle: AppFont.w(sel ? 700 : 500,
                        size: 12.5, color: sel ? Colors.white : null),
                  );
                },
              ),
            ),
            LabeledSlider(
              label: S.speed,
              value: value,
              min: 0.25,
              max: 4,
              display: S.speedLabel,
              onChanged: (v) => setSheet(() => value = v),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(S.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      state.pushUndo();
                      state.updateClip(
                        clip.copyWith(speed: (value * 100).round() / 100),
                        seekAfter: true,
                      );
                    },
                    child: const Text(S.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// حوار مستوى الصوت للمقطع.
Future<void> showVolumeSheet(BuildContext context, ClipItem clip) async {
  final state = EditorScope.of(context);
  var value = clip.volume.clamp(0, 2).toDouble();
  var muted = clip.muted;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppFont.w(800, size: 17).make(S.volume),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setSheet(() => muted = !muted),
                  icon: Icon(
                    muted ? Icons.volume_off : Icons.volume_up,
                    color: muted ? AppColors.danger : ctx.accent,
                  ),
                  label: Text(
                    muted ? S.unmute : S.mute,
                    style: AppFont.w(600,
                        size: 13,
                        color: muted ? AppColors.danger : ctx.accent),
                  ),
                ),
              ],
            ),
            LabeledSlider(
              label: S.volume,
              value: value,
              min: 0,
              max: 2,
              display: (v) => '${(v * 100).round()}%',
              onChanged: (v) => setSheet(() => value = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  state.updateClip(
                    clip.copyWith(
                      volume: (value * 100).round() / 100,
                      muted: muted || value == 0,
                    ),
                  );
                },
                child: const Text(S.save),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// حوار مدة الصورة.
Future<void> showPhotoDurationSheet(BuildContext context, ClipItem clip) async {
  final state = EditorScope.of(context);
  var value = clip.photoDuration.clamp(0.3, 30).toDouble();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFont.w(800, size: 17).make(S.photoDuration),
            const SizedBox(height: 14),
            LabeledSlider(
              label: S.duration,
              value: value,
              min: 0.3,
              max: 30,
              display: (v) => '${v.toStringAsFixed(1)}s',
              onChanged: (v) => setSheet(() => value = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  state.updateClip(
                    clip.copyWith(photoDuration: (value * 10).round() / 10),
                  );
                },
                child: const Text(S.save),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
