import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/overlay_item.dart';
import '../../../../state/editor_controller.dart';

const _emojiSets = [
  ['🔥', '😂', '😍', '🥳', '👀', '💯', '👍', '🔔', '❤️', '✨', '🚀', '🤯', '🎬', '🎯', '⚡', '💡'],
];

/// Add & edit text overlays / emoji stickers (drag in preview to position).
class TextStickerPanel extends ConsumerStatefulWidget {
  final String mode; // 'text' | 'stickers'
  const TextStickerPanel({super.key, required this.mode});

  @override
  ConsumerState<TextStickerPanel> createState() => _TextStickerPanelState();
}

class _TextStickerPanelState extends ConsumerState<TextStickerPanel> {
  final _textCtrl = TextEditingController();
  double _fontSize = 7;
  Color _color = Colors.white;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(editorProvider);
    final ctrl = ref.read(editorProvider.notifier);
    final sel = st.selectedOverlayId;
    final selItem = sel == null ? null : st.project.overlays.where((o) => o.id == sel).firstOrNull;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.mode == 'text' ? context.tr('add_text') : context.tr('stickers'),
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 10),
          if (widget.mode == 'text') ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: InputDecoration(hintText: context.tr('caption_text')),
                    style: GoogleFonts.cairo(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _addText(ctrl),
                  child: Text('+ ${context.tr('add_text')}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('${context.tr('size')}: ${_fontSize.toStringAsFixed(0)}',
                    style: GoogleFonts.cairo(fontSize: 12)),
                Expanded(
                  child: Slider(
                    value: _fontSize, min: 3, max: 14,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
                for (final c in [Colors.white, AppColors.accent, AppColors.accent2, AppColors.warning, AppColors.success])
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 24, height: 24, margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                          border: _color == c ? Border.all(color: Colors.white, width: 2) : null),
                    ),
                  ),
              ],
            ),
          ] else ...[
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final e in _emojiSets.expand((x) => x))
                    GestureDetector(
                      onTap: () => _addEmoji(ctrl, e),
                      child: Container(
                        width: 52, height: 52, margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surface2, borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: st.project.overlays.isEmpty
                ? Center(
                    child: Text('⬆ ${context.tr('add_text')}',
                        style: GoogleFonts.cairo(color: AppColors.textDim, fontSize: 12)))
                : ListView.builder(
                    itemCount: st.project.overlays.length,
                    itemBuilder: (context, i) {
                      final o = st.project.overlays[i];
                      final active = o.id == sel;
                      return ListTile(
                        dense: true,
                        onTap: () => ctrl.selectOverlay(active ? null : o.id),
                        leading: Icon(o.isEmoji ? Icons.emoji_emotions : Icons.text_fields,
                            color: active ? AppColors.accent : AppColors.textDim, size: 20),
                        title: Text(o.text, maxLines: 1, style: GoogleFonts.cairo(fontSize: 13)),
                        subtitle: Text(
                          '${_fmt(o.start)} → ${_fmt(o.end)}',
                          style: GoogleFonts.cairo(fontSize: 10, color: AppColors.accent),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (active && selItem != null) ...[
                              _iconBtn(Icons.timer, () => _editTiming(ctrl, selItem!)),
                              _iconBtn(Icons.delete_outline, () => ctrl.deleteOverlay(o.id)),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: AppColors.textDim),
        ),
      );

  void _addText(EditorController ctrl) {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final st = ref.read(editorProvider);
    ctrl.addOverlay(OverlayItem(
      id: const Uuid().v4(),
      text: text,
      start: st.playhead,
      end: (st.playhead + 3).clamp(0, st.project.totalDuration),
      fontSizePct: _fontSize,
      color: _color,
    ));
    _textCtrl.clear();
  }

  void _addEmoji(EditorController ctrl, String emoji) {
    final st = ref.read(editorProvider);
    ctrl.addOverlay(OverlayItem(
      id: const Uuid().v4(),
      text: emoji,
      isEmoji: true,
      start: st.playhead,
      end: (st.playhead + 2.5).clamp(0, st.project.totalDuration),
      fontSizePct: 8,
    ));
  }

  Future<void> _editTiming(EditorController ctrl, OverlayItem o) async {
    final startCtrl = TextEditingController(text: o.start.toStringAsFixed(1));
    final endCtrl = TextEditingController(text: o.end.toStringAsFixed(1));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('duration')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: startCtrl, decoration: InputDecoration(labelText: context.tr('start_time'))),
            TextField(controller: endCtrl, decoration: InputDecoration(labelText: context.tr('end_time'))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('ok'))),
        ],
      ),
    );
    if (ok == true) {
      ctrl.updateOverlay(o.id, (x) {
        x.start = double.tryParse(startCtrl.text) ?? x.start;
        x.end = double.tryParse(endCtrl.text) ?? x.end;
      });
    }
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).floor().toString().padLeft(2, '0');
    return '$m:$sec';
  }
}

extension _First<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
