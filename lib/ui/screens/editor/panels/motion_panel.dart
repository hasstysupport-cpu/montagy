import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/ai/ai_facade.dart';
import '../../../../services/motion/templates.dart';
import '../../../../state/editor_controller.dart';
import '../../../../state/settings_provider.dart';

/// Motion graphics: bundled templates + AI generation (same JSON DSL).
class MotionPanel extends ConsumerStatefulWidget {
  const MotionPanel({super.key});

  @override
  ConsumerState<MotionPanel> createState() => _MotionPanelState();
}

class _MotionPanelState extends ConsumerState<MotionPanel> {
  final _promptCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final hasScene = (st.motionSceneJson ?? '').isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('motion_graphics'),
              style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          // AI generator
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _promptCtrl,
                  maxLines: 2,
                  style: GoogleFonts.cairo(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: context.tr('motion_prompt_hint'),
                    hintStyle: GoogleFonts.cairo(fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _busy ? null : () => _generate(ctrl),
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(context.tr('generate'), style: GoogleFonts.cairo(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasScene)
            Row(
              children: [
                Icon(Icons.check_circle, size: 15, color: AppColors.success),
                const SizedBox(width: 5),
                Expanded(
                  child: Text('${context.tr('apply')} ✓',
                      style: GoogleFonts.cairo(fontSize: 12, color: AppColors.success)),
                ),
                TextButton(
                  onPressed: () => ctrl.applyMotionSceneJson(''),
                  child: Text(context.tr('remove'), style: GoogleFonts.cairo(fontSize: 12)),
                ),
              ],
            ),
          const SizedBox(height: 4),
          Text(context.tr('motion_templates'),
              style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: MotionTemplates.all.length,
              itemBuilder: (context, i) {
                final tpl = MotionTemplates.all[i];
                return GestureDetector(
                  onTap: () => ctrl.applyMotionSceneJson(jsonEncode(tpl.toJson())),
                  child: Container(
                    width: 130,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(_tplIcon(tpl.name), color: AppColors.accent, size: 26),
                        const Spacer(),
                        Text(_tplName(tpl.name),
                            style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700)),
                        Text('${tpl.elements.length} layers',
                            style: GoogleFonts.cairo(fontSize: 10, color: AppColors.textDim)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate(EditorController ctrl) async {
    final s = ref.read(settingsProvider);
    if (!AiFacade.hasTextModel(s)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.tr('ai_settings_hint'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final st = ref.read(editorProvider);
      final scene = await AiFacade.generateMotionScene(
        s: s,
        prompt: _promptCtrl.text,
        videoDuration: st.project.totalDuration,
        language: s.locale,
      );
      ctrl.applyMotionSceneJson(jsonEncode(scene));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  IconData _tplIcon(String name) => switch (name) {
        'intro_glow' => Icons.wb_incandescent_outlined,
        'subscribe_cta' => Icons.subscriptions_outlined,
        'lower_third' => Icons.subtitles_outlined,
        'countdown' => Icons.timer_outlined,
        'promo_shake' => Icons.local_offer_outlined,
        _ => Icons.animation,
      };

  String _tplName(String name) => switch (name) {
        'intro_glow' => 'مقدمة متوهجة',
        'subscribe_cta' => 'زرار اشتراك',
        'lower_third' => 'اسم المتحدث',
        'countdown' => 'عد تنازلي',
        'promo_shake' => 'عرض ترويجي',
        _ => name,
      };
}
