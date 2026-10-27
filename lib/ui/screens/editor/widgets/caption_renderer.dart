import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/caption.dart';
import '../../../../models/caption_style.dart';

TextStyle captionFont(String family, {double? size, FontWeight? weight, Color? color, double? spacing}) {
  final gf = switch (family) {
    'Tajawal' => GoogleFonts.tajawal,
    'Almarai' => GoogleFonts.almarai,
    'Anton' => GoogleFonts.anton,
    'BebasNeue' => GoogleFonts.bebasNeue,
    'Lalezar' => GoogleFonts.lalezar,
    'Changa' => GoogleFonts.changa,
    _ => GoogleFonts.tajawal,
  };
  return gf(fontSize: size, fontWeight: weight, color: color, letterSpacing: spacing, height: 1.3);
}

List<Shadow> strokeShadowsOf(Color color, double width) => [
      if (width > 0)
        for (var a = 0; a < 12; a++)
          Shadow(color: color, blurRadius: 0.5, offset: Offset.fromDirection(a * math.pi / 6, width)),
    ];

/// Public entry — renders a caption segment at time [t].
/// Karaoke styles get per-word highlighting; everything else here.
Widget buildCaptionWidget({
  required CaptionSegment segment,
  required CaptionStyle style,
  required double t,
  required double videoHeightPx,
}) {
  if (style.anim == CaptionAnim.karaoke) {
    return _KaraokeCaption(segment: segment, style: style, t: t, videoHeightPx: videoHeightPx);
  }
  return _SimpleCaption(segment: segment, style: style, t: t, videoHeightPx: videoHeightPx);
}

class _SimpleCaption extends StatelessWidget {
  final CaptionSegment segment;
  final CaptionStyle style;
  final double t;
  final double videoHeightPx;

  const _SimpleCaption({
    required this.segment,
    required this.style,
    required this.t,
    required this.videoHeightPx,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = (videoHeightPx * style.fontSizePct / 100) * segment.fontSizeScale;
    final local = t - segment.start;
    final dur = segment.duration;
    final hollow = style.textColor.value == 0x00000000;

    final raw = style.uppercase ? segment.text.toUpperCase() : segment.text;
    var ts = captionFont(
      style.fontFamily,
      size: fontSize,
      weight: style.bold ? FontWeight.w800 : FontWeight.w500,
      color: hollow ? Colors.transparent : style.textColor,
      spacing: style.letterSpacing,
    ).copyWith(shadows: [
      ...strokeShadowsOf(style.strokeColor, style.strokeWidth),
      if (style.blur > 0) Shadow(color: style.shadowColor, blurRadius: style.blur),
      if (style.blur <= 0 && style.shadowColor.value != 0x00000000)
        Shadow(color: style.shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
    ]);

    Widget content = Text(raw, style: ts);

    switch (style.anim) {
      case CaptionAnim.typewriter:
        final n = ((local / dur).clamp(0.0, 1.0) * raw.length).floor();
        content = Text(raw.substring(0, n.clamp(0, raw.length)), style: ts);
        break;
      case CaptionAnim.pop:
        final scale = local < 0.12
            ? 0.8 + (local / 0.12) * 0.25
            : local < 0.22
                ? 1.05 - ((local - 0.12) / 0.10) * 0.05
                : 1.0;
        content = Transform.scale(scale: scale, child: content);
        break;
      case CaptionAnim.slideUp:
        content = TweenAnimationBuilder<double>(
          tween: Tween(begin: 26.0, end: 0.0),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (_, v, child) => Transform.translate(offset: Offset(0, v), child: child),
          child: content,
        );
        break;
      case CaptionAnim.wave:
        final words = raw.split(' ');
        content = Wrap(
          alignment: WrapAlignment.center,
          spacing: fontSize * 0.35,
          runSpacing: 4,
          children: [
            for (var i = 0; i < words.length; i++)
              Transform.translate(
                offset: Offset(0, -6 * math.sin(local * 4 + i * 0.9)),
                child: Text(words[i], style: ts),
              ),
          ],
        );
        break;
      case CaptionAnim.karaoke:
      case CaptionAnim.none:
        break;
    }

    if (style.bgColor != null) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.55, vertical: fontSize * 0.28),
        decoration: BoxDecoration(
          color: style.bgColor!.withOpacity(style.bgOpacity),
          borderRadius: BorderRadius.circular(fontSize * 0.35),
        ),
        child: content,
      );
    }

    final align = switch (segment.position) {
      CaptionPosition.top => Alignment.topCenter,
      CaptionPosition.center => Alignment.center,
      CaptionPosition.bottom => Alignment.bottomCenter,
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 1.2, vertical: videoHeightPx * 0.06),
      child: Align(alignment: align, child: content),
    );
  }
}

class _KaraokeCaption extends StatelessWidget {
  final CaptionSegment segment;
  final CaptionStyle style;
  final double t;
  final double videoHeightPx;

  const _KaraokeCaption({
    required this.segment,
    required this.style,
    required this.t,
    required this.videoHeightPx,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = (videoHeightPx * style.fontSizePct / 100) * segment.fontSizeScale;
    final hollow = style.textColor.value == 0x00000000;

    List<TimedWord> words = segment.words;
    if (words.isEmpty) {
      final tmp = CaptionSegment(
        id: segment.id, text: segment.text, start: segment.start, end: segment.end, styleId: segment.styleId,
      )..distributeWords();
      words = tmp.words;
    }

    final base = captionFont(
      style.fontFamily,
      size: fontSize,
      weight: style.bold ? FontWeight.w800 : FontWeight.w500,
      spacing: style.letterSpacing,
    );
    final strokes = strokeShadowsOf(style.strokeColor, style.strokeWidth);
    final hollowFill = style.strokeColor.withOpacity(.35);

    Widget makeWord(int i, String w) {
      final wStart = segment.start + (words[i].start - segment.start);
      final wEnd = segment.start + (words[i].end - segment.start);
      final active = t >= wStart && t < wEnd;
      final passed = t >= wEnd;
      final color = active
          ? style.highlightColor
          : passed
              ? (hollow ? style.strokeColor : style.textColor)
              : (hollow ? hollowFill : style.textColor);
      final ts = base.copyWith(color: color, shadows: [
        ...strokes,
        if (style.blur > 0) Shadow(color: style.shadowColor, blurRadius: style.blur),
        if (active) Shadow(color: style.highlightColor.withOpacity(.85), blurRadius: 22),
      ]);
      Widget word = Text(w, style: ts);
      if (active) word = Transform.scale(scale: 1.07, child: word);
      return word;
    }

    Widget content;
    if (words.isEmpty) {
      content = Text(segment.text, style: base.copyWith(color: style.textColor));
    } else {
      content = Wrap(
        alignment: WrapAlignment.center,
        spacing: fontSize * 0.32,
        runSpacing: fontSize * 0.15,
        children: [
          for (var i = 0; i < words.length; i++) makeWord(i, words[i].text),
        ],
      );
    }

    if (style.bgColor != null) {
      content = Container(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.55, vertical: fontSize * 0.28),
        decoration: BoxDecoration(
          color: style.bgColor!.withOpacity(style.bgOpacity),
          borderRadius: BorderRadius.circular(fontSize * 0.35),
        ),
        child: content,
      );
    }

    final align = switch (segment.position) {
      CaptionPosition.top => Alignment.topCenter,
      CaptionPosition.center => Alignment.center,
      CaptionPosition.bottom => Alignment.bottomCenter,
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 1.2, vertical: videoHeightPx * 0.06),
      child: Align(alignment: align, child: content),
    );
  }
}
