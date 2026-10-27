import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/ai/ai_facade.dart';
import '../../../../services/ai/agent_loop.dart';
import '../../../../state/editor_controller.dart';
import '../../../../state/settings_provider.dart';

/// In-editor AI assistant — opens the full agent chat as a bottom sheet
/// with quick actions.
void showAiAssistantSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.82,
      child: const AiAgentChat(),
    ),
  );
}

class AiAgentChat extends ConsumerStatefulWidget {
  const AiAgentChat({super.key});

  @override
  ConsumerState<AiAgentChat> createState() => _AiAgentChatState();
}

class _AiAgentChatState extends State<AiAgentChat> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quick = [
      ('🎬', 'اعمل كابتشن تلقائي بستايل تيك توك', 'Run auto-captions with TikTok karaoke style on this project.'),
      ('✨', 'ضيف انتقالات وفيلاتر سينمائية', 'Apply cinematic filter with intensity 0.8 and set zoomin transitions between all clips.'),
      ('📝', 'حسّن نص الكابتشن وخلّيه جذاب', 'Suggest improved caption text: make it punchy and engaging while keeping meaning.'),
      ('🤔', 'دوّرلي على ترندات الريلز', 'web_search: latest instagram reels trends 2026 short video hooks'),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30, height: 30,
              decoration: const BoxDecoration(gradient: AppColors.gradHot, shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(context.tr('ai_agent'), style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      for (final q in quick)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            onTap: () => _send(q.$3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            leading: Text(q.$1, style: const TextStyle(fontSize: 22)),
                            title: Text(q.$2, style: GoogleFonts.cairo(fontSize: 13.5)),
                          ),
                        ),
                    ],
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      return _bubble(m);
                    },
                  ),
          ),
          if (_busy)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(context.tr('thinking'), style: GoogleFonts.cairo(fontSize: 12)),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      style: GoogleFonts.cairo(fontSize: 13),
                      decoration: InputDecoration(hintText: context.tr('agent_hint')),
                      onSubmitted: (_) => _send(_ctrl.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : () => _send(_ctrl.text),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary.withOpacity(.25) : AppColors.surface2,
          borderRadius: BorderRadiusDirectional.only(
            topStart: const Radius.circular(16),
            topEnd: const Radius.circular(16),
            bottomStart: Radius.circular(isUser ? 16 : 4),
            bottomEnd: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.toolName != null)
              Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${context.tr('tool_used')}: ${m.toolName}',
                    style: GoogleFonts.cairo(fontSize: 9.5, color: AppColors.accent)),
              ),
            Text(m.text, style: GoogleFonts.cairo(fontSize: 12.5, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _send(String text) async {
    text = text.trim();
    if (text.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_Msg(role: 'user', text: text));
      _busy = true;
    });
    _scrollDown();

    final st = ref.read(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    // Local quick-action: auto captions
    if (text.toLowerCase().contains('auto-caption') || text.toLowerCase().contains('كابتشن تلقائي')) {
      try {
        final segs = await _runAutoCaptions();
        ctrl.setAllCaptions(segs);
        _add('assistant', 'تم! ضفت ${segs.length} كابتشن بستايل ${st.project.captionStyleId} 🎉');
      } catch (e) {
        _add('assistant', 'مشكلة في التحويل الصوتي: اتأكد من الإعدادات إن عندك مفتاح Groq أو Gemini.');
      }
      setState(() => _busy = false);
      return;
    }

    // Otherwise → full agent loop
    try {
      final reply = await runAgentLoop(
        ref: ref,
        userText: text,
        onTool: (name, result) {
          _add('assistant', result, toolName: name);
        },
      );
      _add('assistant', reply.isEmpty ? context.tr('agent_done') : reply);
    } catch (e) {
      _add('assistant', '⚠️ ${context.tr('error_generic')}');
    } finally {
      setState(() => _busy = false);
    }
  }

  void _add(String role, String text, {String? toolName}) {
    setState(() => _messages.add(_Msg(role: role, text: text, toolName: toolName)));
    _scrollDown();
  }

  Future<List<dynamic>> _runAutoCaptions() async {
    final st = ref.read(editorProvider);
    final settings = ref.read(settingsProvider);
    final clip = st.project.clips.first;
    final segs = await AiFacade.autoCaptions(
      settings: settings,
      videoPath: clip.path,
      styleId: st.project.captionStyleId,
      language: settings.locale == 'ar' ? 'ar' : '',
    );
    return segs;
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }
}

class _Msg {
  final String role;
  final String text;
  final String? toolName;
  const _Msg({required this.role, required this.text, this.toolName});
}
