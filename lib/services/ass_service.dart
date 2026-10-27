import 'dart:io';

import '../models/caption.dart';
import '../models/caption_style.dart';

/// Converts caption segments + styles into a **libass** subtitle file (.ass)
/// burned by FFmpeg. Supports:
///  • TikTok karaoke word-by-word highlight (\k tags)
///  • YouTube classic outline
///  • Neon glow (blur + colored outline layers)
///  • Opaque box backgrounds (BorderStyle=3)
///  • Top/Center/Bottom anchoring (ASS alignment)
///  • RTL-safe Arabic via fribidi shaping (handled natively by libass)
class AssService {
  AssService._();

  // ASS colour: &HAABBGGRR (alpha inverted: 00 = opaque)
  static String _assColor(Color c, {bool opaque = true}) {
    final a = opaque ? 0x00 : 0xFF;
    final b = c.blue, g = c.green, r = c.red;
    return '&H${a.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${r.toRadixString(16).padLeft(2, '0')}';
  }

  static String _ts(double t) {
    t = t.clamp(0, 1e9);
    final h = (t ~/ 3600).toString().padLeft(1, '0');
    final m = ((t % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (t % 60).floor().toString().padLeft(2, '0');
    final cs = (((t - t.floor()) * 100).round()).clamp(0, 99).toString().padLeft(2, '0');
    return '$h:$m:$s.$cs';
  }

  static String _alignmentFor(CaptionPosition p) => switch (p) {
        CaptionPosition.top => '8',
        CaptionPosition.center => '5',
        CaptionPosition.bottom => '2',
      };

  /// MarginV: bottom/top captions sit 7% from edge; centered ignores it.
  static int _marginFor(CaptionPosition p, int videoH) {
    final v = (videoH * 0.07).round();
    return p == CaptionPosition.center ? 10 : v;
  }

  /// Build a full .ass file for one caption style (project-wide default,
  /// per-segment overrides handled via secondary dialogue styles).
  static String build({
    required List<CaptionSegment> captions,
    required Map<String, CaptionStyle> stylesById,
    required int videoW,
    required int videoH,
  }) {
    final buf = StringBuffer();
    buf.writeln('[Script Info]');
    buf.writeln('ScriptType: v4.00+');
    buf.writeln('PlayResX: $videoW');
    buf.writeln('PlayResY: $videoH');
    buf.writeln('WrapStyle: 0');
    buf.writeln('ScaledBorderAndShadow: yes');
    buf.writeln();

    buf.writeln('[V4+ Styles]');
    buf.writeln(
        'Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');

    // One ASS style per caption style id actually used.
    final usedIds = captions.map((c) => c.styleId).toSet();
    for (final id in usedIds) {
      final s = stylesById[id] ?? CaptionStylePresets.tiktokKaraoke;
      final fontSize = (videoH * s.fontSizePct / 100).round().clamp(10, videoH);
      final hasBox = s.bgColor != null;
      final hollow = s.textColor.value == 0x00000000;
      buf.writeln([
        'Style: $id',
        s.fontFamily,
        '$fontSize',
        // Primary: karaoke fills this colour; hollow text uses stroke colour as primary.
        _assColor(hollow ? s.strokeColor : s.textColor),
        // Secondary: the colour shown BEFORE karaoke highlight reaches the word.
        _assColor(hollow ? s.textColor : _dim(s.textColor)),
        _assColor(s.strokeColor),
        _assColor(s.bgColor ?? const Color(0x00000000), opaque: hasBox),
        s.bold ? '-1' : '0',
        '0', '0', '0',
        '100', '100',
        s.letterSpacing.toStringAsFixed(1),
        '0',
        hasBox ? '3' : '1', // BorderStyle: 3 = opaque box
        hasBox ? '6' : s.strokeWidth.toStringAsFixed(1),
        s.shadowColor.value == 0x00000000 && s.blur <= 0
            ? '0'
            : '2',
        _alignmentFor(captions.firstWhere((c) => c.styleId == id).position),
        '40', '40',
        '${_marginFor(captions.firstWhere((c) => c.styleId == id).position, videoH)}',
        '1',
      ].join(', '));
    }
    buf.writeln();

    buf.writeln('[Events]');
    buf.writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (final c in captions) {
      final s = stylesById[c.styleId] ?? CaptionStylePresets.tiktokKaraoke;
      final text = s.uppercase ? c.text.toUpperCase() : c.text;

      String dialogueText;
      switch (s.anim) {
        case CaptionAnim.karaoke:
          dialogueText = _karaoke(c, text, s);
          break;
        case CaptionAnim.pop:
          dialogueText = r'{\fscx80\fscy80\t(0,120,\fscx105\fscy105)\t(120,220,\fscx100\fscy100)}' + text;
          break;
        case CaptionAnim.typewriter:
          dialogueText = _typewriter(c, text);
          break;
        case CaptionAnim.wave:
          dialogueText = r'{\t(0,400,\frz2)\t(400,800,\frz-2)\t(800,1200,\frz0)}' + text;
          break;
        case CaptionAnim.slideUp:
          dialogueText =
              r'{\move(' '${(videoW / 2).round()},${(videoH * 0.92).round()},${(videoW / 2).round()},${(videoH * 0.88).round()},0,250)}' +
                  text;
          break;
        case CaptionAnim.none:
          dialogueText = text;
      }

      // Neon glow: prefix blur tag.
      if (s.blur > 0) {
        dialogueText = r'{\blur' + (s.blur / 6).toStringAsFixed(2) + '}' + dialogueText;
      }

      buf.writeln(
          'Dialogue: 0,${_ts(c.start)},${_ts(c.end)},${c.styleId},,0,0,0,,${dialogueText.replaceAll('\n', r'\N')}');
    }
    return buf.toString();
  }

  /// Word-by-word karaoke using \k (centiseconds) — the highlight sweeps
  /// Primary over Secondary colour exactly like TikTok/Reels captions.
  static String _karaoke(CaptionSegment c, String text, CaptionStyle s) {
    var words = c.words;
    if (words.isEmpty) {
      final tmp = CaptionSegment(
        id: c.id, text: text, start: c.start, end: c.end, styleId: c.styleId,
      )..distributeWords();
      words = tmp.words;
    }
    if (words.isEmpty) return text;
    // Karaoke is relative to the line start.
    final lineStart = c.start;
    final buf = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      final cs = (((w.end - lineStart) - (i == 0 ? 0 : (words[i - 1].end - lineStart))) * 100)
          .round()
          .clamp(1, 9999);
      buf.write(r'{\k$cs'.replaceFirst(r'$cs', cs.toString()));
      buf.write(w.text);
      if (i < words.length - 1) buf.write(' ');
    }
    return buf.toString();
  }

  /// Typewriter: reveal characters stepwise using \t-free approach — emit one
  /// dialogue with progressively longer text is heavy; use \k on characters.
  static String _typewriter(CaptionSegment c, String text) {
    final chars = text.split('');
    final per = ((c.end - c.start) * 100 / (chars.length.clamp(1, 999))).round().clamp(1, 100);
    return chars.map((ch) => r'{\k$per'.replaceFirst(r'$per', per.toString()) + ch).join();
  }

  static Color _dim(Color c) {
    const f = 0.55;
    return Color.fromARGB(255, (c.red * f).round(), (c.green * f).round(), (c.blue * f).round());
  }

  /// Writes the .ass to disk and returns its path.
  static Future<String> writeAssFile({
    required String dir,
    required List<CaptionSegment> captions,
    required Map<String, CaptionStyle> stylesById,
    required int videoW,
    required int videoH,
  }) async {
    final f = File('$dir/captions_${DateTime.now().millisecondsSinceEpoch}.ass');
    await f.writeAsString(build(
      captions: captions,
      stylesById: stylesById,
      videoW: videoW,
      videoH: videoH,
    ));
    return f.path;
  }
}
