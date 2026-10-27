import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/ai/ai_facade.dart';
import '../../../services/storage_service.dart';
import '../../../state/settings_provider.dart';
import 'editor/editor_screen.dart';

/// AI Studio tab: project picker → auto captions / motion / agent entry.
class AiStudioScreen extends ConsumerStatefulWidget {
  const AiStudioScreen({super.key});

  @override
  ConsumerState<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends ConsumerState<AiStudioScreen> {
  String? _projectId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    return SafeArea(
      child: FutureBuilder(
        future: StorageService.instance.listProjects(),
        builder: (context, snap) {
          final projects = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.tr('ai_studio'),
                  style: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(context.tr('tagline'),
                  style: GoogleFonts.cairo(fontSize: 12.5, color: AppColors.textDim)),
              const SizedBox(height: 18),

              // Provider status
              Row(
                children: [
                  _statusDot(AiFacade.hasTextModel(settings)),
                  const SizedBox(width: 6),
                  Text('OpenRouter', style: GoogleFonts.cairo(fontSize: 12)),
                  const SizedBox(width: 14),
                  _statusDot(settings.groqKey.isNotEmpty || settings.geminiKey.isNotEmpty),
                  const SizedBox(width: 6),
                  Text('Speech-to-Text', style: GoogleFonts.cairo(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 18),

              // Project selector
              Text(context.tr('select_project_first'),
                  style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in projects)
                    ChoiceChip(
                      label: Text(p.name),
                      selected: _projectId == p.id,
                      onSelected: (_) => setState(() => _projectId = p.id),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Actions
              _action(
                context,
                icon: Icons.closed_caption,
                color: AppColors.accent2,
                title: context.tr('ai_caption_tab'),
                desc: 'Groq Whisper / Gemini — صوت لنص بستايلات جاهزة',
                onTap: _projectId == null ? null : () => _openProject(),
              ),
              _action(
                context,
                icon: Icons.animation,
                color: AppColors.primary,
                title: context.tr('ai_motion_tab'),
                desc: 'اوصف الحركة والـ AI يعملها JSON على الفيديو',
                onTap: _projectId == null ? null : () => _openProject(),
              ),
              _action(
                context,
                icon: Icons.smart_toy_outlined,
                color: AppColors.accent,
                title: context.tr('ai_agent'),
                desc: 'وكيل ينفذ أوامرك: بحث، تعديلات، كابتشن، موشن',
                onTap: _projectId == null ? null : () => _openProject(),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _statusDot(bool ok) => Container(
        width: 9, height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ok ? AppColors.success : AppColors.textDim,
        ),
      );

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
    required VoidCallback? onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(desc, style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textDim)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textDim),
            ],
          ),
        ),
      );

  Future<void> _openProject() async {
    setState(() => _busy = true);
    final projects = await StorageService.instance.listProjects();
    if (!mounted) return;
    setState(() => _busy = false);
    final p = projects.where((x) => x.id == _projectId).firstOrNull;
    if (p == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(projectId: p.id)));
  }
}

extension _FirstA<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
