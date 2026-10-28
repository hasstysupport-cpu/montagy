import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_font.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import '../../editor/editor_state.dart';
import '../widgets/common.dart' show PanelScroll;
import '../export/export_screen.dart';
import 'dialogs/add_media_sheet.dart';
import 'dialogs/crop_screen.dart';
import 'dialogs/speed_volume_sheets.dart';
import 'dialogs/text_edit_sheet.dart';
import 'panels/adjust_panel.dart';
import 'panels/audio_panel.dart';
import 'panels/canvas_panel.dart';
import 'panels/edit_panel.dart';
import 'panels/effects_panel.dart';
import 'panels/filter_panel.dart';
import 'panels/sticker_panel.dart';
import 'panels/text_panel.dart';
import 'panels/transition_panel.dart';
import 'preview_view.dart';
import 'timeline_view.dart';
import '../../services/projects_store.dart';

/// تبويبات الأدوات الرئيسية — تظهر حين لا يوجد تحديد (نمط CapCut).
/// الترتيب مطابق لـ CapCut: تعديل، صوت، نص، ملصقات، تراكب، مؤثرات، فلاتر، انتقالات، ضبط، تنسيق.
const List<(IconData, String)> kEditorTabs = [
  (Icons.content_cut, S.tools),          // 0
  (Icons.music_note_outlined, S.audio),   // 1
  (Icons.text_fields, S.text),            // 2
  (Icons.emoji_emotions_outlined, S.sticker), // 3
  (Icons.layers_outlined, S.overlay),     // 4
  (Icons.blur_on, S.effects),             // 5
  (Icons.auto_awesome_outlined, S.filters), // 6
  (Icons.swap_horiz, S.transitions),      // 7
  (Icons.tune, S.adjust),                 // 8
  (Icons.crop_free, S.canvas),            // 9
];

/// نطاق المحرر.
class EditorScope extends InheritedNotifier<EditorState> {
  const EditorScope({super.key, required super.notifier, required super.child});

  static EditorState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EditorScope>()!.notifier!;
}

class EditorScreen extends StatefulWidget {
  final Project project;
  const EditorScreen({super.key, required this.project});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final EditorState state;

  @override
  void initState() {
    super.initState();
    state = EditorState(widget.project);
    state.addListener(_onStateChanged);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onStateChanged() {
    final err = state.lastError;
    if (err == null || !mounted) return;
    state.consumeError();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err, style: AppFont.w(600, size: 12.5, color: Colors.white)),
      backgroundColor: AppColors.danger.withValues(alpha: 0.92),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2200),
    ));
  }

  @override
  void dispose() {
    state.removeListener(_onStateChanged);
    state.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.darkBg : AppColors.lightBg;

    return EditorScope(
      notifier: state,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          await state.saveNow();
          if (context.mounted) Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: surface,
          resizeToAvoidBottomInset: false,
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, dark),
                // المعاينة
                Expanded(child: PreviewView(onAddMedia: _addMedia)),
                // التايم لاين
                const TimelineView(),
                // شريط الأدوات السياقي (أسفل الشاشة — نمط CapCut/InShot)
                const ContextualToolbar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addMedia() async {
    await showAddMediaSheet(context);
  }

  Widget _buildAppBar(BuildContext context, bool dark) {
    final dim = dark ? AppColors.darkTextDim : AppColors.lightTextDim;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () async {
              await state.saveNow();
              if (context.mounted) Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back_ios_new,
                size: 20,
                color: dark ? AppColors.darkText : AppColors.lightText),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.project.name,
                  style: AppFont.w(700, size: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ListenableBuilder(
                  listenable: state,
                  builder: (ctx, _) => Text(
                    '${S.durationLabel(state.projectTime)} / ${S.durationLabel(state.totalDuration)}',
                    style: AppFont.w(500, size: 10.5, color: dim),
                  ),
                ),
              ],
            ),
          ),
          // تراجع / إعادة
          ListenableBuilder(
            listenable: state,
            builder: (ctx, _) => Row(children: [
              IconButton(
                onPressed: state.canUndo ? () => state.undo() : null,
                icon: Icon(Icons.undo,
                    size: 21,
                    color: state.canUndo
                        ? (dark ? AppColors.darkText : AppColors.lightText)
                        : (dark ? AppColors.darkBorder : AppColors.lightBorder)),
              ),
              IconButton(
                onPressed: state.canRedo ? () => state.redo() : null,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.redo,
                    size: 21,
                    color: state.canRedo
                        ? (dark ? AppColors.darkText : AppColors.lightText)
                        : (dark ? AppColors.darkBorder : AppColors.lightBorder)),
              ),
            ]),
          ),
          const SizedBox(width: 2),
          _ExportButton(onTap: _openExport),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Future<void> _openExport() async {
    await state.pause();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorScope(
        notifier: state,
        child: const ExportScreen(),
      ),
    ));
  }
}

// ═══════════════════ شريط الأدوات السياقي ═══════════════════

/// الشريط السفلي — يتبدل حسب التحديد تماماً كـ CapCut:
/// بلا تحديد → الأدوات الرئيسية | مقطع محدد → أدوات المقطع | نص/ملصق → أدواته.
class ContextualToolbar extends StatelessWidget {
  const ContextualToolbar();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkBorder
                : AppColors.lightBorder,
            width: 0.6,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: state,
          builder: (ctx, _) {
            if (state.selectedClip != null) {
              return _ClipToolsBar(clip: state.selectedClip!);
            }
            if (state.selectedText != null) {
              return _TextToolsBar(text: state.selectedText!);
            }
            if (state.selectedSticker != null) {
              return _StickerToolsBar(sticker: state.selectedSticker!);
            }
            return _MainToolsBar(state: state);
          },
        ),
      ),
    );
  }
}

// ── صف الأدوات الرئيسية ──

class _MainToolsBar extends StatelessWidget {
  final EditorState state;
  const _MainToolsBar({required this.state});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: kEditorTabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (ctx, i) {
            return _ToolCell(
              icon: kEditorTabs[i].$1,
              label: kEditorTabs[i].$2,
              onTap: () {
                HapticFeedback.selectionClick();
                showToolSheet(ctx, i);
              },
            );
          },
        ),
      ),
    );
  }
}

// ── أدوات المقطع المحدد (نمط CapCut تماماً) ──

class _ClipToolsBar extends StatelessWidget {
  final ClipItem clip;
  const _ClipToolsBar({required this.clip});

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final isPhoto = clip.type == MediaType.photo;

    final tools = <_ToolDef>[
      // ترتيب CapCut: تقسيم، سرعة، صوت، فلتر، ضبط، تحويل، قص، عكس، تجميد،
      //               استخراج الصوت، تكرار، استبدال، حذف، إلغاء
      _ToolDef(
        Icons.content_cut, S.split,
        enabled: state.canSplit,
        onTap: () => state.splitAtPlayhead(),
      ),
      if (!isPhoto)
        _ToolDef(
          Icons.speed, S.speed,
          onTap: () => showSpeedSheet(context, clip),
        )
      else
        _ToolDef(
          Icons.timer_outlined, S.photoDuration,
          onTap: () => showPhotoDurationSheet(context, clip),
        ),
      if (!isPhoto)
        _ToolDef(
          clip.muted ? Icons.volume_off : Icons.volume_up, S.volume,
          onTap: () => showVolumeSheet(context, clip),
        ),
      // الفلتر + الضبط في شريط المقطع (نمط CapCut — أهم أداة لما تحدد مقطع)
      _ToolDef(
        Icons.auto_awesome_outlined, S.filters,
        active: clip.filterPreset != null,
        onTap: () => showToolSheet(context, 6),
      ),
      _ToolDef(
        Icons.tune, S.adjust,
        active: !clip.adjust.isNeutral,
        onTap: () => showToolSheet(context, 8),
      ),
      _ToolDef(
        Icons.blur_on, S.effects,
        active: clip.effects.isNotEmpty,
        onTap: () => showToolSheet(context, 5),
      ),
      _ToolDef(
        Icons.rotate_right, S.rotate90,
        onTap: () => state.updateClip(
            clip.copyWith(rotation: (clip.rotation + 90) % 360)),
      ),
      _ToolDef(Icons.flip, S.flip, onTap: () => _flipMenu(context, clip)),
      _ToolDef(
        Icons.crop_free, S.crop,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EditorScope(
            notifier: state,
            child: CropRoute(clip: clip),
          ),
        )),
      ),
      if (!isPhoto)
        _ToolDef(
          Icons.replay, S.reverse,
          active: clip.reversed,
          onTap: () => state.updateClip(
              clip.copyWith(reversed: !clip.reversed), structural: true),
        ),
      if (!isPhoto)
        _ToolDef(
          Icons.ac_unit, S.freeze,
          onTap: () => _freeze(context, state),
        ),
      if (!isVideoPhotoClip(clip))
        _ToolDef(
          Icons.graphic_eq, S.extractAudio,
          onTap: () => _extract(context, state, clip),
        ),
      _ToolDef(
        Icons.copy_outlined, 'تكرار',
        onTap: () => state.duplicateClip(clip),
      ),
      _ToolDef(
        Icons.swap_horizontal_circle_outlined, 'استبدال',
        onTap: () => _replace(context, state, clip),
      ),
      _ToolDef(
        Icons.delete_outline, 'حذف',
        danger: true,
        onTap: () {
          if (state.project.clips.length <= 1) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(S.cannotDeleteLastClip),
                duration: Duration(milliseconds: 1200)));
            return;
          }
          state.deleteClip(clip);
        },
      ),
    ];

    return _SelectedToolsRow(
      tools: tools,
    );
  }

  static bool isVideoPhotoClip(ClipItem c) => c.type == MediaType.photo;

  void _freeze(BuildContext context, EditorState state) async {
    final ok = await state.freezeFrameAtPlayhead();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? S.frameFrozen : 'تعذر تجميد الإطار'),
        duration: const Duration(milliseconds: 1200),
      ));
    }
  }

  Future<void> _extract(
      BuildContext context, EditorState state, ClipItem clip) async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(S.audioExtracting),
        duration: Duration(seconds: 2)));
    final ok = await state.extractAudio(clip);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? S.extracted : 'تعذر استخراج الصوت'),
        duration: const Duration(milliseconds: 1400),
      ));
    }
  }

  Future<void> _replace(
      BuildContext context, EditorState state, ClipItem clip) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    final name = result.files.single.name;
    final ok = await state.replaceClipSource(clip, path, name);
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر استبدال المقطع')));
    }
  }

  void _flipMenu(BuildContext context, ClipItem clip) {
    final state = EditorScope.of(context);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flip),
              title: const Text(S.flipH),
              onTap: () {
                Navigator.pop(ctx);
                state.updateClip(clip.copyWith(flipH: !clip.flipH));
              },
            ),
            ListTile(
              leading: const Icon(Icons.flip_outlined),
              title: const Text(S.flipV),
              onTap: () {
                Navigator.pop(ctx);
                state.updateClip(clip.copyWith(flipV: !clip.flipV));
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── أدوات النص المحدد ──

class _TextToolsBar extends StatelessWidget {
  final TextOverlay text;
  const _TextToolsBar({required this.text});

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    return _SelectedToolsRow(
      tools: [
        _ToolDef(
          Icons.edit_outlined, S.edit,
          onTap: () => showTextEditSheet(context, text),
        ),
        _ToolDef(
          Icons.videocam_outlined, S.keyframe,
          active: text.keyframes.isNotEmpty,
          onTap: () => state.addTextKeyframe(text),
        ),
        if (text.keyframes.isNotEmpty)
          _ToolDef(
            Icons.clear_all, 'مسح المفاتيح',
            onTap: () => state.clearTextKeyframes(text),
          ),
        _ToolDef(
          Icons.copy_outlined, 'تكرار',
          onTap: () => state.duplicateText(text),
        ),
        _ToolDef(
          Icons.schedule, S.timing,
          onTap: () => _overlayTimingSheet(context, state,
              start: text.start, end: text.end,
              onChanged: (s, e) => state.updateText(text
                ..start = s.clamp(0, state.totalDuration)
                ..end = e.clamp(s + 0.3, state.totalDuration))),
        ),
        _ToolDef(
          Icons.delete_outline, 'حذف',
          danger: true,
          onTap: () => state.deleteText(text),
        ),
      ],
    );
  }
}

class _StickerToolsBar extends StatelessWidget {
  final ImageOverlay sticker;
  const _StickerToolsBar({required this.sticker});

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    return _SelectedToolsRow(
      tools: [
        _ToolDef(
          Icons.videocam_outlined, S.keyframe,
          active: sticker.keyframes.isNotEmpty,
          onTap: () => state.addStickerKeyframe(sticker),
        ),
        if (sticker.keyframes.isNotEmpty)
          _ToolDef(
            Icons.clear_all, 'مسح المفاتيح',
            onTap: () => state.clearStickerKeyframes(sticker),
          ),
        _ToolDef(
          Icons.copy_outlined, 'تكرار',
          onTap: () {
            final j = sticker.toJson();
            j['id'] = ProjectsStore.newId();
            final copy = ImageOverlay.fromJson(j);
            copy.nx = (copy.nx + 0.06).clamp(0.02, 0.98);
            state.addSticker(copy);
          },
        ),
        _ToolDef(
          Icons.schedule, S.timing,
          onTap: () => _overlayTimingSheet(context, state,
              start: sticker.start, end: sticker.end,
              onChanged: (s, e) => state.updateSticker(sticker
                ..start = s.clamp(0, state.totalDuration)
                ..end = e.clamp(s + 0.3, state.totalDuration))),
        ),
        _ToolDef(
          Icons.delete_outline, 'حذف',
          danger: true,
          onTap: () => state.deleteSticker(sticker),
        ),
      ],
    );
  }
}

// ═══════════════════ عناصر مشتركة ═══════════════════

class _ToolDef {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;
  final bool active;
  const _ToolDef(this.icon, this.label,
      {required this.onTap, this.enabled = true, this.danger = false,
       this.active = false});
}

/// صف أدوات بنمط CapCut — الأدوات مباشرة، وزر إلغاء التحديد آخر أداة.
class _SelectedToolsRow extends StatelessWidget {
  final List<_ToolDef> tools;

  const _SelectedToolsRow({
    required this.tools,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          children: [
            for (final t in tools)
              _ToolCell(
                icon: t.icon,
                label: t.label,
                enabled: t.enabled,
                danger: t.danger,
                active: t.active,
                onTap: t.enabled ? t.onTap : () {},
              ),
            // إلغاء التحديد — آخر خلية (نمط CapCut)
            _ToolCell(
              icon: Icons.close,
              label: 'إلغاء',
              onTap: () => EditorScope.of(context).clearSelection(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final bool danger;
  final bool active;

  const _ToolCell({
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 5),
              Text(label,
                  style: AppFont.w(500, size: 10, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════ لوحات الأدوات (Bottom Sheets) ═══════════════════

/// فتح لوحة أداة كـ bottom sheet فوق التايم لاين — نمط CapCut.
Future<void> showToolSheet(BuildContext context, int index) async {
  final state = EditorScope.of(context);
  Widget panel;
  String title;
  switch (index) {
    case 0: panel = const EditPanel(); title = S.tools; break;
    case 1: panel = const AudioPanel(); title = S.audio; break;
    case 2: panel = const TextPanel(); title = S.text; break;
    case 3: panel = const StickerPanel(); title = S.sticker; break;
    case 4: panel = const _OverlayPanel(); title = S.overlay; break;
    case 5: panel = const EffectsPanel(); title = S.effects; break;
    case 6: panel = const FilterPanel(); title = S.filters; break;
    case 7: panel = const TransitionPanel(); title = S.transitions; break;
    case 8: panel = const AdjustPanel(); title = S.adjust; break;
    case 9: panel = const CanvasPanel(); title = S.canvas; break;
    default: return;
  }

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => EditorScope(
      notifier: state,
      child: _ToolSheetShell(title: title, child: panel),
    ),
  );
}

class _ToolSheetShell extends StatelessWidget {
  final String title;
  final Widget child;
  const _ToolSheetShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final maxH = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH * 0.60, minHeight: 180),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مقبض السحب + العنوان
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
            child: Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Center(
                    child: AppFont.w(700, size: 14.5).make(title),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close,
                        size: 20,
                        color: dark ? AppColors.darkText : AppColors.lightText),
                  ),
                ),
              ],
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

/// شيت توقيت الطبقات (نص/ملصق) — سلايدر بداية/نهاية.
Future<void> _overlayTimingSheet(
  BuildContext context,
  EditorState state, {
  required double start,
  required double end,
  required void Function(double s, double e) onChanged,
}) async {
  var s = start;
  var e = end;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        // حدود آمنة لسلايدرات الزمن (تفادي انهيار Slider عند مشارف المدة)
        final total = state.totalDuration;
        final maxT = total < 0.3 ? 0.3 : total;
        final maxStart = (e - 0.3).clamp(0.0, maxT);
        final startMax = maxStart < 0.05 ? 0.05 : maxStart;
        final minEnd = s + 0.3 > maxT ? maxT : s + 0.3;
        final endMax = maxT > minEnd ? maxT : minEnd + 0.05;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: AppFont.w(700, size: 15).make(S.timing)),
                const SizedBox(height: 14),
                Row(children: [
                  AppFont.w(600, size: 12).make(S.startAt),
                  const Spacer(),
                  Text(S.durationLabel(s),
                      style: AppFont.w(600, size: 12, color: context.accent),
                      textDirection: TextDirection.ltr),
                ]),
                Slider(
                  value: s.clamp(0.0, startMax),
                  min: 0,
                  max: startMax,
                  onChanged: (v) {
                    setSheet(() => s = v);
                    onChanged(v, e);
                  },
                ),
                const SizedBox(height: 4),
                Row(children: [
                  AppFont.w(600, size: 12).make(S.endAt),
                  const Spacer(),
                  Text(S.durationLabel(e),
                      style: AppFont.w(600, size: 12, color: context.accent),
                      textDirection: TextDirection.ltr),
                ]),
                Slider(
                  value: e.clamp(minEnd, endMax),
                  min: minEnd,
                  max: endMax,
                  onChanged: (v) {
                    setSheet(() => e = v);
                    onChanged(s, v);
                  },
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        onChanged(state.projectTime, e);
                        Navigator.pop(ctx);
                      },
                      child: Text(S.setStartToPlayhead,
                          style: AppFont.w(600, size: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(S.done, style: AppFont.w(700, size: 13)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// مسار الاقتصاص ملفوف بالنطاق (كان يستدعى مباشرة سابقاً).
class CropRoute extends StatelessWidget {
  final ClipItem clip;
  const CropRoute({super.key, required this.clip});

  @override
  Widget build(BuildContext context) =>
      CropScreen(clip: clip);
}

/// لوحة الطبقات (PiP) — إضافة فيديو كطبقة فوقية قابلة للتحريك.
class _OverlayPanel extends StatelessWidget {
  const _OverlayPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final videoLayers =
        state.project.overlays.where((s) => s.isVideoLayer).toList();

    return PanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppFont.w(600, size: 11.5,
                        color: dark ? AppColors.darkTextDim : AppColors.lightTextDim)
                    .make('أضف فيديو كطبقة فوقية (صورة داخل صورة) — حرّكها وكبّرها باللمس في المعاينة'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.icon(
              onPressed: () => _pickOverlayVideo(context, state),
              icon: const Icon(Icons.add_to_queue_outlined, size: 18),
              label: AppFont.w(700, size: 12.5).make('اختر فيديو الطبقة'),
            ),
          ),
          if (videoLayers.isNotEmpty) ...[
            const SizedBox(height: 16),
            AppFont.w(700, size: 12, color: context.accent).make('الطبقات الحالية'),
            const SizedBox(height: 6),
            for (final l in videoLayers)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.layers_outlined,
                    color: AppColors.blue, size: 20),
                title: Text(
                  'طبقة فيديو • ${l.end - l.start < 100 ? (l.end - l.start).toStringAsFixed(1) : '?'} ثانية',
                  style: AppFont.w(600, size: 11.5),
                ),
                subtitle: Text(
                  'يُحدد من ${l.start.toStringAsFixed(1)} إلى ${l.end.toStringAsFixed(1)}',
                  style: AppFont.w(500, size: 10),
                  textDirection: TextDirection.ltr,
                ),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: AppColors.danger),
                  onPressed: () => state.deleteSticker(l),
                ),
                onTap: () => state.selectSticker(l.id),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickOverlayVideo(BuildContext context, EditorState state) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;
    // نسخ الملف لمساحة المشروع
    final copied = await ProjectsStore.importAsset(path);
    if (copied == null) {
      state.raiseError('تعذر استيراد ملف الطبقة');
      return;
    }
    double dur = 3;
    try {
      final probe = await ProjectsStore.probeVideo(copied);
      if (probe != null && probe.$1 > 0) dur = probe.$1;
    } catch (_) {}
    if (!context.mounted) return;
    Navigator.of(context).pop(); // نغلق اللوحة ليتفاعل المستخدم مع المعاينة
    await state.addVideoLayer(copied, dur);
  }
}

/// زر التصدير — تدرج لوني حسب الثيم.
class _ExportButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ExportButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            gradient: context.accentGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: context.accent.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.file_upload_outlined,
                  size: 17, color: Colors.white),
              const SizedBox(width: 6),
              AppFont.w(800, size: 13, color: Colors.white).make('تصدير'),
            ],
          ),
        ),
      ),
    );
  }
}
