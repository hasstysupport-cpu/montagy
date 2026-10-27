import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/caption_style.dart';
import '../../../services/ai/openrouter_service.dart';
import '../../../state/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.tr('settings'), style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),

          // Language
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.language, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text(context.tr('language'), style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(value: 'ar', label: Text(context.tr('arabic'))),
                    ButtonSegment(value: 'en', label: Text(context.tr('english'))),
                  ],
                  selected: {s.locale},
                  onSelectionChanged: (v) =>
                      ref.read(settingsProvider.notifier).update((x) => x.copyWith(locale: v.first)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Default caption style
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.style_outlined, color: AppColors.accent2),
                  const SizedBox(width: 8),
                  Text(context.tr('default_caption_style'),
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    for (final st in CaptionStylePresets.all)
                      ChoiceChip(
                        label: Text(context.tr('style_${st.id}')),
                        selected: s.defaultCaptionStyleId == st.id,
                        onSelected: (_) => ref
                            .read(settingsProvider.notifier)
                            .update((x) => x.copyWith(defaultCaptionStyleId: st.id)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // AI providers
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.key_outlined, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.tr('ai_settings'),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(context.tr('ai_settings_hint'),
                    style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textDim)),
                const SizedBox(height: 14),
                _keyField(
                  context, ref,
                  label: context.tr('openrouter_key'),
                  hint: 'sk-or-v1-...',
                  value: s.openrouterKey,
                  link: 'https://openrouter.ai/keys',
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).update((x) => x.copyWith(openrouterKey: v)),
                ),
                const SizedBox(height: 12),
                Text(context.tr('openrouter_model'), style: GoogleFonts.cairo(fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: OpenRouterService.freeModels.contains(s.openrouterModel)
                      ? s.openrouterModel
                      : OpenRouterService.freeModels.first,
                  items: [
                    for (final m in OpenRouterService.freeModels)
                      DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) =>
                      ref.read(settingsProvider.notifier).update((x) => x.copyWith(openrouterModel: v ?? '')),
                ),
                const SizedBox(height: 14),
                _keyField(
                  context, ref,
                  label: context.tr('groq_key'),
                  hint: 'gsk_...',
                  value: s.groqKey,
                  link: 'https://console.groq.com/keys',
                  onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(groqKey: v)),
                ),
                const SizedBox(height: 12),
                _keyField(
                  context, ref,
                  label: context.tr('gemini_key'),
                  hint: 'AIza...',
                  value: s.geminiKey,
                  link: 'https://aistudio.google.com/app/apikey',
                  onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(geminiKey: v)),
                ),
                const SizedBox(height: 12),
                _keyField(
                  context, ref,
                  label: context.tr('search_api_key'),
                  hint: 'tvly-...',
                  value: s.tavilyKey,
                  link: 'https://tavily.com',
                  onChanged: (v) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(tavilyKey: v)),
                ),
                const SizedBox(height: 16),
                _TestConnectionButton(settings: s),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // About
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.favorite_outline, color: AppColors.accent2),
                  const SizedBox(width: 8),
                  Text(context.tr('about'), style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
                const SizedBox(height: 10),
                Text(context.tr('about_text'),
                    style: GoogleFonts.cairo(fontSize: 12.5, color: AppColors.textDim, height: 1.7)),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _keyField(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required String hint,
    required String value,
    required String link,
    required ValueChanged<String> onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: GoogleFonts.cairo(fontSize: 13))),
              GestureDetector(
                onTap: () => _launch(link),
                child: Text(context.tr('get_free_key'),
                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            obscureText: true,
            controller: TextEditingController(text: value),
            decoration: InputDecoration(hintText: hint),
            onChanged: onChanged,
          ),
        ],
      );

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    // ignore: deprecated_member_use
    await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  }
}

class _TestConnectionButton extends StatefulWidget {
  final AppSettings settings;
  const _TestConnectionButton({required this.settings});
  @override
  State<_TestConnectionButton> createState() => _TestConnectionButtonState();
}

class _TestConnectionButtonState extends State<_TestConnectionButton> {
  String _state = ''; // '', 'busy', 'ok', 'fail'
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _state == 'busy' ? null : _test,
      icon: Icon(
        switch (_state) { 'ok' => Icons.check_circle, 'fail' => Icons.error_outline, _ => Icons.wifi_tethering },
        color: switch (_state) { 'ok' => AppColors.success, 'fail' => AppColors.danger, _ => null },
      ),
      label: Text(switch (_state) {
        'busy' => context.tr('loading'),
        'ok' => context.tr('connection_ok'),
        'fail' => context.tr('connection_failed'),
        _ => context.tr('test_connection'),
      }),
    );
  }

  Future<void> _test() async {
    setState(() => _state = 'busy');
    try {
      final r = await OpenRouterService.chat(
        apiKey: widget.settings.openrouterKey.trim(),
        model: widget.settings.openrouterModel,
        messages: const [ChatMessage(role: 'user', content: 'ping')],
        maxTokens: 8,
      );
      setState(() => _state = r.content.isNotEmpty ? 'ok' : 'fail');
    } catch (_) {
      setState(() => _state = 'fail');
    }
  }
}
