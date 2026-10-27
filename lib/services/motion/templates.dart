import '../../models/motion_scene.dart';

/// Bundled motion templates — Flutter-native (no external deps), AI can also
/// generate new scenes with the same DSL.
class MotionTemplates {
  MotionTemplates._();

  static const introGlow = MotionScene(name: 'intro_glow', elements: [
    MotionElement(
      type: 'text', text: 'اهلا بيك ✨', start: 0, end: 2.6,
      x: 0.5, y: 0.42, fontSizePct: 10, anim: 'popIn', accent: Color(0xFF8B5CF6),
    ),
    MotionElement(
      type: 'shape', shape: 'underline', start: 0.5, end: 2.6,
      x: 0.5, y: 0.5, anim: 'wipe', accent: Color(0xFF22D3EE),
    ),
  ]);

  static const subscribeCta = MotionScene(name: 'subscribe_cta', elements: [
    MotionElement(
      type: 'shape', shape: 'pill', start: 0, end: 4,
      x: 0.5, y: 0.88, anim: 'slideUp', accent: Color(0xFFEF4444),
    ),
    MotionElement(
      type: 'text', text: 'اشترك 🔔 وفعّل الجرس', start: 0.15, end: 4,
      x: 0.5, y: 0.88, fontSizePct: 5.5, anim: 'fadeIn', color: Color(0xFFFFFFFF),
    ),
    MotionElement(
      type: 'emoji', emoji: '👍', start: 0.6, end: 4, x: 0.86, y: 0.88,
      fontSizePct: 6, anim: 'pulse',
    ),
  ]);

  static const lowerThird = MotionScene(name: 'lower_third', elements: [
    MotionElement(
      type: 'shape', shape: 'rect', start: 0, end: 5,
      x: 0.06, y: 0.82, anim: 'slideUp', accent: Color(0xFF8B5CF6),
    ),
    MotionElement(
      type: 'text', text: 'اسم المتحدث', start: 0.3, end: 5,
      x: 0.1, y: 0.82, fontSizePct: 4.5, anim: 'fadeIn',
    ),
  ]);

  static const countdown = MotionScene(name: 'countdown', elements: [
    MotionElement(
      type: 'text', text: '3', start: 0, end: 1, x: 0.5, y: 0.45,
      fontSizePct: 16, anim: 'popIn', accent: Color(0xFFF472B6),
    ),
    MotionElement(
      type: 'text', text: '2', start: 1, end: 2, x: 0.5, y: 0.45,
      fontSizePct: 16, anim: 'popIn', accent: Color(0xFF22D3EE),
    ),
    MotionElement(
      type: 'text', text: '1', start: 2, end: 3, x: 0.5, y: 0.45,
      fontSizePct: 16, anim: 'popIn', accent: Color(0xFFFBBF24),
    ),
    MotionElement(
      type: 'text', text: 'يلا نبدأ! 🚀', start: 3, end: 5, x: 0.5, y: 0.45,
      fontSizePct: 10, anim: 'popIn',
    ),
  ]);

  static const promoShake = MotionScene(name: 'promo_shake', elements: [
    MotionElement(
      type: 'text', text: 'خصم 50% 🔥', start: 0, end: 4, x: 0.5, y: 0.3,
      fontSizePct: 11, anim: 'shake', accent: Color(0xFFFDE047), color: Color(0xFFEF4444),
    ),
    MotionElement(
      type: 'text', text: 'لأول 100 فقط', start: 0.4, end: 4, x: 0.5, y: 0.42,
      fontSizePct: 5.5, anim: 'pulse',
    ),
  ]);

  static const List<MotionScene> all = [
    introGlow, subscribeCta, lowerThird, countdown, promoShake,
  ];
}
