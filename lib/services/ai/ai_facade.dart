import 'dart:convert';

import '../../state/settings_provider.dart';
import '../../models/caption.dart';
import '../../models/caption_style.dart';
import '../ffmpeg_service.dart';
import 'openrouter_service.dart';
import 'transcription_service.dart';
import 'package:uuid/uuid.dart';

/// Facade over the AI providers with graceful fallbacks:
///  • Transcription: Groq → Gemini
///  • Text tasks (polish / translate / motion scenes / agent): OpenRouter
class AiFacade {
  AiFacade._();

  static String _orModel(AppSettings s) => s.openrouterModel;

  static bool hasTextModel(AppSettings s) => s.openrouterKey.trim().isNotEmpty;
  static bool hasStt(AppSettings s) => s.groqKey.trim().isNotEmpty || s.geminiKey.trim().isNotEmpty;

  // ---------- Auto captions ----------

  /// 1) Transcribe → 2) build caption segments with word timing.
  /// [language] ISO code hint ('ar' | 'en' | '' auto).
  static Future<List<CaptionSegment>> autoCaptions({
    required AppSettings settings,
    required String videoPath,
    required String styleId,
    String language = '',
  }) async {
    // Extract compressed audio first (whisper + inline uploads prefer small files).
    final audioPath = await _extractAudio(videoPath);
    List<TranscriptSegment> segs;
    if (settings.groqKey.trim().isNotEmpty) {
      segs = await TranscriptionService.viaGroq(
          apiKey: settings.groqKey.trim(), audioPath: audioPath, language: language);
    } else if (settings.geminiKey.trim().isNotEmpty) {
      segs = await TranscriptionService.viaGemini(apiKey: settings.geminiKey.trim(), audioPath: audioPath);
    } else {
      throw Exception('NO_STT_KEY');
    }
    return _segmentsToCaptions(segs, styleId);
  }

  static Future<String> _extractAudio(String videoPath) async {
    return FfmpegService.instance.extractAudio(videoPath);
  }

  static List<CaptionSegment> _segmentsToCaptions(List<TranscriptSegment> segs, String styleId) {
    final uuid = const Uuid();
    final out = <CaptionSegment>[];
    // Merge tiny fragments into readable 1-2 line captions (<= ~70 chars).
    var buf = '';
    double? bufStart;
    double bufEnd = 0;
    void flush() {
      if (buf.trim().isEmpty || bufStart == null) return;
      final c = CaptionSegment(
        id: uuid.v4(),
        text: buf.trim(),
        start: bufStart!,
        end: bufEnd,
        styleId: styleId,
      );
      c.distributeWords();
      out.add(c);
      buf = '';
      bufStart = null;
    }

    for (final s in segs) {
      if (bufStart == null) bufStart = s.start;
      if (buf.length + s.text.length > 70) flush();
      if (bufStart == null) bufStart = s.start;
      buf = buf.isEmpty ? s.text : '$buf ${s.text}';
      bufEnd = s.end;
      final dur = bufEnd - (bufStart ?? 0);
      if (dur > 4.5) flush();
    }
    flush();
    return out;
  }

  // ---------- Text helpers ----------

  static Future<String> polishCaption(AppSettings s, String text, {String targetLang = ''}) async {
    final sys = 'You are a short-video caption editor. Rewrite the user text to be punchy, '
        'natural and grammatically correct. ${targetLang.isEmpty ? "Keep the same language." : "Reply in $targetLang."} '
        'Return ONLY the rewritten text, nothing else.';
    final r = await OpenRouterService.chat(
      apiKey: s.openrouterKey.trim(),
      model: _orModel(s),
      messages: [
        ChatMessage(role: 'system', content: sys),
        ChatMessage(role: 'user', content: text),
      ],
      temperature: 0.5,
      maxTokens: 300,
    );
    return r.content.trim();
  }

  static Future<String> translate(AppSettings s, String text, String toLang) async {
    return polishCaption(s, text, targetLang: toLang);
  }

  /// AI writes a MotionScene (same DSL as models/motion_scene.dart).
  static Future<Map<String, dynamic>> generateMotionScene({
    required AppSettings s,
    required String prompt,
    required double videoDuration,
    required String language,
  }) async {
    final sys = 'You generate JSON motion-graphics scenes for a video editor. '
        'Schema: {"name": string, "elements": [{type:"text|emoji|shape", text?: string, emoji?: string, '
        'shape?: "pill|rect|circle|underline", start: number(sec), end: number(sec), x:0..1, y:0..1, '
        'fontSizePct: number(3..16), font: "Tajawal|Almarai|Anton|BebasNeue|Lalezar", color: "#RRGGBB", '
        'accent: "#RRGGBB", anim: "popIn|fadeIn|slideUp|slideDown|typewriter|pulse|shake|wipe", loop: boolean}]}. '
        'Video duration is $videoDuration seconds. Times must stay inside it. '
        'Language for any text: $language. Return ONLY JSON, no markdown.';
    final r = await OpenRouterService.chat(
      apiKey: s.openrouterKey.trim(),
      model: _orModel(s),
      messages: [
        ChatMessage(role: 'system', content: sys),
        ChatMessage(role: 'user', content: prompt),
      ],
      temperature: 0.8,
      maxTokens: 1600,
    );
    var t = r.content.trim();
    t = t.replaceFirst(RegExp(r'^```(json)?'), '').replaceFirst(RegExp(r'```$'), '').trim();
    final st = t.indexOf('{');
    final en = t.lastIndexOf('}');
    if (st == -1 || en == -1) throw Exception('AI_BAD_JSON');
    return Map<String, dynamic>.from(jsonDecode(t.substring(st, en + 1)) as Map<String, dynamic>);
  }

  static Future<List<CaptionSegment>> polishCaptions({
    required AppSettings settings,
    required List<CaptionSegment> captions,
    required String mode, // polish | translate | hashtags
    required String lang,
  }) async {
    final joined = captions
        .map((c) => '${c.start.toStringAsFixed(2)}|${c.end.toStringAsFixed(2)}|${c.text.replaceAll('|', ' ')}')
        .join('\n');
    final sys = switch (mode) {
      'translate' => 'Translate each subtitle line to $lang. Keep timing lines EXACTLY as given. '
          'Output format: start|end|translated text per line, nothing else.',
      'hashtags' => 'Rewrite each subtitle line to be social-media friendly, punchy and clean. '
          'Keep timing lines EXACTLY. Output format: start|end|text per line, nothing else.',
      _ => 'Fix grammar/typos of each subtitle line, keep meaning and language. '
          'Keep timing lines EXACTLY. Output format: start|end|text per line, nothing else.',
    };
    final r = await OpenRouterService.chat(
      apiKey: settings.openrouterKey.trim(),
      model: _orModel(settings),
      messages: [
        ChatMessage(role: 'system', content: sys),
        ChatMessage(role: 'user', content: joined),
      ],
      temperature: 0.4,
      maxTokens: 2500,
    );
    final out = <CaptionSegment>[];
    final uuid = const Uuid();
    for (final line in r.content.split('\n')) {
      final parts = line.split('|');
      if (parts.length < 3) continue;
      final st = double.tryParse(parts[0].trim());
      final en = double.tryParse(parts[1].trim());
      final txt = parts.sublist(2).join('|').trim();
      if (st == null || en == null || txt.isEmpty) continue;
      // match nearest existing caption to keep styling
      final match = _nearest(captions, st);
      final c = CaptionSegment(
        id: uuid.v4(),
        text: txt,
        start: st,
        end: en,
        styleId: match?.styleId ?? settings.defaultCaptionStyleId,
        position: match?.position ?? CaptionPosition.bottom,
      );
      c.distributeWords();
      out.add(c);
    }
    return out.isEmpty ? captions : out;
  }

  static CaptionSegment? _nearest(List<CaptionSegment> list, double t) {
    CaptionSegment? best;
    var bestD = double.infinity;
    for (final c in list) {
      final d = (c.start - t).abs();
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }
}


