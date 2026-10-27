import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:io';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/i18n/strings.dart';
import '../../../../models/caption.dart';
import '../../../../state/editor_controller.dart';

/// CapCut-style timeline: filmstrip of clip 1, caption blocks lane,
/// audio lane, draggable playhead + trim handles.
class TimelineWidget extends ConsumerStatefulWidget {
  const TimelineWidget({super.key});

  @override
  ConsumerState<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends ConsumerState<TimelineWidget> {
  final ScrollController _scroll = ScrollController();
  double _pxPerSec = 40;
  Map<String, List<String?>> _thumbsCache = {};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final p = st.project;
    final total = p.totalDuration <= 0 ? 1.0 : p.totalDuration;
    final width = total * _pxPerSec;

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          // zoom + actions row
          SizedBox(
            height: 34,
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.content_cut, size: 18, color: AppColors.accent),
                  tooltip: context.tr('split'),
                  onPressed: ctrl.splitAtPlayhead,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.zoom_in, size: 18),
                  onPressed: () => setState(() => _pxPerSec = (_pxPerSec * 1.4).clamp(16, 200)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.zoom_out, size: 18),
                  onPressed: () => setState(() => _pxPerSec = (_pxPerSec / 1.4).clamp(16, 200)),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(
                    _fmt(st.playhead),
                    style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _scroll,
              child: SizedBox(
                width: width + 300,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        // ---- caption lane ----
                        SizedBox(
                          height: 40,
                          child: Stack(
                            children: [
                              for (final c in p.captions)
                                Positioned(
                                  left: c.start * _pxPerSec,
                                  width: ((c.end - c.start) * _pxPerSec).clamp(24, double.infinity),
                                  top: 4, bottom: 4,
                                  child: GestureDetector(
                                    onTap: () => ctrl.selectCaption(p.captions.indexOf(c)),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: st.selectedCaptionIndex == p.captions.indexOf(c)
                                            ? AppColors.accent2.withOpacity(.55)
                                            : AppColors.accent2.withOpacity(.28),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.accent2.withOpacity(.6)),
                                      ),
                                      child: Center(
                                        child: Text(
                                          c.text,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // ---- video filmstrip ----
                        SizedBox(
                          height: 52,
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  for (final clip in p.clips)
                                    GestureDetector(
                                      onLongPress: () => _clipMenu(context, p.clips.indexOf(clip)),
                                      child: SizedBox(
                                        width: clip.timelineLength * _pxPerSec,
                                        child: _Filmstrip(
                                          key: ValueKey(clip.id),
                                          clipPath: clip.path,
                                          length: clip.timelineLength,
                                          pxPerSec: _pxPerSec,
                                          cacheKey: clip.id,
                                          cache: _thumbsCache,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              // trim handles over first clip (practical scope)
                              if (p.clips.isNotEmpty) _TrimHandles(ctrl: ctrl, pxPerSec: _pxPerSec),
                            ],
                          ),
                        ),
                        // ---- audio lane ----
                        SizedBox(
                          height: 30,
                          child: Stack(
                            children: [
                              for (final a in p.audioTracks)
                                Positioned(
                                  left: a.startAt * _pxPerSec,
                                  width: 120,
                                  top: 3, bottom: 3,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(.35),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.primary.withOpacity(.6)),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.music_note, size: 12, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            a.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 9, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // ---- playhead (inside scroll so it tracks content) ----
                    Positioned(
                      left: st.playhead * _pxPerSec,
                      top: 0, bottom: 0,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragUpdate: (d) =>
                            ctrl.setPlayhead(st.playhead + d.delta.dx / _pxPerSec),
                        child: Container(width: 2, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _clipMenu(BuildContext context, int index) {
    final ctrl = ref.read(editorProvider.notifier);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(context.tr('delete_clip')),
              onTap: () {
                ctrl.deleteClip(index);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).floor().toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

/// Async filmstrip: fetches N thumbnails across the clip and tiles them.
class _Filmstrip extends StatefulWidget {
  final String clipPath;
  final double length;
  final double pxPerSec;
  final String cacheKey;
  final Map<String, List<String?>> cache;

  const _Filmstrip({
    super.key,
    required this.clipPath,
    required this.length,
    required this.pxPerSec,
    required this.cacheKey,
    required this.cache,
  });

  @override
  State<_Filmstrip> createState() => _FilmstripState();
}

class _FilmstripState extends State<_Filmstrip> {
  List<String?>? _thumbs;

  @override
  void initState() {
    super.initState();
    _thumbs = widget.cache[widget.cacheKey];
    _load();
  }

  Future<void> _load() async {
    final count = ((widget.length * widget.pxPerSec) / 52).floor().clamp(1, 30);
    final list = List<String?>.filled(count, null);
    setState(() => _thumbs = list);
    for (var i = 0; i < count; i++) {
      if (!mounted) return;
      try {
        final t = (i + 0.5) / count * widget.length;
        final path = await VideoThumbnail.thumbnailFile(
          video: widget.clipPath,
          thumbnailFormat: ThumbnailFormat.JPEG,
          quality: 25,
          timeMs: (t * 1000).round(),
        );
        if (mounted && path != null) {
          setState(() => _thumbs![i] = path);
        }
      } catch (_) {}
    }
    widget.cache[widget.cacheKey] = _thumbs!;
  }

  @override
  Widget build(BuildContext context) {
    final thumbs = _thumbs ?? const <String?>[];
    return Row(
      children: [
        for (final t in thumbs)
          Expanded(
            child: t != null
                ? Image.file(File(t), fit: BoxFit.cover, gaplessPlayback: true)
                : Container(color: AppColors.surface2),
          ),
      ],
    );
  }
}

/// Draggable left/right trim handles for the first clip.
class _TrimHandles extends ConsumerWidget {
  final EditorController ctrl;
  final double pxPerSec;
  const _TrimHandles({required this.ctrl, required this.pxPerSec});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(editorProvider);
    final clip = st.project.clips.firstOrNull;
    if (clip == null) return const SizedBox.shrink();
    final left = clip.trimStart * pxPerSec;
    final right = clip.trimEnd * pxPerSec;

    Widget handle({required bool isLeft}) => GestureDetector(
          onHorizontalDragUpdate: (d) {
            final delta = d.delta.dx / pxPerSec;
            ctrl.updateClip(0, (c) {
              if (isLeft) {
                c.trimStart = (c.trimStart + delta).clamp(0, c.trimEnd - 0.2);
              } else {
                c.trimEnd = (c.trimEnd + delta).clamp(c.trimStart + 0.2, c.sourceDuration);
              }
            }, snapshot: false);
          },
          child: Container(
            width: 18,
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(.9),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Center(
              child: Icon(isLeft ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_right,
                  size: 14, color: Colors.black),
            ),
          ),
        );

    return Stack(
      children: [
        Positioned(left: left - 18, top: 0, bottom: 0, child: handle(isLeft: true)),
        Positioned(left: right - 0, top: 0, bottom: 0, child: handle(isLeft: false)),
      ],
    );
  }
}
