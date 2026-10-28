import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/models.dart';
import '../../../services/projects_store.dart';
import '../../../services/voice_recorder.dart';
import '../../widgets/common.dart';
import '../dialogs/audio_edit_sheet.dart';
import '../editor_screen.dart';

/// لوحة الصوت — موسيقى / تعليق صوتي / استخراج صوت.
class AudioPanel extends StatefulWidget {
  const AudioPanel({super.key});

  @override
  State<AudioPanel> createState() => _AudioPanelState();
}

class _AudioPanelState extends State<AudioPanel> {
  bool _recording = false;
  DateTime? _recStart;

  @override
  void dispose() {
    if (_recording) {
      VoiceRecorder.cancel();
    }
    super.dispose();
  }

  Future<void> _toggleRecord(BuildContext context) async {
    final state = EditorScope.of(context);
    if (_recording) {
      final path = await VoiceRecorder.stop();
      setState(() => _recording = false);
      if (path == null || !context.mounted) return;
      final dur =
          DateTime.now().difference(_recStart ?? DateTime.now()).inSeconds;
      state.addAudio(AudioTrack(
        id: ProjectsStore.newId(),
        path: path,
        kind: AudioKind.voice,
        title: 'تعليق صوتي',
        startAt: 0,
        outPoint: dur.clamp(1, 7200).toDouble(),
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('تم إضافة التسجيل ✓'),
              duration: Duration(milliseconds: 1200)),
        );
      }
      return;
    }

    final hasPerm = await VoiceRecorder.ensurePermission();
    if (!hasPerm) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(S.micPermission)),
        );
      }
      return;
    }
    final media = await ProjectsStore.mediaDir();
    final outPath = '${media.path}/${ProjectsStore.newId()}.m4a';
    final started = await VoiceRecorder.start(outPath);
    if (!started) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر بدء التسجيل')),
        );
      }
      return;
    }
    _recStart = DateTime.now();
    setState(() => _recording = true);
  }

  Future<void> _pickMusic(BuildContext context) async {
    final state = EditorScope.of(context);
    final result =
        await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.paths.isEmpty) return;
    final path = result.paths.whereType<String>().first;
    final imported = await ProjectsStore.importAsset(path);
    if (imported == null) return;

    // مدة الصوت عبر ffprobe
    final info = await ProjectsStore.probeVideo(imported);
    final dur = info?.$1 ?? 0;
    if (dur <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ملف صوتي غير صالح')),
        );
      }
      return;
    }
    final name = path.split('/').last;
    state.addAudio(AudioTrack(
      id: ProjectsStore.newId(),
      path: imported,
      kind: AudioKind.music,
      title: name.length > 24 ? '${name.substring(0, 24)}…' : name,
      startAt: 0,
      outPoint: dur,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return PanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickMusic(context),
                  icon: const Icon(Icons.library_music, size: 18),
                  label: AppFont.w(600, size: 12.5).make(S.addMusic),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => extractAudioFromClip(context),
                  icon: const Icon(Icons.graphic_eq, size: 18),
                  label: AppFont.w(600, size: 12.5).make(S.extractAudio),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // زر التسجيل
          GestureDetector(
            onTap: () => _toggleRecord(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _recording
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : dark
                        ? AppColors.darkSurfaceHi
                        : AppColors.lightSurfaceHi,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _recording ? AppColors.danger : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _recording ? Icons.stop_circle : Icons.mic,
                    color: _recording ? AppColors.danger : context.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  AppFont.w(700, size: 13,
                          color: _recording ? AppColors.danger : null)
                      .make(_recording ? S.recordStop : S.voiceover),
                  const Spacer(),
                  if (_recording)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // قائمة التراكات
          if (state.project.audio.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final tr in state.project.audio)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => showAudioEditSheet(context, tr),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColors.darkSurfaceHi
                          : AppColors.lightSurfaceHi,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tr.kind == AudioKind.voice
                              ? Icons.mic
                              : tr.kind == AudioKind.extracted
                                  ? Icons.graphic_eq
                                  : Icons.music_note,
                          size: 18,
                          color: context.accent,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppFont.w(600, size: 12.5).make(
                                tr.title.isEmpty ? S.music : tr.title,
                              ),
                              AppFont.w(400, size: 10,
                                      color: dark
                                          ? AppColors.darkTextDim
                                          : AppColors.lightTextDim)
                                  .make(
                                'يبدأ عند ${S.durationLabel(tr.startAt)} • ${S.durationLabel(tr.duration)}',
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
