import 'dart:convert';

import 'package:http/http.dart' as http;

/// DuckDuckGo Instant-Answer + HTML search (no API key needed).
/// Falls back to Tavily if the user set a key in settings.
class WebSearchService {
  WebSearchService._();

  static Future<String> search(String query, {String tavilyKey = ''}) async {
    if (tavilyKey.trim().isNotEmpty) {
      try {
        return await _tavily(query, tavilyKey);
      } catch (_) {/* fall through to ddg */}
    }
    return _duckduckgo(query);
  }

  static Future<String> _tavily(String query, String key) async {
    final res = await http.post(
      Uri.parse('https://api.tavily.com/search'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'api_key': key, 'query': query, 'max_results': 5}),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('tavily ${res.statusCode}');
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? [];
    final buf = StringBuffer();
    for (final r in results) {
      buf.writeln('• ${(r['title'] ?? '')} — ${(r['content'] ?? '')}'.substring(0, 300));
      buf.writeln('  ${r['url'] ?? ''}');
    }
    return buf.toString();
  }

  static Future<String> _duckduckgo(String query) async {
    final client = http.Client();
    try {
      final res = await client.post(
        Uri.parse('https://html.duckduckgo.com/html/'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Mozilla/5.0 (MontagyApp/1.0)',
        },
        body: 'q=${Uri.encodeComponent(query)}',
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return 'Search unavailable (HTTP ${res.statusCode}).';
      // Minimal snippet extraction — results are inside <a class="result__a">…</a>
      final reg = RegExp(r'<a[^>]*class="result__a"[^>]*>(.*?)</a>', dotAll: true);
      final snipReg = RegExp(r'<a[^>]*class="result__snippet"[^>]*>(.*?)</a>', dotAll: true);
      final titles = reg.allMatches(res.body).take(5).toList();
      final snips = snipReg.allMatches(res.body).take(5).toList();
      if (titles.isEmpty) return 'No results found.';
      String clean(String s) => s
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#x27;', "'")
          .trim();
      final buf = StringBuffer();
      for (var i = 0; i < titles.length; i++) {
        buf.writeln('• ${clean(titles[i].group(1) ?? "")}');
        if (i < snips.length) buf.writeln('  ${clean(snips[i].group(1) ?? "")}');
      }
      return buf.toString();
    } finally {
      client.close();
    }
  }
}
