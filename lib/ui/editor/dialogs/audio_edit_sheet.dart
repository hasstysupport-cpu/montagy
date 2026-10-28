import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/models.dart';
import '../../../services/ffmpeg_gateway.dart';
import '../../../services/projects_store.dart';
import '../../widgets/common.dart';
import '../editor_screen.dart';

/// تعديل تراك صوتي.
Future<void> showAudioEditSheet(BuildContext context, AudioTrack track) async {
  final state = EditorScope.of(context);
  var volume = track.volume.clamp(0, 2).toDouble();
  var startAt = track.startAt;
  var fadeIn = track.fadeIn.clamp(0, 5).toDouble();
  var fadeOut = track.fadeOut.clamp(0, 5).toDouble();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppFont.w(800, size: 16)
                      .make(track.title.isEmpty ? S.music : track.title),
                ),
                Text(
                  S.durationLabel(track.duration),
                  style: AppFont.w(600, size: 12, color: ctx.accent),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
            LabeledSlider(
              label: S.musicVolume,
              value: volume,
              min: 0,
              max: 2,
              display: (v) => '${(v * 100).round()}%',
              onChanged: (v) => setSheet(() => volume = v),
            ),
            LabeledSlider(
              label: S.fadeIn,
              value: fadeIn,
              min: 0,
              max: 5,
              display: (v) => '${v.toStringAsFixed(1)}s',
              onChanged: (v) => setSheet(() => fadeIn = v),
            ),
            LabeledSlider(
              label: S.fadeOut,
              value: fadeOut,
              min: 0,
              max: 5,
              display: (v) => '${v.toStringAsFixed(1)}s',
              onChanged: (v) => setSheet(() => fadeOut = v),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.my_location, size: 17),
                    label: AppFont.w(600, size: 12.5)
                        .make(S.startFromPlayhead),
                    onPressed: () {
                      setSheet(() =>
                          startAt = state.projectTime.clamp(0, state.totalDuration));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      state.deleteAudio(track);
                    },
                    child: const Text(S.delete),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      track.volume = volume;
                      track.startAt = startAt;
                      track.fadeIn = fadeIn;
                      track.fadeOut = fadeOut;
                      state.updateAudio(track);
                    },
                    child: const Text(S.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// استخراج الصوت من مقطع مختار.
Future<void> extractAudioFromClip(BuildContext context) async {
  final state = EditorScope.of(context);
  final clip = state.selectedClip ?? state.project.clips.firstOrNull;
  if (clip == null || clip.type != MediaType.video || !clip.hasAudio) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('اختر مقطع فيديو يحتوي صوتاً أولاً')),
    );
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text(S.audioExtracting), duration: Duration(seconds: 2)),
  );

  final media = await ProjectsStore.mediaDir();
  final outPath =
      '${media.path}/${ProjectsStore.newId()}.m4a';
  final srcDur = clip.outPoint - clip.inPoint;

  // atempo لضبط السرعة إن لزم
  final atempo = clip.speed != 1
      ? (clip.speed > 2
          ? 'atempo=2.0,atempo=${(clip.speed / 2).toStringAsFixed(3)}'
          : clip.speed < 0.5
              ? 'atempo=0.5,atempo=${(clip.speed * 2).toStringAsFixed(3)}'
              : 'atempo=${clip.speed.toStringAsFixed(3)}')
      : '';

  final args = [
    '-y',
    '-ss', clip.inPoint.toStringAsFixed(3),
    '-t', srcDur.toStringAsFixed(3),
    '-i', clip.sourcePath,
    '-vn',
    if (atempo.isNotEmpty) '-filter:a', atempo,
    '-c:a', 'aac',
    '-b:a', '160k',
    outPath,
  ];

  final session = await FFmpegKit.executeWithArguments(args);
  final rc = await session.getReturnCode();
  final ok = rc?.getValue() == 0;

  if (!ok || !context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر استخراج الصوت')),
    );
    return;
  }

  final starts = state.clipStarts;
  final idx = state.project.clips.indexOf(clip);
  final track = AudioTrack(
    id: ProjectsStore.newId(),
    path: outPath,
    kind: AudioKind.extracted,
    title: 'صوت مستخرج',
    startAt: idx >= 0 && idx < starts.length ? starts[idx] : 0,
    inPoint: 0,
    outPoint: srcDur / clip.speed,
  );
  state.addAudio(track);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(S.extracted)),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
