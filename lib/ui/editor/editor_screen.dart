import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_font.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import '../../editor/editor_state.dart';
import '../export/export_screen.dart';
import 'dialogs/add_media_sheet.dart';
import 'panels/adjust_panel.dart';
import 'panels/audio_panel.dart';
import 'panels/canvas_panel.dart';
import 'panels/edit_panel.dart';
import 'panels/filter_panel.dart';
import 'panels/sticker_panel.dart';
import 'panels/text_panel.dart';
import 'panels/transition_panel.dart';
import 'preview_view.dart';
import 'timeline_view.dart';

const List<(IconData, String)> kEditorTabs = [
  (Icons.content_cut, S.tools),
  (Icons.auto_awesome_outlined, S.filters),
  (Icons.tune, S.adjust),
  (Icons.text_fields, S.text),
  (Icons.emoji_emotions_outlined, S.sticker),
  (Icons.music_note_outlined, S.audio),
  (Icons.crop_free, S.canvas),
  (Icons.swap_horiz, S.transitions),
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
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    state = EditorState(widget.project);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
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
      child: WillPopScope(
        onWillPop: () async {
          await state.saveNow();
          return true;
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
                // شريط الأدوات
                _ToolbarBar(
                  tab: _tab,
                  onChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _tab = i);
                  },
                ),
                // اللوحة
                _PanelContainer(index: _tab),
                // التايم لاين
                const TimelineView(),
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
                    style: AppFont.w(500,
                        size: 10.5,
                        color: dark
                            ? AppColors.darkTextDim
                            : AppColors.lightTextDim),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder(
            valueListenable: _UndoEnable(state),
            builder: (ctx, enabled, _) => IconButton(
              onPressed: enabled ? () => state.undo() : null,
              icon: Icon(Icons.undo,
                  size: 22,
                  color: enabled
                      ? (dark ? AppColors.darkText : AppColors.lightText)
                      : (dark ? AppColors.darkBorder : AppColors.lightBorder)),
            ),
          ),
          const SizedBox(width: 6),
          _ExportButton(onTap: _openExport),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Future<void> _openExport() async {
    await state.pause();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorScope(
        notifier: state,
        child: const ExportScreen(),
      ),
    ));
  }
}

class _UndoEnable extends ValueNotifier<bool> {
  _UndoEnable(EditorState state) : super(state.canUndo) {
    state.addListener(() => value = state.canUndo);
  }
}

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
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: AppColors.blue.withValues(alpha: 0.35),
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

class _ToolbarBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onChanged;
  const _ToolbarBar({required this.tab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
              color: dark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.6),
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: kEditorTabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 4),
          itemBuilder: (ctx, i) {
            final selected = i == tab;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 64,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.blue.withValues(alpha: 0.14)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        kEditorTabs[i].$1,
                        size: 21,
                        color: selected
                            ? AppColors.blue
                            : (dark
                                ? AppColors.darkTextDim
                                : AppColors.lightTextDim),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kEditorTabs[i].$2,
                        style: AppFont.w(selected ? 700 : 500,
                            size: 10,
                            color: selected
                                ? AppColors.blue
                                : (dark
                                    ? AppColors.darkTextDim
                                    : AppColors.lightTextDim)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PanelContainer extends StatelessWidget {
  final int index;
  const _PanelContainer({required this.index});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final state = EditorScope.of(context);
    Widget panel;
    switch (index) {
      case 0:
        panel = const EditPanel();
      case 1:
        panel = const FilterPanel();
      case 2:
        panel = const AdjustPanel();
      case 3:
        panel = const TextPanel();
      case 4:
        panel = const StickerPanel();
      case 5:
        panel = const AudioPanel();
      case 6:
        panel = const CanvasPanel();
      case 7:
        panel = const TransitionPanel();
      default:
        panel = const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurface : AppColors.lightSurface,
          border: Border(
            top: BorderSide(
                color: dark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 0.6),
          ),
        ),
        child: ListenableBuilder(
          listenable: state,
          builder: (ctx, _) => panel,
        ),
      ),
    );
  }
}
