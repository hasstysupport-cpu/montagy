import '../models/caption.dart';

/// Parses & writes SRT (and a basic VTT reader) — fully offline.
class SrtService {
  SrtService._();

  static final _timeRe =
      RegExp(r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})');

  static double _toSec(List<String?> g, int i) {
    final h = int.parse(g[i]!);
    final m = int.parse(g[i + 1]!);
    final s = int.parse(g[i + 2]!);
    final ms = int.parse(g[i + 3]!.padRight(3, '0').substring(0, 3));
    return h * 3600 + m * 60 + s + ms / 1000;
  }

  /// Returns segments in file order.
  static List<CaptionSegment> parse(String content, {required String styleId, required String Function() newId}) {
    final lines = content.replaceAll('\r\n', '\n').split('\n');
    final out = <CaptionSegment>[];
    var i = 0;
    while (i < lines.length) {
      final m = _timeRe.firstMatch(lines[i]);
      if (m == null) {
        i++;
        continue;
      }
      final g = m.groups([1, 2, 3, 4, 5, 6, 7, 8]);
      final start = _toSec(g, 0);
      final end = _toSec(g, 4);
      i++;
      final buf = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty && !lines[i].contains('-->')) {
        buf.add(lines[i]);
        i++;
      }
      final text = buf.join('\n')
          .replaceAll(RegExp(r'<[^>]+>'), '') // strip html tags
          .trim();
      if (text.isNotEmpty) {
        final seg = CaptionSegment(
          id: newId(),
          text: text,
          start: start,
          end: end,
          styleId: styleId,
        );
        seg.distributeWords();
        out.add(seg);
      }
    }
    return out;
  }

  static String _fmt(double t) {
    final h = (t ~/ 3600).toString().padLeft(2, '0');
    final m = ((t % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (t % 60).floor().toString().padLeft(2, '0');
    final ms = ((t - t.floor()) * 1000).round().toString().padLeft(3, '0');
    return '$h:$m:$s,$ms';
  }

  static String export(List<CaptionSegment> captions) {
    final buf = StringBuffer();
    for (var i = 0; i < captions.length; i++) {
      final c = captions[i];
      buf
        ..writeln('${i + 1}')
        ..writeln('${_fmt(c.start)} --> ${_fmt(c.end)}')
        ..writeln(c.text)
        ..writeln();
    }
    return buf.toString();
  }
}
