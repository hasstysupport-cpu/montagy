import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/project.dart';
import '../../../state/editor_controller.dart';
import '../../../services/storage_service.dart';
import 'widgets/preview_canvas.dart';
import 'widgets/timeline.dart';
import 'panels/captions_panel.dart';
import 'panels/styles_panel.dart';
import 'panels/text_sticker_panel.dart';
import 'panels/filters_panel.dart';
import 'panels/speed_panel.dart';
import 'panels/audio_panel.dart';
import 'panels/transitions_panel.dart';
import 'panels/motion_panel.dart';
import 'widgets/ai_assistant_sheet.dart';
import 'export/export_screen.dart';

/// Opens a project and provides the EditorController for the whole subtree.
class EditorScreen extends ConsumerStatefulWidget {
  final String projectId;
  const EditorScreen({super.key, required this.projectId});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  EditorController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await StorageService.instance.listProjects();
    final p = projects.firstWhere((x) => x.id == widget.projectId);
    if (!mounted) return;
    setState(() => _controller = EditorController(p));
  }

  @override
  void dispose() {
    _controller?.save();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ProviderScope(
      overrides: [editorProvider.overrideWith((ref) => c)],
      child: const _EditorShell(),
    );
  }
}

class _EditorShell extends ConsumerWidget {
  const _EditorShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);

    return PopScope(
      canPop: !st.dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await ctrl.save();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: Text(st.project.name, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await ctrl.save();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            if (st.dirty)
              IconButton(icon: const Icon(Icons.check), tooltip: context.tr('save'), onPressed: ctrl.save),
            IconButton(icon: const Icon(Icons.undo), onPressed: ctrl.undo),
            IconButton(icon: const Icon(Icons.redo), onPressed: ctrl.redo),
            _ExportButton(projectId: st.project.id),
          ],
        ),
        body: Column(
          children: [
            // Preview
            Expanded(flex: 5, child: PreviewCanvas()),
            // Active panel
            if (st.activePanel.isNotEmpty)
              Container(
                height: 260,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: _panel(st.activePanel, ctrl, st),
              )
            else
              const SizedBox(height: 8),
            // Timeline
            SizedBox(
              height: 148,
              child: TimelineWidget(),
            ),
            // Toolbar
            _Toolbar(),
          ],
        ),
      ),
    );
  }

  Widget _panel(String id, EditorController ctrl, EditorState st) {
    return switch (id) {
      'captions' => CaptionsPanel(),
      'styles' => StylesPanel(),
      'text' || 'stickers' => TextStickerPanel(mode: id),
      'filters' => FiltersPanel(),
      'speed' => SpeedPanel(),
      'audio' => AudioPanel(),
      'transitions' => TransitionsPanel(),
      'motion' => MotionPanel(),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ExportButton extends ConsumerWidget {
  final String projectId;
  const _ExportButton(this.projectId);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: GestureDetector(
        onTap: () {
          final ctrl = ref.read(editorProvider.notifier);
          ctrl.save().then((_) {
            if (!context.mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ExportScreen(projectId: projectId)),
            );
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            gradient: AppColors.gradPrimary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(context.tr('export'),
              style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ),
    );
  }
}

class _Toolbar extends ConsumerWidget {
  const _Toolbar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final items = [
      ('captions', Icons.closed_caption, context.tr('tool_captions')),
      ('styles', Icons.style, context.tr('style_gallery')),
      ('text', Icons.text_fields, context.tr('tool_text')),
      ('stickers', Icons.emoji_emotions_outlined, context.tr('tool_stickers')),
      ('filters', Icons.filter_vintage, context.tr('tool_filters')),
      ('speed', Icons.speed, context.tr('tool_speed')),
      ('audio', Icons.music_note, context.tr('tool_audio')),
      ('transitions', Icons.swap_horiz, context.tr('tool_transitions')),
      ('motion', Icons.animation, context.tr('tool_motion')),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 86,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: items.length + 1,
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _tool(
                    context,
                    icon: Icons.auto_awesome,
                    label: context.tr('tool_ai'),
                    active: false,
                    accent: AppColors.accent2,
                    onTap: () => showAiAssistantSheet(context),
                  );
                }
                final it = items[i - 1];
                return _tool(
                  context,
                  icon: it.$2,
                  label: it.$3,
                  active: st.activePanel == it.$1,
                  onTap: () => ctrl.openPanel(it.$1),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
    Color? accent,
  }) {
    final color = active ? AppColors.accent : AppColors.textDim;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accent ?? color, size: 26),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(fontSize: 10.5, color: accent ?? color),
            ),
          ],
        ),
      ),
    );
  }
}
