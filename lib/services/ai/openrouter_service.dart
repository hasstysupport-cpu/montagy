import 'dart:convert';

import 'package:http/http.dart' as http;

/// OpenAI-compatible chat client pointed at OpenRouter (free models supported).
/// Tool calling follows the OpenAI function-calling schema.
class ChatMessage {
  final String role; // system | user | assistant | tool
  final String content;
  final String? toolCallId;
  final List<Map<String, dynamic>>? toolCalls; // assistant requesting tools

  const ChatMessage({
    required this.role,
    required this.content,
    this.toolCallId,
    this.toolCalls,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (toolCalls != null)
          'tool_calls': toolCalls!.map((t) {
            final id = t['id'] as String;
            final name = t['name'] as String;
            final args = t['arguments'] as String;
            return {
              'id': id,
              'type': 'function',
              'function': {'name': name, 'arguments': args},
            };
          }).toList(),
        if (toolCallId != null) 'tool_call_id': toolCallId,
      };
}

class ChatResult {
  final String content;
  final List<ToolCall> toolCalls;
  const ChatResult({required this.content, required this.toolCalls});
}

class ToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  const ToolCall({required this.id, required this.name, required this.arguments});
}

class OpenRouterService {
  OpenRouterService._();

  static const endpoint = 'https://openrouter.ai/api/v1/chat/completions';

  /// Popular free models (suffix :free) shown in settings.
  static const freeModels = [
    'deepseek/deepseek-chat-v3-0324:free',
    'qwen/qwen-2.5-72b-instruct:free',
    'meta-llama/llama-3.3-70b-instruct:free',
    'google/gemma-3-27b-it:free',
    'mistralai/mistral-small-3.1-24b-instruct:free',
  ];

  static Future<ChatResult> chat({
    required String apiKey,
    required String model,
    required List<ChatMessage> messages,
    List<Map<String, dynamic>> tools = const [],
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
      'max_tokens': maxTokens,
    };
    if (tools.isNotEmpty) {
      body['tools'] = [
        for (final t in tools)
          {
            'type': 'function',
            'function': t,
          }
      ];
    }
    final res = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://montagy.app',
        'X-Title': 'Montagy',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      throw Exception('OpenRouter ${res.statusCode}: ${_tail(res.body)}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choice = ((data['choices'] as List?) ?? []).firstOrNull;
    if (choice == null) throw Exception('Empty response');
    final msg = choice['message'] as Map<String, dynamic>;
    final content = msg['content']?.toString() ?? '';
    final rawCalls = (msg['tool_calls'] as List?) ?? [];
    final calls = <ToolCall>[];
    for (final c in rawCalls) {
      final fn = (c['function'] as Map<String, dynamic>);
      calls.add(ToolCall(
        id: c['id']?.toString() ?? '',
        name: fn['name']?.toString() ?? '',
        arguments: _safeJson(fn['arguments']?.toString() ?? '{}'),
      ));
    }
    return ChatResult(content: content, toolCalls: calls);
  }

  static Map<String, dynamic> _safeJson(String s) {
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  static String _tail(String s) => s.length <= 300 ? s : s.substring(s.length - 300);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
