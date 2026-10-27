import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/motion_scene.dart';

/// Renders a MotionScene JSON on top of the video at the given playhead.
/// Pure Flutter animations — identical DSL the AI generates.
class MotionEngine extends StatelessWidget {
  final String? motionSceneJson;
  final double t; // playhead seconds
  final double videoHeightPx;

  const MotionEngine({super.key, required this.motionSceneJson, required this.t, required this.videoHeightPx});

  @override
  Widget build(BuildContext context) {
    if (motionSceneJson == null || motionSceneJson!.isEmpty) return const SizedBox.shrink();
    MotionScene scene;
    try {
      scene = MotionScene.fromJson(jsonDecode(motionSceneJson!) as Map<String, dynamic>);
    } catch (_) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: Stack(
        children: [
          for (final e in scene.elements)
            if (t >= e.start && t <= e.end)
              _MotionElementView(element: e, local: t - e.start, videoHeightPx: videoHeightPx),
        ],
      ),
    );
  }
}

class _MotionElementView extends StatelessWidget {
  final MotionElement element;
  final double local;
  final double videoHeightPx;

  const _MotionElementView({required this.element, required this.local, required this.videoHeightPx});

  @override
  Widget build(BuildContext context) {
    final anim = _Animated(element: element, local: local, videoHeightPx: videoHeightPx, child: _content());
    return Positioned(
      left: 0, right: 0, top: 0, bottom: 0,
      child: Align(
        alignment: Alignment(element.x * 2 - 1, element.y * 2 - 1),
        child: anim,
      ),
    );
  }

  Widget _content() {
    switch (element.type) {
      case 'emoji':
        return Transform.scale(
          scale: element.fontSizePct / 7,
          child: Text(element.emoji, style: TextStyle(fontSize: videoHeightPx * 0.08)),
        );
      case 'shape':
        return _shape();
      default:
        return _text();
    }
  }

  Widget _text() {
    final fontSize = videoHeightPx * element.fontSizePct / 100;
    final gf = switch (element.font) {
      'Anton' => GoogleFonts.anton,
      'BebasNeue' => GoogleFonts.bebasNeue,
      'Lalezar' => GoogleFonts.lalezar,
      'Almarai' => GoogleFonts.almarai,
      _ => GoogleFonts.tajawal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: element.accent.withOpacity(.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        element.text,
        textAlign: TextAlign.center,
        style: gf(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: element.color,
          shadows: [
            Shadow(color: element.accent.withOpacity(.9), blurRadius: 24),
            const Shadow(color: Colors.black54, blurRadius: 8),
          ],
        ),
      ),
    );
  }

  Widget _shape() {
    final w = videoHeightPx * (element.shape == 'underline' ? 0.30 : 0.42);
    final h = videoHeightPx * (element.shape == 'underline' ? 0.012 : element.shape == 'pill' ? 0.10 : 0.014);
    final radius = switch (element.shape) {
      'pill' => h / 2,
      'circle' => w / 2,
      _ => 6.0,
    };
    return Container(
      width: element.shape == 'circle' ? h : w,
      height: h,
      decoration: BoxDecoration(
        color: element.accent.withOpacity(.92),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [BoxShadow(color: element.accent.withOpacity(.55), blurRadius: 28)],
      ),
    );
  }
}

class _Animated extends StatefulWidget {
  final MotionElement element;
  final double local;
  final double videoHeightPx;
  final Widget child;
  const _Animated({required this.element, required this.local, required this.videoHeightPx, required this.child});

  @override
  State<_Animated> createState() => _AnimatedState();
}

class _AnimatedState extends State<_Animated> with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.element.loop || widget.element.anim == 'pulse' || widget.element.anim == 'shake') {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget w = widget.child;
    final d = widget.local;
    switch (widget.element.anim) {
      case 'popIn':
        final p = (d / 0.35).clamp(0.0, 1.0);
        final ease = Curves.elasticOut.transform(p);
        w = Transform.scale(scale: 0.4 + 0.6 * ease, child: Opacity(opacity: p.clamp(0, 1), child: w));
        break;
      case 'fadeIn':
        w = Opacity(opacity: (d / 0.4).clamp(0.0, 1.0), child: w);
        break;
      case 'slideUp':
        final p = (d / 0.4).clamp(0.0, 1.0);
        w = Transform.translate(
            offset: Offset(0, (1 - Curves.easeOutCubic.transform(p)) * widget.videoHeightPx * 0.12),
            child: Opacity(opacity: p, child: w));
        break;
      case 'slideDown':
        final p = (d / 0.4).clamp(0.0, 1.0);
        w = Transform.translate(
            offset: Offset(0, -(1 - Curves.easeOutCubic.transform(p)) * widget.videoHeightPx * 0.12),
            child: Opacity(opacity: p, child: w));
        break;
      case 'typewriter':
        final text = widget.child is Text ? (widget.child as Text).data ?? '' : '';
        if (text.isNotEmpty) {
          final chars = (d * 18).floor().clamp(0, text.length);
          w = Text(text.substring(0, chars), style: (widget.child as Text).style);
        }
        break;
      case 'pulse':
        return AnimatedBuilder(
          animation: _loop,
          builder: (_, child) {
            final s = 1.0 + 0.08 * math.sin(_loop.value * 2 * math.pi);
            return Transform.scale(scale: s, child: child);
          },
          child: w,
        );
      case 'shake':
        return AnimatedBuilder(
          animation: _loop,
          builder: (_, child) {
            final dx = 4 * math.sin(_loop.value * 6 * math.pi);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: w,
        );
      case 'wipe':
        w = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: (d / 0.5).clamp(0.05, 1.0),
            child: w,
          ),
        );
        break;
    }
    // Exit fade in last 0.3s
    final remaining = widget.element.end - widget.element.start - d;
    if (remaining < 0.3) {
      w = Opacity(opacity: (remaining / 0.3).clamp(0.0, 1.0), child: w);
    }
    return w;
  }
}
