import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_font.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import '../../editor/editor_state.dart';
import 'editor_screen.dart';

/// منطقة المعاينة — فيديو/صورة + فلاتر + طبقات تفاعلية.
class PreviewView extends StatelessWidget {
  final VoidCallback onAddMedia;
  const PreviewView({super.key, required this.onAddMedia});

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: dark ? AppColors.darkBg : AppColors.lightBg,
      child: ListenableBuilder(
        listenable: state,
        builder: (ctx, _) {
          if (state.project.clips.isEmpty) {
            return _EmptyPreview(onAddMedia: onAddMedia);
          }
          final clip = state.currentClipIndex < state.project.clips.length
              ? state.project.clips[state.currentClipIndex]
              : null;
          if (clip == null) return const SizedBox.shrink();
          final aspect = state.project.canvas.aspect.ratio;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (state.selectedClipId != null ||
                  state.selectedTextId != null ||
                  state.selectedStickerId != null) {
                state.selectClip(null);
              } else {
                state.togglePlay();
              }
            },
            child: LayoutBuilder(builder: (ctx, box) {
              var w = box.maxWidth;
              var h = w / aspect;
              if (h > box.maxHeight) {
                h = box.maxHeight;
                w = h * aspect;
              }
              return Center(
                child: SizedBox(
                  width: w,
                  height: h,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Background(clip: clip),
                        _ClipSurface(clip: clip, state: state),
                        if (state.activeVignette(clip) > 0.01)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _VignettePainter(state.activeVignette(clip)),
                            ),
                          ),
                        const _OverlaysLayer(),
                        const _PlayButton(),
                        _ClipBadges(clip: clip),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  final VoidCallback onAddMedia;
  const _EmptyPreview({required this.onAddMedia});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onAddMedia,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.blue.withValues(alpha: 0.4),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(Icons.add, size: 40, color: Colors.white),
            ),
          ),
          const SizedBox(height: 18),
          Text(S.emptyEditorTitle, style: AppFont.w(800, size: 17)),
          const SizedBox(height: 6),
          Text(S.emptyEditorHint,
              style: AppFont.w(400,
                  size: 12,
                  color: dark ? AppColors.darkTextDim : AppColors.lightTextDim)),
        ],
      ),
    );
  }
}

/// خلفية الكانفس.
class _Background extends StatelessWidget {
  final ClipItem clip;
  const _Background({required this.clip});

  @override
  Widget build(BuildContext context) {
    final canvasBg = EditorScope.of(context).project.canvas;
    if (canvasBg.bg == CanvasBg.blur) {
      final thumb = clip.thumbPath;
      final ok = thumb != null && File(thumb).existsSync();
      return Container(
        color: Colors.black,
        child: ok
            ? Image.file(
                File(thumb),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                cacheWidth: 240,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : null,
      );
    }
    final color = canvasBg.bg == CanvasBg.white
        ? Colors.white
        : canvasBg.bg == CanvasBg.custom
            ? canvasBg.customColor
            : Colors.black;
    return Container(color: color);
  }
}

/// عرض المقطع الحالي مع الفلاتر والتحويلات.
class _ClipSurface extends StatelessWidget {
  final ClipItem clip;
  final EditorState state;
  const _ClipSurface({required this.clip, required this.state});

  @override
  Widget build(BuildContext context) {
    final matrix = state.activeFilterMatrix(clip);

    Widget content;
    if (clip.type == MediaType.photo) {
      content = Image.file(
        File(clip.sourcePath),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const _MediaError(),
      );
    } else {
      final ctrl = state.controllerFor(clip);
      if (ctrl != null && ctrl.value.isInitialized) {
        content = _videoTransform(ctrl, clip);
      } else if (clip.thumbPath != null && File(clip.thumbPath!).existsSync()) {
        content = Image.file(
          File(clip.thumbPath!),
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: 480,
          errorBuilder: (_, __, ___) => const _MediaError(),
        );
      } else {
        content = const Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        );
      }
    }

    if (matrix != null) {
      content = ColorFiltered(
        colorFilter: ColorFilter.matrix(matrix),
        child: content,
      );
    }
    return content;
  }

  Widget _videoTransform(VideoPlayerController ctrl, ClipItem clip) {
    final size = ctrl.value.size;
    final video = AspectRatio(
      aspectRatio: size.aspectRatio == 0 ? 9 / 16 : size.aspectRatio,
      child: VideoPlayer(ctrl),
    );

    // تدوير: عند 90/270 نلف الحاوية
    Widget transformed = video;
    if (clip.rotation == 90 || clip.rotation == 270) {
      transformed = RotatedBox(
        quarterTurns: clip.rotation == 90 ? -1 : 1,
        child: AspectRatio(
          aspectRatio: 1 / (size.aspectRatio == 0 ? 9 / 16 : size.aspectRatio),
          child: video,
        ),
      );
    } else if (clip.rotation == 180) {
      transformed = RotatedBox(quarterTurns: 2, child: video);
    }

    if (clip.flipH || clip.flipV) {
      transformed = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(clip.flipH ? -1.0 : 1.0, clip.flipV ? -1.0 : 1.0),
        child: transformed,
      );
    }

    if (clip.crop != null) {
      final c = clip.crop!;
      return LayoutBuilder(builder: (ctx, box) {
        return FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            // حجم "الشاشة الكاملة" قبل الاقتصاص
            width: box.maxWidth / c.width,
            height: box.maxHeight / c.height,
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: Offset(
                  -c.left * box.maxWidth / c.width,
                  -c.top * box.maxHeight / c.height,
                ),
                child: transformed,
              ),
            ),
          ),
        );
      });
    }

    return Center(child: transformed);
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_outlined, size: 38, color: Colors.white38),
          const SizedBox(height: 8),
          AppFont.w(500, size: 12, color: Colors.white54).make('تعذر عرض المقطع'),
        ],
      ),
    );
  }
}

/// طبقة النصوص والملصقات — سحب + تكبير بالقرص.
class _OverlaysLayer extends StatelessWidget {
  const _OverlaysLayer();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final texts = state.activeTexts(state.projectTime).toList();
    final stickers = state.activeStickers(state.projectTime).toList();

    return LayoutBuilder(builder: (ctx, box) {
      return Stack(
        fit: StackFit.expand,
        children: [
          for (final t in texts)
            _OverlayGesture(
              key: ValueKey('txt_${t.id}'),
              nx: t.nx,
              ny: t.ny,
              currentScale: t.scale,
              selected: state.selectedTextId == t.id,
              onSelect: () => state.selectText(t.id),
              onMove: (nx, ny) => state.updateText(t
                ..nx = nx.clamp(0.02, 0.98)
                ..ny = ny.clamp(0.02, 0.98)),
              onScale: (s) => state.updateText(t..scale = s.clamp(0.2, 6)),
              child: Transform.rotate(
                angle: -t.rotation * math.pi / 180,
                child: _textContent(t, box.maxHeight),
              ),
            ),
          for (final s in stickers)
            _OverlayGesture(
              key: ValueKey('stk_${s.id}'),
              nx: s.nx,
              ny: s.ny,
              currentScale: s.scale,
              selected: state.selectedStickerId == s.id,
              onSelect: () => state.selectSticker(s.id),
              onMove: (nx, ny) => state.updateSticker(s
                ..nx = nx.clamp(0.02, 0.98)
                ..ny = ny.clamp(0.02, 0.98)),
              onScale: (sc) => state.updateSticker(s..scale = sc.clamp(0.02, 2)),
              child: Transform.rotate(
                angle: -s.rotation * math.pi / 180,
                child: Opacity(
                  opacity: s.opacity.clamp(0, 1),
                  child: s.emoji != null
                      ? Text(
                          s.emoji!,
                          style: TextStyle(
                            fontSize: s.scale * box.maxHeight * 0.82,
                            height: 1.05,
                          ),
                          textDirection: TextDirection.ltr,
                        )
                      : (s.imagePath != null &&
                              File(s.imagePath!).existsSync()
                          ? Image.file(
                              File(s.imagePath!),
                              height: s.scale * box.maxHeight,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            )
                          : const SizedBox.shrink()),
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _textContent(TextOverlay t, double frameH) {
    final fontSize = (t.fontSize * frameH * t.scale).clamp(8, 800).toDouble();
    final align = t.textAlign == 0
        ? TextAlign.center
        : (t.textAlign == 1 ? TextAlign.right : TextAlign.left);

    final isVar = !FontCatalogStatic.isStatic(t.fontFamily);
    final base = TextStyle(
      fontFamily: t.fontFamily,
      fontSize: fontSize,
      color: t.color,
      height: 1.25,
      shadows: t.hasShadow
          ? [
              Shadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: fontSize * 0.15,
                offset: Offset(0, fontSize * 0.05),
              )
            ]
          : null,
      fontVariations: isVar ? const [FontVariation('wght', 700)] : null,
    );

    Widget text = Text(
      t.text,
      style: base,
      textAlign: align,
    );

    if (t.hasStroke) {
      text = Stack(
        alignment: Alignment.center,
        children: [
          Text(
            t.text,
            textAlign: align,
            style: base.copyWith(
              color: null,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = t.strokeWidth * fontSize
                ..strokeCap = StrokeCap.round
                ..strokeJoin = StrokeJoin.round
                ..color = t.strokeColor,
            ),
          ),
          text,
        ],
      );
    }

    if (t.hasBg) {
      text = Container(
        padding: EdgeInsets.symmetric(
          horizontal: fontSize * 0.35,
          vertical: fontSize * 0.16,
        ),
        decoration: BoxDecoration(
          color: t.bgColor.withValues(alpha: t.bgOpacity),
          borderRadius: BorderRadius.circular(fontSize * 0.32),
        ),
        child: text,
      );
    }
    return text;
  }
}

/// جسد الإيماءات المشترك للطبقات.
class _OverlayGesture extends StatefulWidget {
  final double nx, ny;
  final double currentScale;
  final bool selected;
  final VoidCallback onSelect;
  final void Function(double nx, double ny) onMove;
  final ValueChanged<double> onScale;
  final Widget child;

  const _OverlayGesture({
    super.key,
    required this.nx,
    required this.ny,
    required this.currentScale,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onScale,
    required this.child,
  });

  @override
  State<_OverlayGesture> createState() => _OverlayGestureState();
}

class _OverlayGestureState extends State<_OverlayGesture> {
  double _gestureBaseScale = 1;
  double _startNx = 0.5, _startNy = 0.5;
  Offset _startFocal = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onSelect,
        onScaleStart: (d) {
          _gestureBaseScale = widget.currentScale;
          _startNx = widget.nx;
          _startNy = widget.ny;
          _startFocal = d.localFocalPoint;
          widget.onSelect();
        },
        onScaleUpdate: (d) {
          final box = context.size;
          if (box == null) return;
          if (d.pointerCount >= 2 && d.scale > 0.01) {
            widget.onScale(_gestureBaseScale * d.scale);
          }
          final nx =
              _startNx + (d.localFocalPoint.dx - _startFocal.dx) / box.width;
          final ny =
              _startNy + (d.localFocalPoint.dy - _startFocal.dy) / box.height;
          widget.onMove(nx, ny);
        },
        child: Align(
          alignment: Alignment(widget.nx * 2 - 1, widget.ny * 2 - 1),
          child: Container(
            decoration: widget.selected
                ? BoxDecoration(
                    border: Border.all(color: AppColors.cyan, width: 1.6),
                    borderRadius: BorderRadius.circular(6),
                  )
                : null,
            padding: widget.selected ? const EdgeInsets.all(5) : EdgeInsets.zero,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// زر تشغيل مركزي.
class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (ctx, _) {
        if (state.playing) return const SizedBox.shrink();
        return Center(
          child: GestureDetector(
            onTap: () => state.togglePlay(),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow,
                  size: 36, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

class _ClipBadges extends StatelessWidget {
  final ClipItem clip;
  const _ClipBadges({required this.clip});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];
    if (clip.reversed) {
      badges.add(const _Badge(icon: Icons.replay, label: S.reversed));
    }
    if (clip.speed != 1) {
      badges.add(_Badge(icon: Icons.speed, label: S.speedLabel(clip.speed)));
    }
    if (badges.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: badges,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Badge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          AppFont.w(600, size: 10.5, color: Colors.white).make(label),
        ],
      ),
    );
  }
}

class _VignettePainter extends CustomPainter {
  final double strength;
  _VignettePainter(this.strength);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.05,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: strength * 0.85),
        ],
        stops: const [0.45, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _VignettePainter old) =>
      old.strength != strength;
}

/// بيانات الخطوط الثابتة/المتغيرة (نسخة عرض).
class FontCatalogStatic {
  static const Set<String> staticFonts = {
    'Amiri', 'Lalezar', 'ArefRuqaa', 'IBMPlexSansArabic',
    'BebasNeue', 'Pacifico',
  };
  static bool isStatic(String family) => staticFonts.contains(family);
}
