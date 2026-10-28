/// كتالوج خطوط أداة النص — عربي فاخر + لاتيني.
class FontEntry {
  final String family;      // الاسم المسجل في pubspec
  final String label;       // الاسم المعروض
  final bool arabic;
  final double defaultWeight; // وزن الخط المتغير إن وجد (وإلا 400)
  const FontEntry(this.family, this.label, this.arabic, {this.defaultWeight = 400});
}

class FontCatalog {
  static const List<FontEntry> all = [
    FontEntry('Alexandria', 'الإسكندرية', true, defaultWeight: 700),
    FontEntry('IBMPlexSansArabic', 'بليكس عربي', true),
    FontEntry('Cairo', 'القاهرة', true),
    FontEntry('Amiri', 'أميري', true),
    FontEntry('ReemKufi', 'ريم كوفي', true),
    FontEntry('ElMessiri', 'المسيري', true),
    FontEntry('Changa', 'شنغا', true),
    FontEntry('Lalezar', 'لاله زار', true),
    FontEntry('BalooBhaijaan2', 'بالو', true),
    FontEntry('ArefRuqaa', 'عارف رقعة', true),
    FontEntry('Marhey', 'مرحى', true),
    FontEntry('Rubik', 'روبيك', true),
    FontEntry('PlayfairDisplay', 'بلايفير', false),
    FontEntry('BebasNeue', 'بيباس', false),
    FontEntry('Pacifico', 'باسيفيكو', false),
  ];

  static FontEntry byFamily(String family) => all.firstWhere(
        (f) => f.family == family,
        orElse: () => all.first,
  );

  /// الخطوط ذات الملف الثابت (غير متغيرة الوزن)
  static const Set<String> staticFonts = {
    'Amiri', 'Lalezar', 'ArefRuqaa', 'IBMPlexSansArabic',
    'BebasNeue', 'Pacifico',
  };
}

/// تصنيفات الإيموجي للملصقات.
class EmojiCatalog {
  static const Map<String, List<String>> categories = {
    ' وجوه ': [
      '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
      '😉', '😊', '😍', '🥰', '😘', '😗', '😎', '🤩', '🥳', '😏',
      '😴', '🤤', '😪', '😵', '🤯', '🥶', '😳', '🥵', '😭', '😢',
      '😤', '😡', '🤬', '😱', '😨', '🤗', '🤔', '🤭', '🤫', '😶',
    ],
    ' إيماءات ': [
      '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '👏', '🙌', '🤝',
      '🙏', '💪', '🖐️', '✋', '🤙', '👊', '🫶', '👋', '🫡', '🤌',
      '👆', '👇', '👉', '👈', '☝️', '✍️', '💅', '🦾', '👀', '🧠',
    ],
    ' قلوب ': [
      '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
      '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '♥️',
    ],
    ' حيوانات ': [
      '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
      '🦁', '🐮', '🐷', '🐸', '🐵', '🦄', '🐝', '🦋', '🐢', '🐬',
    ],
    ' طعام ': [
      '🍎', '🍊', '🍋', '🍉', '🍇', '🍓', '🍑', '🥭', '🍍', '🥑',
      '🍔', '🍕', '🌮', '🌯', '🍟', '🍿', '🍩', '🍪', '🎂', '☕',
    ],
    ' رموز ': [
      '🔥', '⭐', '🌟', '✨', '💫', '⚡', '💥', '💯', '🎉', '🎊',
      '🎵', '🎶', '📸', '🎬', '💡', '📌', '🏆', '👑', '💎', '🚀',
      '✅', '❌', '❓', '❗', '💤', '🌈', '☀️', '🌙', '⛅', '❄️',
    ],
  };
}
