import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/models.dart';
import '../../../editor/editor_state.dart';
import '../../widgets/common.dart';
import '../editor_screen.dart';

/// لوحة الكانفس — نسبة العرض + الخلفية.
class CanvasPanel extends StatelessWidget {
  const CanvasPanel();

  static const _aspects = [
    (AspectKind.r9_16, '9:16'),
    (AspectKind.r1_1, '1:1'),
    (AspectKind.r4_5, '4:5'),
    (AspectKind.r16_9, '16:9'),
    (AspectKind.r5_4, '5:4'),
    (AspectKind.r4_3, '4:3'),
    (AspectKind.r3_4, '3:4'),
    (AspectKind.r3_2, '3:2'),
    (AspectKind.r2_3, '2:3'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final canvas = state.project.canvas;

    return PanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(S.aspectRatio),
          SizedBox(
            height: 84,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final (kind, label) in _aspects)
                  _AspectOption(
                    label: label,
                    ratio: kind.ratio,
                    selected: canvas.aspect == kind,
                    onTap: () => state.setAspect(kind),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionTitle(S.background),
          Row(
            children: [
              _BgOption(
                label: 'أسود',
                color: Colors.black,
                selected: canvas.bg == CanvasBg.black,
                onTap: () => state.setCanvasBg(CanvasBg.black),
              ),
              const SizedBox(width: 10),
              _BgOption(
                label: 'أبيض',
                color: Colors.white,
                selected: canvas.bg == CanvasBg.white,
                onTap: () => state.setCanvasBg(CanvasBg.white),
              ),
              const SizedBox(width: 10),
              _BlurOption(
                selected: canvas.bg == CanvasBg.blur,
                onTap: () => state.setCanvasBg(CanvasBg.blur),
              ),
              const SizedBox(width: 10),
              _CustomColorOption(
                selected: canvas.bg == CanvasBg.custom,
                color: canvas.customColor,
                onTap: () => _pickColor(context, state),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, EditorState state) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppFont.w(700, size: 16).make(S.bgColor),
        content: SizedBox(
          width: 300,
          height: 260,
          child: GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            children: [
              for (final c in AppColors.canvasPalette)
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) {
      state.setCanvasBg(CanvasBg.custom, color: picked);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppFont.w(800, size: 13).make(text),
    );
  }
}

class _AspectOption extends StatelessWidget {
  final String label;
  final double ratio;
  final bool selected;
  final VoidCallback onTap;
  const _AspectOption({
    required this.label,
    required this.ratio,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    const h = 54.0;
    final w = h * ratio;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? context.accent.withValues(alpha: 0.13)
              : (dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? context.accent : Colors.transparent,
            width: 1.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: w.clamp(14, 60),
              height: h * 0.52,
              decoration: BoxDecoration(
                color: selected ? context.accent : Colors.grey,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            AppFont.w(600, size: 9.5,
                    color: selected ? context.accent : null)
                .make(label),
          ],
        ),
      ),
    );
  }
}

class _BgOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _BgOption({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.cyan : Colors.grey,
                width: 2.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        AppFont.w(500, size: 9.5).make(label),
      ],
    );
  }
}

class _BlurOption extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _BlurOption({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.cyan : Colors.grey,
                width: 2.4,
              ),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF35506E), Color(0xFF6B7F99),
                  Color(0xFF3A4C63), Color(0xFF5D7390),
                ],
                stops: [0.1, 0.4, 0.6, 0.9],
              ),
            ),
            child: const Icon(Icons.blur_on,
                size: 20, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 4),
        AppFont.w(500, size: 9.5).make(S.blurBg),
      ],
    );
  }
}

class _CustomColorOption extends StatelessWidget {
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _CustomColorOption({
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.cyan : Colors.grey,
                width: 2.4,
              ),
              color: Colors.grey.withValues(alpha: 0.25),
            ),
            child: const Icon(Icons.palette_outlined, size: 20),
          ),
        ),
        const SizedBox(height: 4),
        AppFont.w(500, size: 9.5).make('لون'),
      ],
    );
  }
}
