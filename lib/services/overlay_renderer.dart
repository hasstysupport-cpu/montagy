import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/font_catalog.dart';
import '../data/models.dart';

/// يرسم النصوص والملصقات إلى PNG شفاف بدقة الفيديو النهائية —
/// يضمن عربية مثالية (تشكيل + اتجاه) مطابقة 100% للمعاينة.
class OverlayRenderer {
  static final Set<String> _loaded = {};

  static const Map<String, String> _assets = {
    'Alexandria': 'assets/fonts/Alexandria.ttf',
    'IBMPlexSansArabic': 'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    'Amiri': 'assets/fonts/Amiri-Regular.ttf',
    'ReemKufi': 'assets/fonts/ReemKufi.ttf',
    'ElMessiri': 'assets/fonts/ElMessiri.ttf',
    'Changa': 'assets/fonts/Changa.ttf',
    'Lalezar': 'assets/fonts/Lalezar-Regular.ttf',
    'BalooBhaijaan2': 'assets/fonts/BalooBhaijaan2.ttf',
    'ArefRuqaa': 'assets/fonts/ArefRuqaa-Regular.ttf',
    'Marhey': 'assets/fonts/Marhey.ttf',
    'Rubik': 'assets/fonts/Rubik.ttf',
    'BebasNeue': 'assets/fonts/BebasNeue-Regular.ttf',
    'Pacifico': 'assets/fonts/Pacifico-Regular.ttf',
    'PlayfairDisplay': 'assets/fonts/PlayfairDisplay.ttf',
  };

  /// يحمل كل الخطوط المطلوبة مرة واحدة.
  static Future<void> ensureFonts(Iterable<String> families) async {
    for (final f in families) {
      final asset = _assets[f] ?? _assets['Alexandria']!;
      final key = '$f|$asset';
      if (_loaded.contains(key)) continue;
      try {
        final loader = FontLoader('exp_$f');
        loader.addFont(rootBundle.load(asset));
        await loader.load();
        _loaded.add(key);
      } catch (_) {
        // نجرب العائلة الأصلية إن فشل التحميل
      }
    }
  }

  static TextStyle _textStyle(TextOverlay t, double fontPx, {Paint? foreground}) {
    final isVariable = !FontCatalog.staticFonts.contains(t.fontFamily);
    return TextStyle(
      fontFamily: 'exp_${t.fontFamily}',
      fontSize: fontPx,
      color: foreground == null ? t.color : null,
      foreground: foreground,
      height: 1.25,
      shadows: t.hasShadow && foreground == null
          ? [Shadow(color: Colors.black.withValues(alpha: 0.65), blurRadius: fontPx * 0.12, offset: Offset(0, fontPx * 0.045))]
          : null,
      fontVariations: isVariable ? const [FontVariation('wght', 700)] : null,
    );
  }

  /// يرسم طبقة نص إلى PNG.
  static Future<File> renderText(TextOverlay t,
      {required int frameW, required int frameH, required String outPath}) async {
    await ensureFonts([t.fontFamily]);
    final fontPx = (t.fontSize * frameH * t.scale).clamp(12, frameH * 0.9).toDouble();
    final align = t.textAlign == 0
        ? TextAlign.center
        : (t.textAlign == 1 ? TextAlign.right : TextAlign.left);

    final tp = TextPainter(
      text: TextSpan(text: t.text, style: _textStyle(t, fontPx)),
      textDirection: TextDirection.rtl,
      textAlign: align,
    );
    tp.layout(maxWidth: frameW * 0.92);
    final pad = math.max(fontPx * 0.22, 8.0);
    final contentW = tp.width + pad * 2;
    final contentH = tp.height + pad * 2;

    // حدود الدوران
    final rad = t.rotation * math.pi / 180.0;
    final cosA = math.cos(rad).abs(), sinA = math.sin(rad).abs();
    final outW = (contentW * cosA + contentH * sinA).ceil();
    final outH = (contentW * sinA + contentH * cosA).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(outW / 2, outH / 2);
    canvas.rotate(rad);
    canvas.translate(-contentW / 2, -contentH / 2);

    if (t.hasBg) {
      final rrect = RRect.fromRectAndRadius(
        Offset.zero & Size(contentW, contentH),
        Radius.circular(math.min(contentH * 0.28, fontPx * 0.4)),
      );
      canvas.drawRRect(rrect, Paint()..color = t.bgColor.withValues(alpha: t.bgOpacity));
    }
    if (t.hasStroke) {
      final strokeTp = TextPainter(
        text: TextSpan(
            text: t.text,
            style: _textStyle(t, fontPx,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = t.strokeWidth * fontPx
                  ..strokeCap = StrokeCap.round
                  ..strokeJoin = StrokeJoin.round
                  ..color = t.strokeColor)),
        textDirection: TextDirection.rtl,
        textAlign: align,
      )..layout(maxWidth: frameW * 0.92);
      strokeTp.paint(canvas, Offset(pad, pad));
    }
    tp.paint(canvas, Offset(pad, pad));

    final img = await recorder.endRecording().toImage(outW, outH);
    return _savePng(img, outPath);
  }

  /// يرسم ملصق إيموجي إلى PNG.
  static Future<File> renderEmoji(String emoji,
      {required double relScale, required int frameH, required String outPath}) async {
    final fontPx = (relScale * frameH).clamp(16, frameH * 0.95).toDouble();
    final tp = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: fontPx, height: 1.1),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    tp.layout();
    final pad = fontPx * 0.12;
    final w = (tp.width + pad * 2).ceil();
    final h = (tp.height + pad * 2).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    tp.paint(canvas, Offset(pad, pad));
    final img = await recorder.endRecording().toImage(w, h);
    return _savePng(img, outPath);
  }

  /// يعيد حجم صورة ملصق إلى البكسل المطلوب (مع دوران اختياري).
  static Future<File> renderImage(String imagePath,
      {required double relScale,
      required int frameH,
      double rotationDeg = 0,
      required String outPath}) async {
    final data = await File(imagePath).readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    final src = frame.image;
    final targetH = (relScale * frameH).round().clamp(8, 4096);
    final scale = targetH / src.height;
    final targetW = (src.width * scale).round().clamp(8, 4096);

    final rad = rotationDeg * math.pi / 180.0;
    final cosA = math.cos(rad).abs(), sinA = math.sin(rad).abs();
    final outW = (targetW * cosA + targetH * sinA).ceil();
    final outH = (targetW * sinA + targetH * cosA).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(outW / 2, outH / 2);
    canvas.rotate(rad);
    final dst = Rect.fromCenter(
        center: Offset.zero, width: targetW.toDouble(), height: targetH.toDouble());
    final srcRect = Rect.fromLTWH(
        0, 0, src.width.toDouble(), src.height.toDouble());
    canvas.drawImageRect(src, srcRect, dst, Paint()..filterQuality = FilterQuality.high);
    final img = await recorder.endRecording().toImage(outW, outH);
    return _savePng(img, outPath);
  }

  static Future<File> _savePng(ui.Image img, String path) async {
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw Exception('PNG encode failed');
    final f = File(path);
    await f.writeAsBytes(data.buffer.asUint8List());
    img.dispose();
    return f;
  }

  static String pngName(String prefix, String id) => '$prefix${_safe(id)}.png';

  static String _safe(String s) {
    final clean = s.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return clean.substring(0, clean.length.clamp(0, 14));
  }
}
