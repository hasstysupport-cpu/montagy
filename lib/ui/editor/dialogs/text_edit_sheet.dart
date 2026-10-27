import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/font_catalog.dart';
import '../../../data/models.dart';
import '../../../editor/editor_state.dart';
import '../../../services/projects_store.dart';
import '../../widgets/common.dart';
import '../editor_screen.dart';

/// محرر النص الكامل (إضافة/تعديل).
Future<void> showTextEditSheet(BuildContext context, [TextOverlay? existing]) async {
  final state = EditorScope.of(context);
  await Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _TextEditorPage(state: state, existing: existing),
  ));
}

class _TextEditorPage extends StatefulWidget {
  final EditorState state;
  final TextOverlay? existing;
  const _TextEditorPage({required this.state, required this.existing});

  @override
  State<_TextEditorPage> createState() => _TextEditorPageState();
}

class _TextEditorPageState extends State<_TextEditorPage> {
  late final TextEditingController _controller;
  late TextOverlay _draft;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _draft = widget.existing!;
      _controller = TextEditingController(text: _draft.text);
    } else {
      _controller = TextEditingController();
      final t = widget.state.projectTime;
      _draft = TextOverlay(
        id: ProjectsStore.newId(),
        start: t,
        end: (t + 3).clamp(t, widget.state.totalDuration),
        animIn: TextAnim.fade,
        animOut: TextAnim.fade,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _mut(void Function() fn) {
    setState(fn);
    // تحديث مباشر في المعاينة إن كان النص موجوداً
    if (widget.existing != null) {
      widget.existing!.text = _draft.text;
      widget.existing!.fontFamily = _draft.fontFamily;
      widget.existing!.fontSize = _draft.fontSize;
      widget.existing!.color = _draft.color;
      widget.existing!.textAlign = _draft.textAlign;
      widget.existing!.hasBg = _draft.hasBg;
      widget.existing!.bgColor = _draft.bgColor;
      widget.existing!.bgOpacity = _draft.bgOpacity;
      widget.existing!.hasStroke = _draft.hasStroke;
      widget.existing!.strokeColor = _draft.strokeColor;
      widget.existing!.strokeWidth = _draft.strokeWidth;
      widget.existing!.hasShadow = _draft.hasShadow;
      widget.existing!.rotation = _draft.rotation;
      widget.existing!.scale = _draft.scale;
      widget.existing!.animIn = _draft.animIn;
      widget.existing!.animOut = _draft.animOut;
      widget.existing!.animDur = _draft.animDur;
      widget.state.updateText(widget.existing!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: AppFont.w(700, size: 16).make(existingLabel),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () {
                widget.state.deleteText(widget.existing!);
                Navigator.pop(context);
              },
            ),
          TextButton(
            onPressed: _save,
            child: const Text(S.save),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // مربع النص
              TextField(
                controller: _controller,
                minLines: 2,
                maxLines: 5,
                style: AppFont.w(600, size: 17),
                textAlign: _draft.textAlign == 0
                    ? TextAlign.center
                    : (_draft.textAlign == 1
                        ? TextAlign.right
                        : TextAlign.left),
                decoration: InputDecoration(
                  hintText: S.writeSomething,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: dark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder),
                  ),
                ),
                onChanged: (v) => _mut(() => _draft.text = v),
              ),
              const SizedBox(height: 18),

              // الخطوط
              _SectionTitle(S.fonts),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: FontCatalog.all.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (ctx, i) {
                    final f = FontCatalog.all[i];
                    final sel = f.family == _draft.fontFamily;
                    return GestureDetector(
                      onTap: () => _mut(() => _draft.fontFamily = f.family),
                      child: Container(
                        width: 96,
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColors.darkSurface
                              : AppColors.lightSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: sel
                                ? AppColors.blue
                                : (dark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder),
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'أبجد هوز',
                                style: TextStyle(
                                  fontFamily: f.family,
                                  fontSize: 20,
                                  color: sel ? AppColors.blue : null,
                                  fontVariations: FontCatalog.staticFonts
                                          .contains(f.family)
                                      ? null
                                      : const [FontVariation('wght', 700)],
                                ),
                              ),
                              const SizedBox(height: 6),
                              AppFont.w(500, size: 9.5,
                                      color: dark
                                          ? AppColors.darkTextDim
                                          : AppColors.lightTextDim)
                                  .make(f.label),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 18),

              // اللون
              _SectionTitle(S.fontColor),
              _ColorRow(
                colors: AppColors.textPalette,
                selected: _draft.color,
                onPick: (c) => _mut(() => _draft.color = c),
              ),
              const SizedBox(height: 18),

              // الحجم والدوران
              LabeledSlider(
                label: S.fontSize,
                value: _draft.fontSize,
                min: 0.02,
                max: 0.22,
                display: (v) => '${(v * 100).toStringAsFixed(0)}%',
                onChanged: (v) => _mut(() => _draft.fontSize = v),
              ),
              LabeledSlider(
                label: S.rotation,
                value: _draft.rotation,
                min: -180,
                max: 180,
                display: (v) => '${v.round()}°',
                onChanged: (v) => _mut(() => _draft.rotation = v.roundToDouble()),
              ),
              const SizedBox(height: 8),

              // المحاذاة
              _SectionTitle('المحاذاة'),
              ChoiceChips<int>(
                options: const [(0, 'وسط'), (1, 'يمين'), (2, 'يسار')],
                value: _draft.textAlign,
                onChanged: (v) => _mut(() => _draft.textAlign = v),
              ),
              const SizedBox(height: 18),

              // خيارات
              _SectionTitle('التنسيق'),
              Row(
                children: [
                  _ToggleChip(
                    label: S.textBg,
                    icon: Icons.format_color_fill,
                    selected: _draft.hasBg,
                    onTap: () => _mut(() => _draft.hasBg = !_draft.hasBg),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: S.stroke,
                    icon: Icons.border_style,
                    selected: _draft.hasStroke,
                    onTap: () => _mut(() => _draft.hasStroke = !_draft.hasStroke),
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: S.shadow,
                    icon: Icons.contrast,
                    selected: _draft.hasShadow,
                    onTap: () => _mut(() => _draft.hasShadow = !_draft.hasShadow),
                  ),
                ],
              ),
              if (_draft.hasBg) ...[
                const SizedBox(height: 12),
                _ColorRow(
                  colors: AppColors.textPalette,
                  selected: _draft.bgColor,
                  onPick: (c) => _mut(() => _draft.bgColor = c),
                ),
                LabeledSlider(
                  label: 'شفافية الخلفية',
                  value: _draft.bgOpacity,
                  min: 0.05,
                  max: 1,
                  display: (v) => '${(v * 100).round()}%',
                  onChanged: (v) => _mut(() => _draft.bgOpacity = v),
                ),
              ],
              if (_draft.hasStroke) ...[
                const SizedBox(height: 12),
                _ColorRow(
                  colors: AppColors.textPalette,
                  selected: _draft.strokeColor,
                  onPick: (c) => _mut(() => _draft.strokeColor = c),
                ),
                LabeledSlider(
                  label: 'سماكة الحدود',
                  value: _draft.strokeWidth,
                  min: 0.01,
                  max: 0.25,
                  display: (v) => '${(v * 100).round()}%',
                  onChanged: (v) => _mut(() => _draft.strokeWidth = v),
                ),
              ],
              const SizedBox(height: 18),

              // الحركات
              _SectionTitle('${S.animIn} / ${S.animOut}'),
              ChoiceChips<TextAnim>(
                options: const [
                  (TextAnim.none, S.animNone),
                  (TextAnim.fade, S.animFade),
                  (TextAnim.slideUp, S.animSlideUp),
                  (TextAnim.slideDown, S.animSlideDown),
                  (TextAnim.slideRight, S.animSlideLeft),
                  (TextAnim.slideLeft, S.animSlideRight),
                ],
                value: _draft.animIn,
                onChanged: (v) => _mut(() => _draft.animIn = v),
              ),
              const SizedBox(height: 8),
              ChoiceChips<TextAnim>(
                options: const [
                  (TextAnim.none, S.animNone),
                  (TextAnim.fade, S.animFade),
                ],
                value: _draft.animOut,
                onChanged: (v) => _mut(() => _draft.animOut = v),
              ),
              LabeledSlider(
                label: 'مدة الحركة',
                value: _draft.animDur,
                min: 0.15,
                max: 1.5,
                display: (v) => '${v.toStringAsFixed(1)}s',
                onChanged: (v) => _mut(() => _draft.animDur = v),
              ),
              const SizedBox(height: 18),

              // التوقيت
              _SectionTitle(S.timing),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: S.startAt,
                      value: _draft.start,
                      onSetPlayhead: () => _mut(() => _draft.start =
                          widget.state.projectTime.clamp(
                              0, _draft.end - 0.2)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: S.endAt,
                      value: _draft.end,
                      onSetPlayhead: () => _mut(() => _draft.end =
                          widget.state.projectTime.clamp(
                              _draft.start + 0.2,
                              widget.state.totalDuration)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(widget.existing != null ? S.save : 'أضف النص'),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  String get existingLabel =>
      widget.existing != null ? S.editText : S.addText;

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب نصاً أولاً')),
      );
      return;
    }
    _draft.text = text;
    if (widget.existing != null) {
      widget.state.updateText(_draft);
    } else {
      widget.state.addText(_draft);
    }
    Navigator.pop(context);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppFont.w(800, size: 13.5).make(text),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onPick;
  const _ColorRow({
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final c = colors[i];
          final sel = c.value == selected.value;
          return GestureDetector(
            onTap: () => onPick(c),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel ? AppColors.cyan : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      avatar: Icon(icon,
          size: 16, color: selected ? Colors.white : AppColors.blue),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.blue,
      showCheckmark: false,
      labelStyle: AppFont.w(600, size: 12,
          color: selected ? Colors.white : null),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final double value;
  final VoidCallback onSetPlayhead;
  const _TimeField({
    required this.label,
    required this.value,
    required this.onSetPlayhead,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFont.w(600, size: 11).make(label),
        const SizedBox(height: 6),
        InkWell(
          onTap: onSetPlayhead,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceHi
                  : AppColors.lightSurfaceHi,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.durationLabel(value),
                  style: AppFont.w(700, size: 14, color: AppColors.blue),
                  textDirection: TextDirection.ltr,
                ),
                const Icon(Icons.my_location, size: 16, color: AppColors.blue),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
