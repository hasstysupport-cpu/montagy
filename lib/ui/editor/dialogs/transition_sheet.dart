import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/filter_presets.dart';
import '../../../data/models.dart';
import '../../widgets/common.dart';
import '../editor_screen.dart';

/// اختيار الانتقال بين المقطع الحالي والتالي.
Future<void> showTransitionSheet(BuildContext context, ClipItem clip) async {
  final state = EditorScope.of(context);
  var selected = clip.transitionOutId;
  var dur = clip.transitionDuration.clamp(0.2, 2.0).toDouble();

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
            AppFont.w(800, size: 17).make(S.transitions),
            const PanelHint(S.transitionHint),
            SizedBox(
              height: 84,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TransitionOption(
                    label: S.none,
                    icon: Icons.block,
                    selected: selected == null,
                    onTap: () => setSheet(() => selected = null),
                  ),
                  const SizedBox(width: 10),
                  for (final t in TransitionPresets.all) ...[
                    _TransitionOption(
                      label: t.name,
                      icon: _iconFor(t.id),
                      selected: selected == t.id,
                      onTap: () => setSheet(() => selected = t.id),
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            if (selected != null)
              LabeledSlider(
                label: S.transitionDuration,
                value: dur,
                min: 0.2,
                max: 2,
                display: (v) => '${v.toStringAsFixed(1)}s',
                onChanged: (v) => setSheet(() => dur = v),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  state.updateClip(
                    clip.copyWith(
                      transitionOutId: selected,
                      clearTransition: selected == null,
                      transitionDuration: dur,
                    ),
                    structural: true,
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

IconData _iconFor(String id) {
  switch (id) {
    case 'fade':
      return Icons.blur_on;
    case 'slideleft':
      return Icons.swap_horiz;
    case 'wiperight':
      return Icons.cleaning_services_outlined;
    case 'circleopen':
      return Icons.circle_outlined;
    case 'dissolve':
      return Icons.grain;
    case 'smoothleft':
      return Icons.waves;
    case 'zoomin':
      return Icons.zoom_in;
    case 'pixelize':
      return Icons.grid_on;
    case 'radial':
      return Icons.radio_button_checked;
    default:
      return Icons.auto_awesome_motion;
  }
}

class _TransitionOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TransitionOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 74,
        decoration: BoxDecoration(
          color: selected
              ? context.accent.withValues(alpha: 0.15)
              : (dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? context.accent
                : (dark ? AppColors.darkBorder : AppColors.lightBorder),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 24,
                color: selected ? context.accent : null),
            const SizedBox(height: 6),
            AppFont.w(600, size: 10,
                    color: selected ? context.accent : null)
                .make(label),
          ],
        ),
      ),
    );
  }
}
