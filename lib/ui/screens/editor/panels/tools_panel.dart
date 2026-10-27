import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/ffmpeg_service.dart';
import '../../../../state/editor_controller.dart';

/// v1.1 — Transform / Chroma / Voice FX / Smart-cut tools for the clip
/// under the playhead (CapCut-style tool panel).
class ToolsPanel extends ConsumerStatefulWidget {
  const ToolsPanel({super.key});

  @override
  ConsumerState<ToolsPanel> createState() => _ToolsPanelState();
}

class _ToolsPanelState extends ConsumerState<ToolsPanel> {
  bool _analyzing = false;

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final idx = ctrl.clipIndexAtPlayhead();
    if (idx == -1) {
      return Center(child: Text(context.tr('no_clip_hint'),
          style: GoogleFonts.cairo(color: AppColors.textDim, fontSize: 13)));
    }
    final clip = st.project.clips[idx];

    Widget section(String title, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: GoogleFonts.cairo(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDim)),
            const SizedBox(height: 6),
            child,
          ]),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Transform ----
          section(context.tr('transform'), Wrap(spacing: 8, runSpacing: 8, children: [
            _actionChip(context, Icons.rotate_left, context.tr('rotate_left'),
                active: false, onTap: () => _rot(ctrl, idx, -90)),
            _actionChip(context, Icons.rotate_right, context.tr('rotate_right'),
                active: false, onTap: () => _rot(ctrl, idx, 90)),
            _actionChip(context, Icons.flip, context.tr('mirror'),
                active: clip.mirror, onTap: () => ctrl.updateClip(idx, (c) => c.mirror = !c.mirror)),
            _actionChip(context, Icons.flip_outlined, context.tr('flip_vertical'),
                active: clip.flipV, onTap: () => ctrl.updateClip(idx, (c) => c.flipV = !c.flipV)),
            _actionChip(context, Icons.history, context.tr('reverse'),
                active: clip.reverse, onTap: () => ctrl.updateClip(idx, (c) => c.reverse = !c.reverse)),
            _actionChip(context, Icons.ac_unit, context.tr('freeze_frame'),
                active: clip.freezeDur > 0,
                onTap: () => ctrl.updateClip(idx, (c) => c.freezeDur = c.freezeDur > 0 ? 0 : 1.5)),
          ])),

          // ---- Aspect crop ----
          section(context.tr('crop_aspect'), Wrap(spacing: 6, children: [
            for (final e in [
              (0.0, context.tr('off')),
              (1.0, '1:1'),
              (0.8, '4:5'),
              (0.5625, '9:16'),
              (1.7778, '16:9'),
            ])
              _chip(context, e.$2, selected: clip.cropAspect == e.$1,
                  onTap: () => ctrl.updateClip(idx, (c) => c.cropAspect = e.$1)),
          ])),

          // ---- Ken Burns motion ----
          section(context.tr('ken_burns'), Wrap(spacing: 6, children: [
            for (final e in [
              ('', context.tr('off')),
              ('zoomIn', context.tr('kb_zoom_in')),
              ('zoomOut', context.tr('kb_zoom_out')),
              ('panLeft', context.tr('kb_pan_left')),
              ('panRight', context.tr('kb_pan_right')),
            ])
              _chip(context, e.$2, selected: clip.kenBurns == e.$1,
                  onTap: () => ctrl.updateClip(idx, (c) => c.kenBurns = e.$1)),
          ])),

          // ---- Chroma key ----
          section(context.tr('chroma_key'),
              Row(children: [
            Expanded(
              child: Wrap(spacing: 6, children: [
                _chip(context, context.tr('off'), selected: !clip.chromaEnabled,
                    onTap: () => ctrl.updateClip(idx, (c) => c.chromaEnabled = false)),
                _colorKey(context, '22DD44', clip, ctrl, idx),
                _colorKey(context, '2244FF', clip, ctrl, idx),
                _colorKey(context, 'FF22AA', clip, ctrl, idx),
              ]),
            ),
          ])),
          if (clip.chromaEnabled)
            Row(children: [
              SizedBox(width: 74, child: Text(context.tr('similarity'),
                  style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textDim))),
              Expanded(
                child: Slider(
                  value: clip.chromaSimilarity,
                  min: 0.05, max: 0.4,
                  divisions: 35,
                  activeColor: AppColors.primary,
                  onChanged: (v) => ctrl.updateClip(idx, (c) => c.chromaSimilarity = v, snapshot: false),
                ),
              ),
            ]),

          // ---- Voice FX ----
          section(context.tr('voice_fx'), Wrap(spacing: 6, children: [
            for (final e in [
              ('normal', context.tr('vfx_normal')),
              ('chipmunk', context.tr('vfx_chipmunk')),
              ('deep', context.tr('vfx_deep')),
              ('robot', context.tr('vfx_robot')),
              ('echo', context.tr('vfx_echo')),
            ])
              _chip(context, e.$2, selected: _voiceFxSelected(clip, e.$1),
                  onTap: () => _applyVoiceFx(ctrl, idx, e.$1)),
          ])),

          // ---- Smart cut ----
          section(context.tr('smart_cut'),
              _analyzing
                  ? Row(children: [
                      const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(context.tr('analyzing'),
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textDim)),
                    ])
                  : Wrap(spacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: () => _autoSplit(context, ctrl, idx, bySilence: true),
                        icon: const Icon(Icons.graphic_eq, size: 18),
                        label: Text(context.tr('split_silence'), style: GoogleFonts.cairo(fontSize: 12)),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _autoSplit(context, ctrl, idx, bySilence: false),
                        icon: const Icon(Icons.movie_filter, size: 18),
                        label: Text(context.tr('split_scenes'), style: GoogleFonts.cairo(fontSize: 12)),
                      ),
                    ])),
        ],
      ),
    );
  }

  // ------------- helpers -------------

  void _rot(EditorController ctrl, int idx, int delta) {
    ctrl.updateClip(idx, (c) {
      var r = (c.rotate + delta) % 360;
      if (r < 0) r += 360;
      c.rotate = r;
    });
  }

  bool _voiceFxSelected(dynamic clip, String fx) {
    switch (fx) {
      case 'chipmunk':
        return clip.pitch == 5 && !clip.echo;
      case 'deep':
        return clip.pitch == -5 && !clip.echo;
      case 'robot':
        return clip.echo && clip.pitch == 0;
      case 'echo':
        return clip.echo && clip.pitch != 0;
      default:
        return clip.pitch == 0 && !clip.echo;
    }
  }

  void _applyVoiceFx(EditorController ctrl, int idx, String fx) {
    ctrl.updateClip(idx, (c) {
      c.echo = fx == 'robot' || fx == 'echo';
      switch (fx) {
        case 'chipmunk':
          c.pitch = 5;
          break;
        case 'deep':
          c.pitch = -5;
          break;
        case 'echo':
          c.pitch = c.pitch == 0 ? 3 : c.pitch;
          break;
        case 'normal':
        case 'robot':
          c.pitch = 0;
          break;
      }
    });
  }

  Widget _colorKey(BuildContext context, String hex, dynamic clip,
      EditorController ctrl, int idx) {
    final color = Color(int.parse('FF$hex', radix: 16));
    final selected = clip.chromaEnabled && clip.chromaColor == hex;
    return GestureDetector(
      onTap: () => ctrl.updateClip(idx, (c) {
        c.chromaEnabled = true;
        c.chromaColor = hex;
      }),
      child: Container(
        width: 44, height: 30,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  Future<void> _autoSplit(BuildContext context, EditorController ctrl, int idx,
      {required bool bySilence}) async {
    final clip = ctrl.state.project.clips[idx];
    setState(() => _analyzing = true);
    try {
      final svc = FfmpegService.instance;
      List<double> marks;
      if (bySilence) {
        marks = (await svc.detectSilences(clip.path))
            .expand((r) => [r[0], if (r[1] > 0) r[1]])
            .where((t) => t > clip.trimStart + 0.3 && t < clip.trimEnd - 0.3)
            .toList()
          ..sort();
      } else {
        marks = (await svc.detectScenes(clip.path))
            .where((t) => t > clip.trimStart + 0.3 && t < clip.trimEnd - 0.3)
            .toList()
          ..sort();
      }
      if (marks.isNotEmpty) {
        ctrl.autoSplitClip(idx, marks);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(bySilence
              ? '${context.tr('split_silence')}: ${marks.length ~/ 1}'
              : '${context.tr('split_scenes')}: ${marks.length}'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
      }
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Widget _actionChip(BuildContext context, IconData icon, String label,
      {required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary.withOpacity(.25) : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? AppColors.primary : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: active ? AppColors.primary : AppColors.textDim),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.cairo(fontSize: 12,
              color: active ? AppColors.primary : AppColors.text)),
        ]),
      ),
    );
  }

  Widget _chip(BuildContext context, String label,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(.25) : AppColors.bg,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.cairo(fontSize: 12,
                color: selected ? AppColors.primary : AppColors.textDim)),
      ),
    );
  }
}
