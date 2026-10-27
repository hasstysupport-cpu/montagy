import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/caption_style.dart';
import '../../../../models/overlay_item.dart';
import '../../../../state/editor_controller.dart';
import 'caption_renderer.dart';
import 'motion_engine.dart';

/// Video preview + caption/overlay/motion layers, synced to the controller
/// playhead. Handles dragging & pinch of overlay items.
class PreviewCanvas extends ConsumerStatefulWidget {
  const PreviewCanvas({super.key});

  @override
  ConsumerState<PreviewCanvas> createState() => _PreviewCanvasState();
}

class _PreviewCanvasState extends ConsumerState<PreviewCanvas> {
  VideoPlayerController? _player;
  String _loadedPath = '';
  double _aspect = 9 / 16;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    _player?.dispose();
    super.dispose();
  }

  void _ensurePlayer(EditorState st) {
    final first = st.project.clips.firstOrNull;
    if (first == null || first.path == _loadedPath) return;
    _loadedPath = first.path;
    final old = _player;
    final p = VideoPlayerController.file(File(first.path));
    _player = p;
    p.initialize().then((_) {
      if (!mounted) return;
      setState(() => _aspect = p.value.aspectRatio);
      p.addListener(_onVideoTick);
      if (mounted) setState(() {});
    });
    old?.dispose();
  }

  void _onVideoTick() {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    final ctrl = ref.read(editorProvider.notifier);
    // The preview plays clip #1's trimmed source — approximate timeline sync.
    final st = ref.read(editorProvider);
    final clip = st.project.clips.firstOrNull;
    if (clip == null) return;
    final localT = p.value.position.inMilliseconds / 1000.0;
    // timeline = (src - trimStart) / speed  (clip #1 starts at 0 on the timeline)
    ctrl.setPlayhead(((localT - clip.trimStart) / clip.speed).clamp(0, st.project.totalDuration));
    final playing = p.value.isPlaying;
    if (playing != st.playing) ctrl.setPlaying(playing);
    if (!playing && _ticker != null) {
      _ticker?.cancel();
      _ticker = null;
    } else if (playing && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => setState(() {}));
    }
    setState(() {}); // cheap: re-render overlays at 30fps only while playing
  }

  Future<void> _togglePlay(EditorState st) async {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    final ctrl = ref.read(editorProvider.notifier);
    final clip = st.project.clips.firstOrNull;
    if (clip == null) return;
    if (p.value.isPlaying) {
      await p.pause();
      ctrl.setPlaying(false);
    } else {
      // jump to trim start if before it
      final posSec = p.value.position.inMilliseconds / 1000.0;
      if (posSec < clip.trimStart || posSec > clip.trimEnd) {
        await p.seekTo(Duration(milliseconds: (clip.trimStart * 1000).round()));
      }
      await p.play();
      ctrl.setPlaying(true);
      _ticker ??= Timer.periodic(const Duration(milliseconds: 33), (_) => setState(() {}));
    }
    setState(() {});
  }

  Future<void> _seekTo(double timelineT, EditorState st) async {
    final p = _player;
    final clip = st.project.clips.firstOrNull;
    if (p == null || !p.value.isInitialized || clip == null) return;
    // src = trimStart + timeline * speed (inverse of the tick formula)
    final srcT = clip.trimStart + timelineT * clip.speed;
    await p.seekTo(Duration(milliseconds: (srcT.clamp(clip.trimStart, clip.trimEnd) * 1000).round()));
    ref.read(editorProvider.notifier).setPlayhead(timelineT);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(editorProvider);
    _ensurePlayer(st);
    final p = _player;
    final ready = p != null && p.value.isInitialized;

    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ---- Video ----
          AspectRatio(
            aspectRatio: ready ? p!.value.aspectRatio : _aspect,
            child: ready
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: p!.value.size.width,
                        height: p.value.size.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            VideoPlayer(p),
                            // Captions
                            ..._captions(st, p.value.size.height),
                            // Motion graphics
                            MotionEngine(
                              motionSceneJson: st.motionSceneJson,
                              t: st.playhead,
                              videoHeightPx: p.value.size.height,
                            ),
                            // Overlays (text/stickers)
                            ..._overlays(st),
                          ],
                        ),
                      ),
                    ),
                  )
                : const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          ),

          // ---- Controls ----
          if (ready)
            Positioned(
              bottom: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _togglePlay(st),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(.55),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        st.playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      ),
                      child: Slider(
                        value: st.playhead.clamp(0, st.project.totalDuration),
                        max: st.project.totalDuration <= 0 ? 1 : st.project.totalDuration,
                        onChanged: (v) => _seekTo(v, st),
                      ),
                    ),
                  ),
                  Text(
                    '${_fmt(st.playhead)} / ${_fmt(st.project.totalDuration)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

          if (st.busy)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(st.busyLabel, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _captions(EditorState st, double videoH) {
    final t = st.playhead;
    return [
      for (final c in st.project.captions)
        if (t >= c.start && t < c.end)
          buildCaptionWidget(
            segment: c,
            style: CaptionStylePresets.byId(c.styleId),
            t: t,
            videoHeightPx: videoH,
          ),
    ];
  }

  List<Widget> _overlays(EditorState st) {
    final t = st.playhead;
    return [
      for (final o in st.project.overlays)
        if (t >= o.start && t <= o.end) _draggableOverlay(o, st),
    ];
  }

  Widget _draggableOverlay(OverlayItem o, EditorState st) {
    final selected = st.selectedOverlayId == o.id;
    final ctrl = ref.read(editorProvider.notifier);
    final p = _player!;
    final videoW = p.value.size.width;
    final videoH = p.value.size.height;

    Widget item = Container(
      padding: EdgeInsets.symmetric(
        horizontal: o.fontSizePct * videoH / 100 * 0.4,
        vertical: o.fontSizePct * videoH / 100 * 0.15,
      ),
      decoration: BoxDecoration(
        color: o.bgColor?.withOpacity(o.bgOpacity),
        borderRadius: BorderRadius.circular(10),
        border: selected ? Border.all(color: AppColors.accent, width: 1.5) : null,
      ),
      child: Text(
        o.text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: o.fontSizePct * videoH / 100,
          fontWeight: FontWeight.w800,
          color: o.color,
          height: 1.2,
        ),
      ),
    );

    item = Opacity(
      opacity: o.opacity,
      child: Transform.rotate(
        angle: o.rotationDeg * 3.14159 / 180,
        child: Transform.scale(scale: o.scale, child: item),
      ),
    );

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => ctrl.selectOverlay(selected ? null : o.id),
        onPanUpdate: (d) => ctrl.updateOverlay(o.id, (x) {
          x.x = (x.x + d.delta.dx / (videoW * x.scale)).clamp(0.02, 0.98);
          x.y = (x.y + d.delta.dy / (videoH * x.scale)).clamp(0.02, 0.98);
        }),
        child: Align(
          alignment: Alignment((o.x * 2 - 1).clamp(-1, 1), (o.y * 2 - 1).clamp(-1, 1)),
          child: item,
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

extension _FirstOrNullX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
