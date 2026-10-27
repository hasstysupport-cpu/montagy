import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/caption.dart';
import '../../../../models/caption_style.dart';
import '../../../../services/ai/ai_facade.dart';
import '../../../../services/srt_service.dart';
import '../../../../state/editor_controller.dart';
import '../../../../state/settings_provider.dart';

/// Captions list + add/auto-AI/SRT + per-caption editing.
class CaptionsPanel extends ConsumerStatefulWidget {
  const CaptionsPanel({super.key});

  @override
  ConsumerState<CaptionsPanel> createState() => _CaptionsPanelState();
}

class _CaptionsPanelState extends ConsumerState<CaptionsPanel> {
  bool _busy = false;
  String _busyMsg = '';

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final captions = st.project.captions;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(context.tr('captions'), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
              const Spacer(),
              _miniBtn(
                icon: Icons.auto_awesome,
                label: context.tr('auto_captions'),
                color: AppColors.accent2,
                onTap: _busy ? null : _autoCaptions,
              ),
              const SizedBox(width: 6),
              _miniBtn(icon: Icons.upload_file, label: 'SRT', onTap: _busy ? null : _importSrt),
              const SizedBox(width: 6),
              _miniBtn(icon: Icons.download, label: 'SRT ↓', onTap: _busy ? null : _exportSrt),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text(_busyMsg, style: GoogleFonts.cairo(fontSize: 12)),
            ]),
          ],
          const SizedBox(height: 8),
          Expanded(
            child: captions.isEmpty
                ? Center(
                    child: Text(context.tr('no_captions_yet'),
                        style: GoogleFonts.cairo(color: AppColors.textDim, fontSize: 13)),
                  )
                : ListView.builder(
                    itemCount: captions.length,
                    itemBuilder: (context, i) {
                      final c = captions[i];
                      final selected = st.selectedCaptionIndex == i;
                      return GestureDetector(
                        onTap: () => ctrl.selectCaption(selected ? -1 : i),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary.withOpacity(.15) : AppColors.surface2,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? AppColors.primary : Colors.transparent,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '${_fmt(c.start)} → ${_fmt(c.end)}',
                                    style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.accent),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => ctrl.updateCaption(i, (x) => x.styleId = _nextStyle(x.styleId)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent2.withOpacity(.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        context.tr('style_${c.styleId}'),
                                        style: GoogleFonts.cairo(fontSize: 10, color: AppColors.accent2),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => ctrl.deleteCaption(i),
                                    child: const Icon(Icons.close, size: 15, color: AppColors.textDim),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                initialValue: c.text,
                                maxLines: null,
                                style: GoogleFonts.cairo(fontSize: 13),
                                decoration: const InputDecoration(isDense: true, border: InputBorder.none),
                                onChanged: (v) {
                                  ctrl.updateCaption(i, (x) {
                                    x.text = v;
                                    x.distributeWords();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: (color ?? AppColors.primary).withOpacity(.18),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color ?? AppColors.primary),
              const SizedBox(width: 4),
              Text(label, style: GoogleFonts.cairo(fontSize: 11, color: color ?? AppColors.primary)),
            ],
          ),
        ),
      );

  String _nextStyle(String current) {
    final ids = CaptionStylePresets.all.map((s) => s.id).toList();
    final i = ids.indexOf(current);
    return ids[(i + 1) % ids.length];
  }

  // ---------- Actions ----------

  Future<void> _autoCaptions() async {
    final st = ref.read(editorProvider);
    final settings = ref.read(settingsProvider);
    if (!AiFacade.hasStt(settings)) {
      _toast(context.tr('ai_settings_hint'));
      return;
    }
    setState(() {
      _busy = true;
      _busyMsg = context.tr('ai_transcribing');
    });
    try {
      final clip = st.project.clips.first;
      final segs = await AiFacade.autoCaptions(
        settings: settings,
        videoPath: clip.path,
        styleId: st.project.captionStyleId,
        language: settings.locale == 'ar' ? 'ar' : '',
      );
      ref.read(editorProvider.notifier).setAllCaptions(segs);
    } catch (e) {
      _toast('${context.tr('error_generic')} (${e.toString().substring(0, e.toString().length.clamp(0, 90))})');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importSrt() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['srt', 'vtt']);
    if (res == null || res.files.single.path == null) return;
    final path = res.files.single.path!;
    final content = await File(path).readAsString();
    final styleId = ref.read(editorProvider).project.captionStyleId;
    final segs = SrtService.parse(content, styleId: styleId, newId: () => const Uuid().v4());
    ref.read(editorProvider.notifier).setAllCaptions(segs);
  }

  Future<void> _exportSrt() async {
    final captions = ref.read(editorProvider).project.captions;
    if (captions.isEmpty) return;
    final srt = SrtService.export(captions);
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;
    // write via dart:io File
    File('${dir}/captions.srt').writeAsStringSync(srt);
    _toast('SRT ✓');
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).floor().toString().padLeft(2, '0');
    return '$m:$sec';
  }
}
