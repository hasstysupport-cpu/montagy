import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_font.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import '../../editor/editor_state.dart';
import 'dialogs/add_media_sheet.dart';
import 'dialogs/audio_edit_sheet.dart';
import 'dialogs/text_edit_sheet.dart';
import 'dialogs/transition_sheet.dart';
import 'editor_screen.dart';

/// التايم لاين — مسطرة + مقاطع + تراكات صوت ونصوص، مؤشر ثابت بالمنتصف.
class TimelineView extends StatefulWidget {
  const TimelineView({super.key});

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  double _pps = 64; // بكسل لكل ثانية
  double _scrollX = 0;
  bool _dragging = false;
  double _gestureStartPps = 64;

  static const double rulerH = 26;
  static const double clipTrackH = 62;
  static const double audioTrackH = 30;
  static const double overlayTrackH = 30;

  @override
  void dispose() {
    _dragging = false;
    super.dispose();
  }

  double _timeAtCenter(EditorState state, double viewportW) =>
      (_scrollX + viewportW / 2) / _pps;

  void _syncToPlayhead(EditorState state, double viewportW) {
    if (_dragging) return;
    if (!state.playing) return;
    final target = state.projectTime * _pps - viewportW / 2;
    _scrollX = target.clamp(0.0, _maxScroll(state, viewportW));
  }

  double _maxScroll(EditorState state, double viewportW) {
    final contentW = _contentWidth(state, viewportW);
    return (contentW - viewportW).clamp(0.0, double.infinity);
  }

  double _contentWidth(EditorState state, double viewportW) {
    final w = state.totalDuration * _pps + viewportW;
    return w.clamp(viewportW, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final state = EditorScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (ctx, _) {
        if (state.project.clips.isEmpty) {
          return _emptyTimeline(dark);
        }
        return Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.lightSurface,
            border: Border(
              top: BorderSide(
                  color: dark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 0.6),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: LayoutBuilder(builder: (ctx, box) {
                final viewportW = box.maxWidth;
                _syncToPlayhead(state, viewportW);

                final hasAudio = state.project.audio.isNotEmpty;
                final hasOverlays =
                    state.project.texts.isNotEmpty || state.project.overlays.isNotEmpty;
                final totalH = rulerH +
                    clipTrackH +
                    8 +
                    (hasAudio ? audioTrackH + 6 : 0) +
                    (hasOverlays ? overlayTrackH + 6 : 0) +
                    8;

                final contentW = _contentWidth(state, viewportW);
                final starts = state.clipStarts;

                return SizedBox(
                  height: totalH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (d) {
                      _dragging = true;
                      _gestureStartPps = _pps;
                    },
                    onScaleUpdate: (d) {
                      setState(() {
                        if (d.pointerCount >= 2 && d.scale > 0.01) {
                          _pps = (_gestureStartPps * d.scale).clamp(24.0, 320.0);
                        }
                        _scrollX -= d.focalPointDelta.dx;
                        _scrollX = _scrollX.clamp(0.0, _maxScroll(state, viewportW));
                      });
                      state.seekTo(_timeAtCenter(state, viewportW));
                    },
                    onScaleEnd: (d) {
                      _dragging = false;
                    },
                    onTapUp: (d) {
                      // نقرة → تحريك المؤشر إلى هذا الزمن
                      final targetT =
                          (d.globalPosition.dx + _scrollX) / _pps;
                      setState(() {
                        _scrollX = (targetT * _pps - viewportW / 2)
                            .clamp(0.0, _maxScroll(state, viewportW));
                      });
                      state.seekTo(targetT);
                    },
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // المحتوى المتحرك
                        Positioned.fill(
                          child: Transform.translate(
                            offset: Offset(-_scrollX, 0),
                            child: SizedBox(
                              width: contentW,
                              child: Stack(
                                children: [
                                  // المسطرة
                                  Positioned(
                                    left: 0,
                                    top: 0,
                                    width: contentW,
                                    height: rulerH,
                                    child: CustomPaint(
                                      painter: _RulerPainter(
                                        pps: _pps,
                                        total: state.totalDuration,
                                        dark: dark,
                                      ),
                                    ),
                                  ),
                                  // تراك الفيديو
                                  Positioned(
                                    left: 0,
                                    top: rulerH + 2,
                                    width: contentW,
                                    height: clipTrackH,
                                    child: Stack(
                                      children: [
                                        for (var i = 0; i < state.project.clips.length; i++)
                                          _ClipWidget(
                                            key: ValueKey(state.project.clips[i].id),
                                            clip: state.project.clips[i],
                                            start: starts[i],
                                            pps: _pps,
                                            selected: state.selectedClipId ==
                                                state.project.clips[i].id,
                                            onTap: () => state.selectClip(
                                                state.project.clips[i].id),
                                            onTrimStart: (dx) => _trimClip(
                                                state, state.project.clips[i], dx, true),
                                            onTrimEnd: (dx) => _trimClip(
                                                state, state.project.clips[i], dx, false),
                                          ),
                                        // شارات الانتقالات
                                        for (var i = 0;
                                            i < state.project.clips.length - 1;
                                            i++)
                                          if (state.project.clips[i].transitionOutId != null)
                                            Positioned(
                                              left: (starts[i] +
                                                      state.project.clips[i]
                                                          .timelineDuration) *
                                                  _pps -
                                                  14,
                                              top: clipTrackH / 2 - 14,
                                              child: _TransitionBadge(
                                                onTap: () => showTransitionSheet(
                                                    context, state.project.clips[i]),
                                              ),
                                            ),
                                        // زر +
                                        Positioned(
                                          left: state.totalDuration * _pps + 8,
                                          top: 0,
                                          height: clipTrackH,
                                          child: _AddClipButton(
                                            onTap: () => showAddMediaSheet(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // تراك الصوت
                                  if (hasAudio)
                                    Positioned(
                                      left: 0,
                                      top: rulerH + clipTrackH + 10,
                                      width: contentW,
                                      height: audioTrackH,
                                      child: Stack(
                                        children: [
                                          for (final tr in state.project.audio)
                                            _AudioBlock(
                                              track: tr,
                                              pps: _pps,
                                              onTap: () =>
                                                  showAudioEditSheet(context, tr),
                                            ),
                                        ],
                                      ),
                                    ),
                                  // تراك النصوص/الملصقات
                                  if (hasOverlays)
                                    Positioned(
                                      left: 0,
                                      top: rulerH +
                                          clipTrackH +
                                          10 +
                                          (hasAudio ? audioTrackH + 6 : 0),
                                      width: contentW,
                                      height: overlayTrackH,
                                      child: Stack(
                                        children: [
                                          for (final t in state.project.texts)
                                            _OverlayPill(
                                              start: t.start,
                                              duration: t.end - t.start,
                                              pps: _pps,
                                              icon: Icons.text_fields,
                                              label: t.text,
                                              color: AppColors.cyan,
                                              selected: state.selectedTextId == t.id,
                                              onTap: () {
                                                state.selectText(t.id);
                                              },
                                              onDoubleTap: () =>
                                                  showTextEditSheet(context, t),
                                            ),
                                          for (final s in state.project.overlays)
                                            _OverlayPill(
                                              start: s.start,
                                              duration: s.end - s.start,
                                              pps: _pps,
                                              icon: s.emoji != null
                                                  ? Icons.emoji_emotions
                                                  : Icons.image_outlined,
                                              label: s.emoji ?? 'صورة',
                                              color: AppColors.warn,
                                              selected: state.selectedStickerId == s.id,
                                              onTap: () {
                                                state.selectSticker(s.id);
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // المؤشر الثابت
                        Center(
                          widthFactor: 1,
                          child: IgnorePointer(
                            child: _Playhead(
                              height: totalH,
                              dark: dark,
                              time: state.projectTime,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  Widget _emptyTimeline(bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightSurface,
        border: Border(
          top: BorderSide(
              color: dark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 0.6),
        ),
      ),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: () => showAddMediaSheet(context),
          icon: const Icon(Icons.add),
          label: const Text(S.emptyEditorTitle),
        ),
      ),
    );
  }

  void _trimClip(EditorState state, ClipItem clip, double dx, bool start) {
    if (clip.type != MediaType.video) return;
    final srcDelta = dx / _pps * clip.speed;
    final cur = state.project.clips[state.project.clips.indexOf(clip)];
    if (start) {
      final newIn = (cur.inPoint + srcDelta)
          .clamp(0.0, cur.outPoint - 0.15 * clip.speed)
          .toDouble();
      state.updateClip(cur.copyWith(inPoint: newIn), seekAfter: true);
    } else {
      final newOut = (cur.outPoint + srcDelta)
          .clamp(cur.inPoint + 0.15 * clip.speed, cur.sourceDuration)
          .toDouble();
      state.updateClip(cur.copyWith(outPoint: newOut), seekAfter: true);
    }
  }
}

/// ───────── عناصر التايم لاين ─────────

class _ClipWidget extends StatelessWidget {
  final ClipItem clip;
  final double start;
  final double pps;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<double> onTrimStart;
  final ValueChanged<double> onTrimEnd;

  const _ClipWidget({
    super.key,
    required this.clip,
    required this.start,
    required this.pps,
    required this.selected,
    required this.onTap,
    required this.onTrimStart,
    required this.onTrimEnd,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final w = clip.timelineDuration * pps;
    final thumbOk = clip.thumbPath != null && File(clip.thumbPath!).existsSync();

    return Positioned(
      left: start * pps,
      width: w.clamp(8.0, double.infinity),
      top: 0,
      height: 62,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: selected ? AppColors.blue : Colors.transparent,
              width: 2.2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // الصور المصغرة
              Positioned.fill(
                child: thumbOk
                    ? LayoutBuilder(builder: (ctx, box) {
                        final count = (box.maxWidth / 54).ceil();
                        return Row(
                          children: [
                            for (var i = 0; i < count; i++)
                              Expanded(
                                child: Image.file(
                                  File(clip.thumbPath!),
                                  fit: BoxFit.cover,
                                  cacheWidth: 72,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                          ],
                        );
                      })
                    : Center(
                        child: Icon(
                          clip.type == MediaType.photo
                              ? Icons.image_outlined
                              : Icons.videocam_outlined,
                          size: 22,
                          color: dark
                              ? AppColors.darkTextDim
                              : AppColors.lightTextDim,
                        ),
                      ),
              ),
              // تعتيم خفيف + اسم
              PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: Colors.black.withValues(alpha: 0.45),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          clip.type == MediaType.photo
                              ? '${clip.photoDuration.toStringAsFixed(1)}s'
                              : S.durationLabel(clip.timelineDuration),
                          style: AppFont.w(600,
                              size: 9, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                      if (clip.muted)
                        const Icon(Icons.volume_off,
                            size: 10, color: Colors.white70),
                      if (clip.reversed)
                        const Icon(Icons.replay, size: 10, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              // مقابض التشذيب
              if (selected) ...[
                _TrimHandle(alignStart: true, onDrag: onTrimStart),
                _TrimHandle(alignStart: false, onDrag: onTrimEnd),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrimHandle extends StatelessWidget {
  final bool alignStart;
  final ValueChanged<double> onDrag;
  const _TrimHandle({required this.alignStart, required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      start: alignStart ? 0 : null,
      end: alignStart ? null : 0,
      top: 0,
      bottom: 0,
      width: 18,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
        child: Container(
          alignment: Alignment.center,
          color: AppColors.blue,
          child: Container(
            width: 3.2,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransitionBadge extends StatelessWidget {
  final VoidCallback onTap;
  const _TransitionBadge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Icon(Icons.swap_horiz, size: 15, color: Colors.white),
      ),
    );
  }
}

class _AddClipButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddClipButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: dark ? AppColors.darkBorder : AppColors.lightBorder,
              width: 1.2,
            ),
          ),
          child: Icon(
            Icons.add,
            color: dark ? AppColors.darkTextDim : AppColors.lightTextDim,
          ),
        ),
      ),
    );
  }
}

class _AudioBlock extends StatelessWidget {
  final AudioTrack track;
  final double pps;
  final VoidCallback onTap;
  const _AudioBlock({
    required this.track,
    required this.pps,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = track.kind == AudioKind.voice
        ? AppColors.warn
        : track.kind == AudioKind.extracted
            ? AppColors.success
            : AppColors.blue;
    return Positioned(
      left: track.startAt * pps,
      width: (track.duration * pps).clamp(20.0, double.infinity),
      top: 0,
      height: 30,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: color.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              Icon(
                track.kind == AudioKind.voice
                    ? Icons.mic
                    : track.kind == AudioKind.extracted
                        ? Icons.graphic_eq
                        : Icons.music_note,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  track.title,
                  style: AppFont.w(600, size: 9.5, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final double start;
  final double duration;
  final double pps;
  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  const _OverlayPill({
    required this.start,
    required this.duration,
    required this.pps,
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: start * pps,
      width: (duration * pps).clamp(24.0, double.infinity),
      top: 0,
      height: 30,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.35 : 0.18),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: AppFont.w(600, size: 9.5, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Playhead extends StatelessWidget {
  final double height;
  final bool dark;
  final double time;
  const _Playhead({
    required this.height,
    required this.dark,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.blue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              S.durationLabel(time),
              style: AppFont.w(700, size: 9.5, color: Colors.white),
              textDirection: TextDirection.ltr,
            ),
          ),
          Expanded(
            child: Container(
              width: 2.2,
              color: AppColors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double pps;
  final double total;
  final bool dark;
  _RulerPainter({required this.pps, required this.total, required this.dark});

  static const _steps = [0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0, 30.0, 60.0, 120.0];

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = dark
          ? AppColors.darkTextDim.withValues(alpha: 0.5)
          : AppColors.lightTextDim.withValues(alpha: 0.5)
      ..strokeWidth = 1;

    var step = _steps.last;
    for (final s in _steps) {
      if (s * pps >= 52) {
        step = s;
        break;
      }
    }

    final labelStyle = TextStyle(
      color: dark ? AppColors.darkTextDim : AppColors.lightTextDim,
      fontSize: 8.5,
    );

    var t = 0.0;
    while (t * pps < size.width) {
      final x = t * pps;
      canvas.drawLine(Offset(x, size.height - 7), Offset(x, size.height), line);
      // شرطة فرعية
      if (t + step / 2 < total || total == 0) {
        final xm = (t + step / 2) * pps;
        canvas.drawLine(
            Offset(xm, size.height - 4), Offset(xm, size.height), line);
      }
      final tp = TextPainter(
        text: TextSpan(text: _label(t), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 3, 2));
      t += step;
    }
  }

  String _label(double t) {
    if (t >= 60) {
      final m = t ~/ 60;
      final s = (t % 60).round();
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    if (t % 1 == 0) return '${t.toInt()}s';
    return t.toStringAsFixed(1);
  }

  @override
  bool shouldRepaint(covariant _RulerPainter old) =>
      old.pps != pps || old.total != total || old.dark != dark;
}
