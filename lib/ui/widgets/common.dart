import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_font.dart';

/// زر أداة في اللوحات.
class ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;
  final bool active;

  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.danger = false,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = context.accent;
    final dim = dark ? AppColors.darkTextDim : AppColors.lightTextDim;
    final color = danger
        ? AppColors.danger
        : active
            ? accent
            : enabled
                ? (dark ? AppColors.darkText : AppColors.lightText)
                : dim;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: active
                        ? accent.withValues(alpha: 0.15)
                        : (dark
                            ? AppColors.darkSurfaceHi
                            : AppColors.lightSurfaceHi),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 21, color: color),
                ),
                const SizedBox(height: 5),
                Text(label, style: AppFont.w(600, size: 9.5, color: color),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// صف سلايدر بعنوان وقيمة.
class LabeledSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String Function(double)? display;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;

  const LabeledSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.display,
    this.onChangeStart,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        SizedBox(
          width: 74,
          child: Text(label,
              style: AppFont.w(600,
                  size: 11.5,
                  color: dark ? AppColors.darkText : AppColors.lightText)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeStart:
                onChangeStart == null ? null : (_) => onChangeStart!(),
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            display?.call(value) ?? value.toStringAsFixed(1),
            style: AppFont.w(600, size: 11, color: context.accent),
            textAlign: TextAlign.start,
            textDirection: TextDirection.ltr,
          ),
        ),
      ],
    );
  }
}

/// شرائح اختيار أفقية.
class ChoiceChips<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const ChoiceChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final selected = options[i].$1 == value;
          return ChoiceChip(
            label: Text(options[i].$2),
            selected: selected,
            onSelected: (_) => onChanged(options[i].$1),
            labelStyle: AppFont.w(selected ? 700 : 500,
                size: 12, color: selected ? Colors.white : null),
            selectedColor: context.accent,
            backgroundColor:
                dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

/// عنوان صغير للوحة.
class PanelHint extends StatelessWidget {
  final String text;
  const PanelHint(this.text);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: AppFont.w(500,
            size: 11.5,
            color: dark ? AppColors.darkTextDim : AppColors.lightTextDim),
      ),
    );
  }
}

/// لوحة أفقية قابلة للتمرير.
class PanelScroll extends StatelessWidget {
  final Widget child;
  const PanelScroll({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: child,
    );
  }
}
