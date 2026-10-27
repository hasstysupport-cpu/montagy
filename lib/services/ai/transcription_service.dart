import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class TranscriptSegment {
  final double start;
  final double end;
  final String text;
  const TranscriptSegment({required this.start, required this.end, required this.text});
}

/// Speech-to-text with word/segment timestamps.
/// Providers: Groq Whisper (fast, free tier) and Google Gemini (audio-capable).
class TranscriptionService {
  TranscriptionService._();

  /// Groq — whisper-large-v3-turbo, verbose JSON with segment timestamps.
  static Future<List<TranscriptSegment>> viaGroq({
    required String apiKey,
    required String audioPath,
    String language = '', // '' = auto
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
    );
    req.headers['Authorization'] = 'Bearer $apiKey';
    req.fields['model'] = 'whisper-large-v3-turbo';
    req.fields['response_format'] = 'verbose_json';
    if (language.isNotEmpty) req.fields['language'] = language;
    final file = await http.MultipartFile.fromPath('file', audioPath);
    req.files.add(file);
    final streamed = await req.send().timeout(const Duration(minutes: 3));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw Exception('Groq STT ${streamed.statusCode}: ${_tail(body)}');
    }
    final data = jsonDecode(body) as Map<String, dynamic>;
    final segs = (data['segments'] as List?) ?? [];
    return [
      for (final s in segs)
        TranscriptSegment(
          start: (s['start'] as num?)?.toDouble() ?? 0,
          end: (s['end'] as num?)?.toDouble() ?? 0,
          text: (s['text'] as String? ?? '').trim(),
        ),
    ];
  }

  /// Gemini — inline base64 audio; prompt asks for JSON segments.
  static Future<List<TranscriptSegment>> viaGemini({
    required String apiKey,
    required String audioPath,
  }) async {
    final f = File(audioPath);
    if (f.lengthSync() > 18 * 1024 * 1024) {
      throw Exception('Audio too large for inline Gemini upload (>18MB)');
    }
    final b64 = base64Encode(await f.readAsBytes());
    final model = 'gemini-2.0-flash';
    final uri =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
    final res = await http.post(
      Uri.parse(uri),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': 'Transcribe this audio. Return ONLY a JSON array of segments, '
                  'each {"start": seconds, "end": seconds, "text": "..."}. '
                  'Keep natural sentence boundaries. No markdown, no commentary.'},
              {
                'inline_data': {'mime_type': 'audio/m4a', 'data': b64}
              },
            ]
          }
        ],
        'generationConfig': {'temperature': 0},
      }),
    ).timeout(const Duration(minutes: 3));
    if (res.statusCode != 200) {
      throw Exception('Gemini STT ${res.statusCode}: ${_tail(res.body)}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final text = (((data['candidates'] as List?)?.firstOrNull
                as Map<String, dynamic>?)?['content'] as Map<String, dynamic>)['parts']
        .map((p) => p['text'] ?? '')
        .join();
    return _parseSegmentsJson(text);
  }

  /// Robustly parse a JSON array out of a model reply (strips markdown fences).
  static List<TranscriptSegment> _parseSegmentsJson(String raw) {
    var s = raw.trim();
    s = s.replaceFirst(RegExp(r'^```(json)?'), '').replaceFirst(RegExp(r'```$'), '').trim();
    final start = s.indexOf('[');
    final end = s.lastIndexOf(']');
    if (start == -1 || end == -1) throw Exception('AI did not return JSON');
    final arr = jsonDecode(s.substring(start, end + 1)) as List;
    return [
      for (final e in arr)
        TranscriptSegment(
          start: (e['start'] as num?)?.toDouble() ?? 0,
          end: (e['end'] as num?)?.toDouble() ?? 0,
          text: (e['text'] as String? ?? '').trim(),
        ),
    ].where((e) => e.text.isNotEmpty).toList();
  }

  static String _tail(String s) => s.length <= 300 ? s : s.substring(s.length - 300);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
