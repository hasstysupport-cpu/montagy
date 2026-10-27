import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_font.dart';
import '../../../core/strings.dart';
import '../../../data/models.dart';
import '../editor_screen.dart';

/// شاشة الاقتصاص التفاعلية — سحب إطار على الصورة.
class CropScreen extends StatefulWidget {
  final ClipItem clip;
  const CropScreen({super.key, required this.clip});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  Rect _rect = const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9);
  final _handleSize = 26.0;

  @override
  void initState() {
    super.initState();
    _rect = widget.clip.crop ??
        const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9);
  }

  void _update(Offset normalized, {bool isStart = false}) {
    setState(() {
      var left = _rect.left;
      var top = _rect.top;
      var right = _rect.right;
      var bottom = _rect.bottom;
      if (isStart) {
        left = normalized.dx.clamp(0.0, right - 0.08);
        top = normalized.dy.clamp(0.0, bottom - 0.08);
      } else {
        right = normalized.dx.clamp(left + 0.08, 1.0);
        bottom = normalized.dy.clamp(top + 0.08, 1.0);
      }
      _rect = Rect.fromLTRB(left, top, right, bottom);
    });
  }

  void _pan(Offset delta, Size box) {
    setState(() {
      var left = (_rect.left + delta.dx / box.width).clamp(0.0, 1 - _rect.width);
      var top = (_rect.top + delta.dy / box.height).clamp(0.0, 1 - _rect.height);
      _rect = Rect.fromLTWH(left, top, _rect.width, _rect.height);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isPhoto = widget.clip.type == MediaType.photo;
    final imagePath =
        isPhoto ? widget.clip.sourcePath : widget.clip.thumbPath;

    return Scaffold(
      backgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
      appBar: AppBar(
        title: AppFont.w(700, size: 16).make(S.crop),
        actions: [
          if (widget.clip.crop != null)
            TextButton(
              onPressed: () {
                state.updateClip(widget.clip.copyWith(crop: null, clearCrop: true));
                Navigator.pop(context);
              },
              child: const Text(S.reset),
            ),
          TextButton(
            onPressed: () {
              final crop = Rect.fromLTWH(
                _rect.left.clamp(0.0, 1.0),
                _rect.top.clamp(0.0, 1.0),
                _rect.width.clamp(0.08, 1.0),
                _rect.height.clamp(0.08, 1.0),
              );
              state.updateClip(widget.clip.copyWith(crop: crop));
              Navigator.pop(context);
            },
            child: const Text(S.save),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(builder: (ctx, box) {
                  Widget image;
                  if (imagePath != null && File(imagePath).existsSync()) {
                    image = Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.error_outline),
                    );
                  } else {
                    image = const Center(child: CircularProgressIndicator());
                  }
                  return AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRect(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          image,
                          // قناع خارج الإطار
                          CustomPaint(
                            painter: _CropMaskPainter(_rect),
                          ),
                          // إطار
                          Positioned.fromRect(
                            rect: Rect.fromLTWH(
                              _rect.left * box.maxWidth,
                              _rect.top * box.maxHeight,
                              _rect.width * box.maxWidth,
                              _rect.height * box.maxHeight,
                            ),
                            child: GestureDetector(
                              onPanUpdate: (d) => _pan(d.delta, box.biggest),
                              child: Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: AppColors.cyan, width: 1.8),
                                ),
                                child: Stack(
                                  children: [
                                    // مقبض بداية (أعلى يسار)
                                    Positioned(
                                      left: 0,
                                      top: 0,
                                      width: _handleSize,
                                      height: _handleSize,
                                      child: GestureDetector(
                                        onPanUpdate: (d) => _update(
                                          Offset(
                                            (_rect.left * box.maxWidth +
                                                    d.delta.dx) /
                                                box.maxWidth,
                                            (_rect.top * box.maxHeight +
                                                    d.delta.dy) /
                                                box.maxHeight,
                                          ),
                                          isStart: true,
                                        ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: AppColors.cyan,
                                            borderRadius: BorderRadius.only(
                                                bottomRight:
                                                    Radius.circular(14)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // مقبض نهاية (أسفل يمين)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      width: _handleSize,
                                      height: _handleSize,
                                      child: GestureDetector(
                                        onPanUpdate: (d) => _update(
                                          Offset(
                                            (_rect.right * box.maxWidth +
                                                    d.delta.dx) /
                                                box.maxWidth,
                                            (_rect.bottom * box.maxHeight +
                                                    d.delta.dy) /
                                                box.maxHeight,
                                          ),
                                        ),
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            color: AppColors.cyan,
                                            borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(14)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppFont.w(500, size: 12.5,
                      color: dark
                          ? AppColors.darkTextDim
                          : AppColors.lightTextDim)
                  .make('اسحب الإطار أو المقابض لتحديد منطقة الاقتصاص'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CropMaskPainter extends CustomPainter {
  final Rect rect;
  _CropMaskPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final r = Rect.fromLTWH(
      rect.left * size.width,
      rect.top * size.height,
      rect.width * size.width,
      rect.height * size.height,
    );
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(r, Radius.zero))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CropMaskPainter old) => old.rect != rect;
}

