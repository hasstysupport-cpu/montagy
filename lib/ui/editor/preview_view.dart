import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_font.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import '../../editor/editor_state.dart';
import 'dialogs/text_edit_sheet.dart';
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
                        _EffectsLayer(clip: clip, state: state),
                        if (state.activeVignette(clip) > 0.01)
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _VignettePainter(state.activeVignette(clip)),
                            ),
                          ),
                        // خطوط التوسيط (دلائل التصاق)
                        const _CenterGuides(),
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
                    color: context.accent.withValues(alpha: 0.4),
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
              currentRotation: t.rotation,
              selected: state.selectedTextId == t.id,
              onSelect: () => state.selectText(t.id),
              onMove: (nx, ny) => state.updateText(t
                ..nx = nx.clamp(0.02, 0.98)
                ..ny = ny.clamp(0.02, 0.98)),
              onScale: (s) => state.updateText(t..scale = s.clamp(0.2, 6)),
              onRotate: (deg) => state.updateText(t..rotation = deg.clamp(-180, 180)),
              child: Transform.rotate(
                angle: -t.rotation * math.pi / 180,
                child: _textContent(t, box.maxHeight),
              ),
              onEdit: () => showTextEditSheet(context, t),
            ),
          for (final s in stickers)
            if (s.isVideoLayer)
              _VideoLayerView(s: s)
            else ...[
              Builder(builder: (_) {
                final rs = s.resolvedAt(state.projectTime);
                return _OverlayGesture(
                  key: ValueKey('stk_${s.id}'),
                  nx: rs.nx,
                  ny: rs.ny,
                  currentScale: rs.scale,
                  currentRotation: rs.rotation,
                  selected: state.selectedStickerId == s.id,
                  onSelect: () => state.selectSticker(s.id),
                  onMove: (nx, ny) => state.updateSticker(s
                    ..nx = nx.clamp(0.02, 0.98)
                    ..ny = ny.clamp(0.02, 0.98)),
                  onScale: (sc) =>
                      state.updateSticker(s..scale = sc.clamp(0.02, 2)),
                  onRotate: (deg) =>
                      state.updateSticker(s..rotation = deg.clamp(-180, 180)),
                  child: Transform.rotate(
                    angle: -rs.rotation * math.pi / 180,
                    child: Opacity(
                      opacity: rs.opacity.clamp(0, 1),
                      child: s.emoji != null
                          ? Text(
                              s.emoji!,
                              style: TextStyle(
                                fontSize: rs.scale * box.maxHeight * 0.82,
                                height: 1.05,
                              ),
                              textDirection: TextDirection.ltr,
                            )
                          : (s.imagePath != null &&
                                  File(s.imagePath!).existsSync()
                              ? Image.file(
                                  File(s.imagePath!),
                                  height: rs.scale * box.maxHeight,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                )
                              : const SizedBox.shrink()),
                    ),
                  ),
                );
              }),
            ],
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

/// طبقة فيديو PiP — مشغل حقيقي قابل للسحب والتحجيم والتدوير.
class _VideoLayerView extends StatefulWidget {
  final ImageOverlay s;
  const _VideoLayerView({required this.s});

  @override
  State<_VideoLayerView> createState() => _VideoLayerViewState();
}

class _VideoLayerViewState extends State<_VideoLayerView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = EditorScope.of(context);
      state.ensureLayerController(widget.s);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final rs = widget.s.resolvedAt(state.projectTime);
    final ctrl = state.layerControllerFor(widget.s);

    Widget content;
    if (ctrl != null && ctrl.value.isInitialized) {
      final size = ctrl.value.size;
      final aspect = size.aspectRatio == 0 ? 9 / 16 : size.aspectRatio;
      content = AspectRatio(
        aspectRatio: aspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: VideoPlayer(ctrl),
        ),
      );
    } else {
      content = Container(
        width: 120,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return _OverlayGesture(
      key: ValueKey('vid_${widget.s.id}'),
      nx: rs.nx,
      ny: rs.ny,
      currentScale: rs.scale,
      currentRotation: rs.rotation,
      selected: state.selectedStickerId == widget.s.id,
      onSelect: () => state.selectSticker(widget.s.id),
      onMove: (nx, ny) => state.updateSticker(widget.s
        ..nx = nx.clamp(0.02, 0.98)
        ..ny = ny.clamp(0.02, 0.98)),
      onScale: (sc) => state.updateSticker(widget.s..scale = sc.clamp(0.08, 1.2)),
      onRotate: (deg) =>
          state.updateSticker(widget.s..rotation = deg.clamp(-180, 180)),
      child: Transform.rotate(
        angle: -rs.rotation * math.pi / 180,
        child: Opacity(
          opacity: rs.opacity.clamp(0, 1),
          child: content,
        ),
      ),
    );
  }
}

/// طبقة المعاينة للمؤثرات — تمثيل تقريبي فوري (التصدير يطبق السلسلة الحقيقية).
class _EffectsLayer extends StatelessWidget {
  final ClipItem clip;
  final EditorState state;
  const _EffectsLayer({required this.clip, required this.state});

  @override
  Widget build(BuildContext context) {
    final fx = clip.effects;
    if (fx.isEmpty) return const SizedBox.shrink();

    final children = <Widget>[];

    // ضبابي
    final blur = (fx['softblur'] ?? 0) > 0.01
        ? fx['softblur']!
        : ((fx['deepblur'] ?? 0) > 0.01 ? 0.5 + fx['deepblur']! / 2 : 0.0);
    if (blur > 0.01) {
      children.add(IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(
              sigmaX: 2 + blur * 10, sigmaY: 2 + blur * 10, tileMode: TileMode.clamp),
          child: const SizedBox.expand(),
        ),
      ));
    }

    // حبيبات
    if ((fx['grain'] ?? 0) > 0.01) {
      children.add(IgnorePointer(
        child: CustomPaint(
          painter: _GrainPainter(strength: fx['grain']!),
          child: const SizedBox.expand(),
        ),
      ));
    }

    // اهتزاز — يُطبق عبر Transform على المحتوى الكلي (تقريب)
    // نون: تعديل ألوان بسيط
    if ((fx['neon'] ?? 0) > 0.01) {
      final s = fx['neon']!;
      children.add(IgnorePointer(
        child: Container(
          color: Colors.white.withValues(alpha: 0.03 + 0.05 * s),
          child: const SizedBox.expand(),
        ),
      ));
    }

    // توهج / حلمي
    if ((fx['glow'] ?? 0) > 0.01 || (fx['dreamy'] ?? 0) > 0.01) {
      final g = ((fx['glow'] ?? 0) + (fx['dreamy'] ?? 0)).clamp(0.0, 1.0);
      children.add(IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              radius: 1.2,
              colors: [
                Colors.white.withValues(alpha: 0.06 + 0.12 * g),
                Colors.transparent,
              ],
            ),
          ),
          child: const SizedBox.expand(),
        ),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(fit: StackFit.expand, children: children),
    );
  }
}

/// رسام الحبيبات — نقاط شفافة عشوائية (تقريب للـ noise).
class _GrainPainter extends CustomPainter {
  final double strength;
  _GrainPainter({required this.strength});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05 + 0.1 * strength);
    final count = (120 + 260 * strength).round();
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      canvas.drawRect(
          Rect.fromLTWH(dx, dy, 1.2, 1.2),
          Paint()
            ..color = (i.isEven ? Colors.white : Colors.black)
                .withValues(alpha: 0.04 + 0.09 * strength));
    }
    paint.color = Colors.transparent;
  }

  @override
  bool shouldRepaint(covariant _GrainPainter old) => old.strength != strength;
}

/// جسد الإيماءات المشترك للطبقات — نمط CapCut/InShot:
/// إصبع واحد = تحريك | قرص = تكبير | لف إصبعين = تدوير | التصاق بخطوط التوسيط.
class _OverlayGesture extends StatefulWidget {
  final double nx, ny;
  final double currentScale;
  final double currentRotation;
  final bool selected;
  final VoidCallback onSelect;
  final void Function(double nx, double ny) onMove;
  final ValueChanged<double> onScale;
  final ValueChanged<double> onRotate;
  final VoidCallback? onEdit;
  final Widget child;

  const _OverlayGesture({
    super.key,
    required this.nx,
    required this.ny,
    required this.currentScale,
    required this.currentRotation,
    required this.selected,
    required this.onSelect,
    required this.onMove,
    required this.onScale,
    required this.onRotate,
    required this.child,
    this.onEdit,
  });

  @override
  State<_OverlayGesture> createState() => _OverlayGestureState();
}

class _OverlayGestureState extends State<_OverlayGesture> {
  double _gestureBaseScale = 1;
  double _startRotation = 0;
  double _startNx = 0.5, _startNy = 0.5;
  Offset _startFocal = Offset.zero;
  bool _snappedX = false;
  bool _snappedY = false;

  @override
  Widget build(BuildContext context) {
    final accent = context.accent;

    return Positioned.fill(
      child: Align(
        alignment: Alignment(widget.nx * 2 - 1, widget.ny * 2 - 1),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onSelect,
          onScaleStart: (d) {
            widget.onSelect();
            _gestureBaseScale = widget.currentScale;
            _startRotation = widget.currentRotation;
            _startNx = widget.nx;
            _startNy = widget.ny;
            _startFocal = d.localFocalPoint;
            _snappedX = false;
            _snappedY = false;
          },
          onScaleUpdate: (d) {
            final box = context.size;
            if (box == null) return;

            // تكبير بالقرص
            if (d.pointerCount >= 2 && d.scale > 0.01) {
              widget.onScale(_gestureBaseScale * d.scale);
              // تدوير بلف الإصبعين
              final degDelta = -d.rotation * 180 / math.pi;
              if (d.rotation.abs() > 0.01) {
                widget.onRotate(_startRotation + degDelta);
              }
            }

            // تحريك بالإصبع مع التصاق مركزي
            var nx =
                _startNx + (d.localFocalPoint.dx - _startFocal.dx) / box.width;
            var ny =
                _startNy + (d.localFocalPoint.dy - _startFocal.dy) / box.height;

            const snapT = 0.014;
            var didSnap = false;
            if ((nx - 0.5).abs() < snapT) {
              nx = 0.5;
              didSnap = true;
            }
            if ((ny - 0.5).abs() < snapT) {
              ny = 0.5;
              didSnap = true;
            }
            if (didSnap && (!_snappedX && nx == 0.5 || !_snappedY && ny == 0.5)) {
              HapticFeedback.selectionClick();
            }
            _snappedX = nx == 0.5;
            _snappedY = ny == 0.5;

            widget.onMove(nx, ny);
          },
          child: _SelectionFrame(
            selected: widget.selected,
            accent: accent,
            onEdit: widget.onEdit,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// إطار التحديد + أزرار الزوايا (حذف/تحرير) — نمط InShot.
class _SelectionFrame extends StatelessWidget {
  final bool selected;
  final Color accent;
  final VoidCallback? onEdit;
  final Widget child;

  const _SelectionFrame({
    required this.selected,
    required this.accent,
    required this.child,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    if (!selected) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1.6),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
              ),
            ],
          ),
          child: child,
        ),
        // زر الحذف — أعلى اليسار
        Positioned(
          left: -4,
          top: -4,
          child: _CornerButton(
            icon: Icons.close,
            onTap: () => EditorScope.of(context).clearSelection(),
            onTapDelete: () {
              final state = EditorScope.of(context);
              final t = state.selectedText;
              if (t != null) {
                state.deleteText(t);
                return;
              }
              final s = state.selectedSticker;
              if (s != null) state.deleteSticker(s);
            },
          ),
        ),
        // زر التحرير — أسفل اليمين (نصوص فقط)
        if (onEdit != null)
          Positioned(
            right: -4,
            bottom: -4,
            child: _CornerButton(
              icon: Icons.edit_outlined,
              onTap: onEdit,
              onTapDelete: null,
            ),
          ),
      ],
    );
  }
}

/// زر زاوية دائري صغير (حذف/تحرير فوق حدود العنصر).
class _CornerButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onTapDelete;

  const _CornerButton({required this.icon, this.onTap, this.onTapDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapDelete ?? onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTapDelete != null ? AppColors.danger : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTapDelete != null ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

/// خطوط التوسيط — تظهر عند التصاق الطبقة بمركز الكانفس.
class _CenterGuides extends StatelessWidget {
  const _CenterGuides();

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    return ListenableBuilder(
      listenable: state,
      builder: (ctx, _) {
        var showV = false;
        var showH = false;
        final t = state.selectedText;
        if (t != null) {
          showV = (t.nx - 0.5).abs() < 0.004;
          showH = (t.ny - 0.5).abs() < 0.004;
        } else {
          final s = state.selectedSticker;
          if (s != null) {
            showV = (s.nx - 0.5).abs() < 0.004;
            showH = (s.ny - 0.5).abs() < 0.004;
          }
        }
        if (!showV && !showH) return const SizedBox.shrink();
        return IgnorePointer(
          child: CustomPaint(
            painter: _GuidesPainter(showV: showV, showH: showH),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _GuidesPainter extends CustomPainter {
  final bool showV, showH;
  _GuidesPainter({required this.showV, required this.showH});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    if (showV) {
      canvas.drawLine(Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height), paint);
    }
    if (showH) {
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width, size.height / 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GuidesPainter old) =>
      old.showV != showV || old.showH != showH;
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
