import '../../models/caption.dart';
import '../../models/filter.dart';
import '../../models/motion_scene.dart';
import '../../models/overlay_item.dart';
import '../../models/project.dart';
import '../../models/transition.dart';
import '../ai/web_search_service.dart';
import '../../state/settings_provider.dart';

/// What the agent can DO to the current project — OpenAI function-calling tools.
/// Each tool returns a short result string fed back to the model.
class AgentContext {
  final VideoProject project;
  final AppSettings settings;
  AgentContext(this.project, this.settings);
}

class AgentTools {
  /// OpenAI tool schemas.
  static List<Map<String, dynamic>> schemas() => [
        {
          'name': 'web_search',
          'description': 'Search the internet for facts, trends, hashtags or ideas.',
          'parameters': {
            'type': 'object',
            'properties': {'query': {'type': 'string'}},
            'required': ['query'],
          },
        },
        {
          'name': 'get_project_info',
          'description': 'Get current project info: duration, clips, captions count, style.',
          'parameters': {'type': 'object', 'properties': {}},
        },
        {
          'name': 'set_caption_style',
          'description': 'Set the project caption style.',
          'parameters': {
            'type': 'object',
            'properties': {
              'style_id': {
                'type': 'string',
                'enum': ['tiktok_karaoke', 'youtube_classic', 'neon', 'box', 'pop',
                         'typewriter', 'gradient', 'outline', 'gaming', 'podcast', 'wave', 'minimal'],
              }
            },
            'required': ['style_id'],
          },
        },
        {
          'name': 'apply_filter',
          'description': 'Apply a look-up filter to ALL clips.',
          'parameters': {
            'type': 'object',
            'properties': {
              'filter_id': {
                'type': 'string',
                'enum': ['original', 'vivid', 'cinematic', 'bw', 'vintage',
                         'cool', 'warm', 'fade', 'noir', 'neondream'],
              },
              'intensity': {'type': 'number', 'description': '0..1'}
            },
            'required': ['filter_id'],
          },
        },
        {
          'name': 'add_transition',
          'description': 'Set transition between all consecutive clips.',
          'parameters': {
            'type': 'object',
            'properties': {
              'transition_id': {
                'type': 'string',
                'enum': ['', 'fade', 'dissolve', 'wipeleft', 'wiperight', 'slideleft',
                         'circleopen', 'pixelize', 'smoothleft', 'zoomin', 'hblur', 'radial'],
              }
            },
            'required': ['transition_id'],
          },
        },
        {
          'name': 'trim_video',
          'description': 'Keep only the given timeline range (seconds).',
          'parameters': {
            'type': 'object',
            'properties': {
              'start': {'type': 'number'},
              'end': {'type': 'number'},
            },
            'required': ['start', 'end'],
          },
        },
        {
          'name': 'set_speed',
          'description': 'Change playback speed of all clips (0.25..4).',
          'parameters': {
            'type': 'object',
            'properties': {'speed': {'type': 'number'}},
            'required': ['speed'],
          },
        },
        {
          'name': 'add_motion_scene',
          'description': 'Generate a motion-graphics scene from a description and attach it to the project.',
          'parameters': {
            'type': 'object',
            'properties': {
              'prompt': {'type': 'string'},
            },
            'required': ['prompt'],
          },
        },
        {
          'name': 'suggest_captions',
          'description': 'Suggest rewritten caption text for the current captions (no timing change).',
          'parameters': {
            'type': 'object',
            'properties': {
              'instruction': {'type': 'string'},
            },
            'required': ['instruction'],
          },
        },
        {
          'name': 'add_text_overlay',
          'description': 'Add a floating text overlay.',
          'parameters': {
            'type': 'object',
            'properties': {
              'text': {'type': 'string'},
              'start': {'type': 'number'},
              'end': {'type': 'number'},
              'x': {'type': 'number', 'description': '0..1'},
              'y': {'type': 'number', 'description': '0..1'},
            },
            'required': ['text'],
          },
        },
      ];

  /// Executes a tool call, mutates the project, returns a result string.
  static Future<String> execute({
    required String name,
    required Map<String, dynamic> args,
    required AgentContext ctx,
    required Future<MotionScene> Function(String prompt) onMotionScene,
    required Future<List<CaptionSegment>> Function(String instruction) onSuggestCaptions,
  }) async {
    final p = ctx.project;
    switch (name) {
      case 'web_search':
        return WebSearchService.search(
          args['query']?.toString() ?? '',
          tavilyKey: ctx.settings.tavilyKey,
        );

      case 'get_project_info':
        return 'Project "${p.name}": ${p.clips.length} clip(s), '
            'total ${p.totalDuration.toStringAsFixed(1)}s, '
            '${p.captions.length} captions, style=${p.captionStyleId}, '
            'filter=${p.clips.map((c) => c.filterId).toSet().join(',')}';

      case 'set_caption_style':
        p.captionStyleId = args['style_id']?.toString() ?? 'tiktok_karaoke';
        for (final c in p.captions) {
          c.styleId = p.captionStyleId;
        }
        return 'Caption style set to $p.captionStyleId for ${p.captions.length} captions.';

      case 'apply_filter':
        final id = args['filter_id']?.toString() ?? 'original';
        final intensity = ((args['intensity'] as num?)?.toDouble()) ?? 0.8;
        for (final c in p.clips) {
          c.filterId = Filters.byId(id).id;
          c.filterIntensity = intensity.clamp(0.0, 1.0);
        }
        return 'Filter $id applied to ${p.clips.length} clips.';

      case 'add_transition':
        final id = args['transition_id']?.toString() ?? '';
        for (final c in p.clips) {
          c.transitionToNext = TransitionSpec(id: id);
        }
        return id.isEmpty ? 'Transitions removed.' : 'Transition $id applied between clips.';

      case 'trim_video':
        final start = ((args['start'] as num?)?.toDouble()) ?? 0;
        final end = ((args['end'] as num?)?.toDouble()) ?? p.totalDuration;
        // Walk the timeline and translate to per-clip trims.
        var cursor = 0.0;
        for (final c in p.clips) {
          final clipLen = c.timelineLength;
          final clipStart = cursor;
          final clipEnd = cursor + clipLen;
          final keepStart = start.clamp(clipStart, clipEnd) - clipStart;
          final keepEnd = end.clamp(clipStart, clipEnd) - clipStart;
          if (keepStart > 0 || keepEnd < clipLen) {
            c.trimStart = c.trimStart + keepStart * c.speed;
            c.trimEnd = c.trimStart + (keepEnd - keepStart) * c.speed;
          }
          cursor = clipEnd;
        }
        return 'Trimmed timeline to $start..$end s.';

      case 'set_speed':
        final sp = ((args['speed'] as num?)?.toDouble() ?? 1.0).clamp(0.25, 4.0);
        for (final c in p.clips) {
          c.speed = sp.toDouble();
        }
        return 'Speed set to $sp for all clips.';

      case 'add_motion_scene':
        final scene = await onMotionScene(args['prompt']?.toString() ?? 'tasteful motion graphics');
        return 'MOTION_SCENE_JSON:${scene.toJson()}'; // handled by controller

      case 'suggest_captions':
        final segs = await onSuggestCaptions(args['instruction']?.toString() ?? 'improve wording');
        return 'CAPTIONS_JSON:${segs.map((s) => s.toJson()).toList()}'; // handled by controller

      case 'add_text_overlay':
        final uuidT = DateTime.now().microsecondsSinceEpoch.toString();
        p.overlays.add(OverlayItem(
          id: 'ov_$uuidT',
          text: args['text']?.toString() ?? 'نص',
          start: ((args['start'] as num?)?.toDouble()) ?? 0,
          end: ((args['end'] as num?)?.toDouble()) ?? 3,
          x: ((args['x'] as num?)?.toDouble()) ?? 0.5,
          y: ((args['y'] as num?)?.toDouble()) ?? 0.3,
        ));
        return 'Text overlay added: "${args['text']}"';

      default:
        return 'Unknown tool: $name';
    }
  }
}
