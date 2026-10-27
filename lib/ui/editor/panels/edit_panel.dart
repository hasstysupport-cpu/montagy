import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/models.dart';
import '../../../editor/editor_state.dart';
import '../../../services/ffmpeg_gateway.dart';
import '../../../services/projects_store.dart';
import '../../widgets/common.dart';
import '../dialogs/crop_screen.dart';
import '../dialogs/speed_volume_sheets.dart';
import '../editor_screen.dart';

/// لوحة أدوات التعديل — قص/تقسيم/سرعة/تدوير/عكس/تجميد...
class EditPanel extends StatelessWidget {
  const EditPanel();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final clip = state.selectedClip;
    final hasClip = clip != null;
    final isPhoto = clip?.type == MediaType.photo;

    return PanelScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasClip)
            const PanelHint(
                'اختر مقطعاً من التايم لاين لتفعيل الأدوات — اسحب المقابض الزرقاء للتشذيب'),
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ToolButton(
                        icon: Icons.content_cut,
                        label: S.split,
                        enabled: hasClip && state.canSplit,
                        onTap: () => state.splitAtPlayhead(),
                      ),
                      ToolButton(
                        icon: Icons.crop,
                        label: S.trim,
                        enabled: hasClip,
                        active: hasClip,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'اسحب المقابض الزرقاء على طرفي المقطع المحدد لتشذيبه'),
                              duration: Duration(milliseconds: 1500),
                            ),
                          );
                        },
                      ),
                      ToolButton(
                        icon: Icons.speed,
                        label: isPhoto ? S.photoDuration : S.speed,
                        enabled: hasClip,
                        onTap: () {
                          if (isPhoto) {
                            showPhotoDurationSheet(context, clip!);
                          } else {
                            showSpeedSheet(context, clip!);
                          }
                        },
                      ),
                      ToolButton(
                        icon: clip?.muted == true
                            ? Icons.volume_off
                            : Icons.volume_up,
                        label: S.volume,
                        enabled: hasClip && !isPhoto,
                        onTap: () => showVolumeSheet(context, clip!),
                      ),
                      ToolButton(
                        icon: Icons.rotate_right,
                        label: S.rotate90,
                        enabled: hasClip,
                        onTap: () => state.updateClip(clip!.copyWith(
                            rotation: (clip.rotation + 90) % 360)),
                      ),
                      ToolButton(
                        icon: Icons.flip,
                        label: S.flip,
                        enabled: hasClip,
                        onTap: () => _flipMenu(context, clip!),
                      ),
                      ToolButton(
                        icon: Icons.crop_free,
                        label: S.crop,
                        enabled: hasClip,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CropScreen(clip: clip!),
                        )),
                      ),
                      ToolButton(
                        icon: Icons.replay,
                        label: S.reverse,
                        enabled: hasClip && !isPhoto,
                        active: clip?.reversed == true,
                        onTap: () => state.updateClip(
                            clip!.copyWith(reversed: !clip.reversed),
                            structural: true),
                      ),
                      ToolButton(
                        icon: Icons.ac_unit,
                        label: S.freeze,
                        enabled: hasClip && !isPhoto,
                        onTap: () => _freezeFrame(context, state, clip!),
                      ),
                      ToolButton(
                        icon: Icons.copy,
                        label: S.duplicateClip,
                        enabled: hasClip,
                        onTap: () => state.duplicateClip(clip!),
                      ),
                      ToolButton(
                        icon: Icons.arrow_back,
                        label: S.moveLeft,
                        enabled: hasClip,
                        onTap: () {
                          final i = state.project.clips.indexOf(clip!);
                          if (i > 0) state.moveClip(i, i - 1);
                        },
                      ),
                      ToolButton(
                        icon: Icons.arrow_forward,
                        label: S.moveRight,
                        enabled: hasClip,
                        onTap: () {
                          final i = state.project.clips.indexOf(clip!);
                          if (i >= 0 && i < state.project.clips.length - 1) {
                            state.moveClip(i, i + 2);
                          }
                        },
                      ),
                      ToolButton(
                        icon: Icons.delete_outline,
                        label: S.deleteClip,
                        danger: true,
                        enabled: hasClip && state.project.clips.length > 1,
                        onTap: () => state.deleteClip(clip!),
                      ),
                  ],
            ),
          ),
          if (hasClip && !isPhoto)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: _ClipInfoBar(clip: clip),
            ),
        ],
      ),
    );
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

  /// تجميد الإطار الحالي: يستخرج فريماً ويضيفه كصورة.
  Future<void> _freezeFrame(
      BuildContext context, EditorState state, ClipItem clip) async {
    final starts = state.clipStarts;
    final idx = state.project.clips.indexOf(clip);
    if (idx < 0) return;
    final localT =
        (state.projectTime - starts[idx]).clamp(0.0, clip.timelineDuration);
    final srcPos = clip.inPoint + localT * clip.speed;

    final tmp = await ProjectsStore.thumbsDir();
    final outPath = '${tmp.path}/${ProjectsStore.newId()}.png';

    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-ss', srcPos.toStringAsFixed(3),
      '-i', clip.sourcePath,
      '-frames:v', '1',
      '-q:v', '2',
      outPath,
    ]);
    final frReturn = await session.getReturnCode();
    if (frReturn?.getValue() != 0 || !context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تجميد الإطار')),
      );
      return;
    }
    final photo = ClipItem(
      id: ProjectsStore.newId(),
      type: MediaType.photo,
      sourcePath: outPath,
      title: 'إطار مجمد',
      photoDuration: 1,
      sourceDuration: 1,
      hasAudio: false,
      thumbPath: outPath,
      filterPreset: clip.filterPreset,
      filterIntensity: clip.filterIntensity,
      adjust: clip.adjust,
    );
    await state.insertClipAt(photo, idx + 1);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(S.frameFrozen),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }
}

class _ClipInfoBar extends StatelessWidget {
  final ClipItem clip;
  const _ClipInfoBar({required this.clip});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.movie_outlined, size: 14, color: AppColors.blue),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              clip.title,
              style: AppFont.w(600, size: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppFont.w(500, size: 10.5,
                  color: dark ? AppColors.darkTextDim : AppColors.lightTextDim)
              .make(
            '${S.durationLabel(clip.timelineDuration)} • ${S.speedLabel(clip.speed)}'
            '${clip.crop != null ? ' • ${S.crop}' : ''}'
            '${clip.rotation != 0 ? ' • ${clip.rotation}°' : ''}',
          ),
        ],
      ),
    );
  }
}
