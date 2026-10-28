import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../data/effects_catalog.dart';
import '../../../data/models.dart';
import '../../widgets/common.dart';
import '../editor_screen.dart';

/// لوحة المؤثرات — نمط CapCut: شبكة مؤثرات + شدة لكل مؤثر مفعّل.
class EffectsPanel extends StatelessWidget {
  const EffectsPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final clip = state.selectedClip ?? state.project.clips.firstOrNull;
    if (clip == null) {
      return const PanelScroll(child: PanelHint('أضف مقطعاً أولاً'));
    }

    final active = clip.effects.entries
        .where((e) => e.value > 0.01)
        .toList(growable: false);

    return PanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (active.isNotEmpty) ...[
            AppFont.w(700, size: 12, color: context.accent).make('المفعّلة'),
            const SizedBox(height: 8),
            for (final e in active)
              _ActiveEffectRow(
                clip: clip,
                effectId: e.key,
                intensity: e.value,
              ),
            const SizedBox(height: 14),
          ],
          AppFont.w(700, size: 12, color: dark ? AppColors.darkTextDim : AppColors.lightTextDim)
              .make('كل المؤثرات — اضغط للتفعيل'),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: EffectsCatalog.all.length,
            itemBuilder: (ctx, i) {
              final fx = EffectsCatalog.all[i];
              final on = state.hasEffect(clip, fx.id);
              return _EffectCell(
                preset: fx,
                active: on,
                onTap: () {
                  if (on) {
                    state.removeEffect(clip, fx.id);
                  } else {
                    state.applyEffect(clip, fx.id, 0.6);
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EffectCell extends StatelessWidget {
  final EffectPreset preset;
  final bool active;
  final VoidCallback onTap;

  const _EffectCell({
    required this.preset,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.accent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.16)
                : (dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? accent : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(preset.emoji,
                  style: TextStyle(
                      fontSize: 24, color: dark ? Colors.white : null)),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  preset.name,
                  style: AppFont.w(600,
                      size: 9.5,
                      color: active
                          ? accent
                          : (dark ? AppColors.darkText : AppColors.lightText)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveEffectRow extends StatelessWidget {
  final ClipItem clip;
  final String effectId;
  final double intensity;

  const _ActiveEffectRow({
    required this.clip,
    required this.effectId,
    required this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final fx = EffectsCatalog.byId(effectId);
    if (fx == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(fx.emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 8),
          SizedBox(
            width: 76,
            child: AppFont.w(600, size: 11).make(fx.name),
          ),
          Expanded(
            child: Slider(
              value: intensity.clamp(0, 1),
              min: 0.05,
              max: 1,
              onChanged: (v) => state.applyEffect(clip, effectId, v),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => state.removeEffect(clip, effectId),
            icon: Icon(Icons.delete_outline,
                size: 18, color: AppColors.danger),
          ),
        ],
      ),
    );
  }
}
