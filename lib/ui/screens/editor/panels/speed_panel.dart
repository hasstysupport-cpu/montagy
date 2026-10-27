import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../state/editor_controller.dart';

class SpeedPanel extends ConsumerWidget {
  const SpeedPanel({super.key});

  static const presets = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final speed = st.project.clips.firstOrNull?.speed ?? 1.0;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('speed'), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in presets)
                ChoiceChip(
                  label: Text(s == 1.0 ? context.tr('normal') : '${s}x'),
                  selected: speed == s,
                  onSelected: (_) {
                    for (var i = 0; i < st.project.clips.length; i++) {
                      ctrl.updateClip(i, (c) => c.speed = s);
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.speed, color: AppColors.accent, size: 20),
              Expanded(
                child: Slider(
                  value: speed.clamp(0.25, 4.0),
                  min: 0.25, max: 4.0, divisions: 75,
                  label: '${speed.toStringAsFixed(2)}x',
                  onChanged: (v) => ctrl.updateClip(0, (c) => c.speed = v, snapshot: false),
                  onChangeEnd: (v) {
                    for (var i = 1; i < st.project.clips.length; i++) {
                      ctrl.updateClip(i, (c) => c.speed = v);
                    }
                  },
                ),
              ),
              Text('${speed.toStringAsFixed(2)}x',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstY<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
