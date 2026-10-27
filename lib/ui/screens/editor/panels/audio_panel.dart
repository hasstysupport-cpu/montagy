import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/audio_track.dart';
import '../../../../services/ffmpeg_service.dart';
import '../../../../state/editor_controller.dart';

class AudioPanel extends ConsumerWidget {
  const AudioPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final clip0 = st.project.clips.firstOrNull;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('tool_audio'), style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),

          // Original sound volume
          Row(
            children: [
              const Icon(Icons.volume_up, size: 18, color: AppColors.accent),
              Text('  ${context.tr('original_sound')}', style: GoogleFonts.cairo(fontSize: 12.5)),
              Expanded(
                child: Slider(
                  value: clip0?.volume ?? 1,
                  min: 0, max: 2,
                  onChanged: (v) => ctrl.updateClip(0, (c) => c.volume = v, snapshot: false),
                ),
              ),
              Text('${((clip0?.volume ?? 1) * 100).round()}%', style: GoogleFonts.cairo(fontSize: 12)),
            ],
          ),

          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickMusic(context, ctrl, st.playhead),
                  icon: const Icon(Icons.library_music, size: 18),
                  label: Text(context.tr('add_music'), style: GoogleFonts.cairo(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: clip0 == null ? null : () => _extractAudio(context, ctrl, clip0.path),
                  icon: const Icon(Icons.audio_file, size: 18),
                  label: Text(context.tr('extract_audio'), style: GoogleFonts.cairo(fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: st.project.audioTracks.isEmpty
                ? Center(
                    child: Text('🎧 ${context.tr('music')}',
                        style: GoogleFonts.cairo(color: AppColors.textDim, fontSize: 12)))
                : ListView.builder(
                    itemCount: st.project.audioTracks.length,
                    itemBuilder: (context, i) {
                      final a = st.project.audioTracks[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.music_note, size: 16, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(a.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.cairo(fontSize: 12.5)),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.delete_outline, size: 16),
                                  onPressed: () => ctrl.removeAudioTrack(a.id),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text('${context.tr('audio_volume')}', style: GoogleFonts.cairo(fontSize: 10)),
                                Expanded(
                                  child: Slider(
                                    value: a.volume, min: 0, max: 2,
                                    onChanged: (v) => ctrl.updateAudio(a.id, (x) => x.volume = v),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickMusic(BuildContext context, EditorController ctrl, double startAt) async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res?.files.single.path == null) return;
    ctrl.addAudioTrack(AudioTrack(
      id: const Uuid().v4(),
      path: res!.files.single.path!,
      name: res.files.single.name,
      startAt: startAt,
    ));
  }

  Future<void> _extractAudio(BuildContext context, EditorController ctrl, String videoPath) async {
    try {
      final out = await FfmpegService.instance.extractAudio(videoPath);
      ctrl.addAudioTrack(AudioTrack(
        id: const Uuid().v4(),
        path: out,
        name: 'extracted.m4a',
        startAt: 0,
      ));
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('audio_extracted'))));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
      }
    }
  }
}

extension _FirstZ<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
