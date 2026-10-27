import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/motion_scene.dart';
import '../../state/editor_controller.dart';
import '../../state/settings_provider.dart';
import 'ai_facade.dart';
import 'agent_tools.dart';
import 'openrouter_service.dart';

/// The AI agent loop: system prompt + tools → model → execute tool calls on
/// the live project → feed results back → repeat (max 8 hops).
Future<String> runAgentLoop({
  required WidgetRef ref,
  required String userText,
  required void Function(String toolName, String summary) onTool,
}) async {
  final settings = ref.read(settingsProvider);
  final ctrl = ref.read(editorProvider.notifier);
  final project = ctrl.state.project;

  if (!AiFacade.hasTextModel(settings)) {
    return 'محتاج مفتاح OpenRouter من الإعدادات الأول ⚙️';
  }

  final messages = <ChatMessage>[
    ChatMessage(
      role: 'system',
      content: 'You are Montagy Agent, an assistant inside a mobile video editor. '
          'The user speaks Arabic (Egyptian) or English. '
          'You can call tools to modify their CURRENT project. Use tools whenever relevant; '
          'after tools finish, reply with a SHORT friendly summary of what you did. '
          'Project: "${project.name}", ${project.clips.length} clips, '
          '${project.totalDuration.toStringAsFixed(1)}s total, ${project.captions.length} captions, '
          'style=${project.captionStyleId}.',
    ),
    ChatMessage(role: 'user', content: userText),
  ];

  final tools = AgentTools.schemas();
  final ctx = AgentContext(project, settings);

  for (var hop = 0; hop < 8; hop++) {
    final result = await OpenRouterService.chat(
      apiKey: settings.openrouterKey.trim(),
      model: settings.openrouterModel,
      messages: messages,
      tools: tools,
    );

    if (result.toolCalls.isEmpty) {
      return result.content;
    }

    messages.add(ChatMessage(role: 'assistant', content: result.content, toolCalls: [
      for (final tc in result.toolCalls)
        {
          'id': tc.id,
          'name': tc.name,
          'arguments': jsonEncode(tc.arguments),
        }
    ]));

    for (final tc in result.toolCalls) {
      String toolResult;
      try {
        toolResult = await AgentTools.execute(
          name: tc.name,
          args: tc.arguments,
          ctx: ctx,
          onMotionScene: (prompt) async {
            final scene = await AiFacade.generateMotionScene(
              s: settings,
              prompt: prompt,
              videoDuration: project.totalDuration,
              language: settings.locale,
            );
            ctrl.applyMotionSceneJson(jsonEncode(scene));
            return MotionScene.fromJson(scene);
          },
          onSuggestCaptions: (instruction) async {
            final segs = await AiFacade.polishCaptions(
              settings: settings,
              captions: project.captions,
              mode: 'hashtags',
              lang: settings.locale,
            );
            ctrl.setAllCaptions(segs);
            return segs;
          },
        );

        // Structured payloads → friendly summaries
        if (toolResult.startsWith('MOTION_SCENE_JSON:')) {
          toolResult = 'Motion scene generated and attached to the project.';
        } else if (toolResult.startsWith('CAPTIONS_JSON:')) {
          toolResult = 'Captions rewritten (${project.captions.length} lines).';
        }
      } catch (e) {
        toolResult = 'Tool error: $e';
      }

      onTool(tc.name, _shorten(toolResult));
      messages.add(ChatMessage(role: 'tool', content: toolResult, toolCallId: tc.id));
    }
  }
  return 'Done (max tool hops reached).';
}

String _shorten(String s) => s.length > 140 ? '${s.substring(0, 140)}…' : s;
