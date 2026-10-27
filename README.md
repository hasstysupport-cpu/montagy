# مونتاجي — Montagy 🎬

**استوديو مونتاج وكابتشن مفتوح المصدر** — تطبيق Flutter لأندرويد (و iOS) مستوحى من CapCut و VEED و OpenCut.

> بدون علامة مائية • بدون تسجيل دخول • مفاتيح AI بتاعتك محفوظة على جهازك بس

---

## ✨ الميزات

| الميزة | التفاصيل |
|---|---|
| 🎥 **مونتاج كامل** | قص، تقسيم عند الـ playhead، حذف كليبات، إضافة كليبات، كتم صوت، مستوى الصوت |
| ⚡ **سرعة** | من 0.25x لـ 4x (Slow-mo و Fast) بصوت متزامن |
| 🎨 **10 فيلاتر** | سينمائي، زايق، نوار، فينتاج، بارد/دافي، حلم نيون... بشدة قابلة للتحكم |
| 🔄 **11 انتقال xfade** | fade, dissolve, zoom, pixelize, circle, wipe... |
| 📝 **كابتشن بـ 12 ستايل** | كاريوكي تيك توك (كلمة كلمة)، نيون متوهج، بوكس ملون، كلاسيك يوتيوب، بوب، آلة كاتبة، جيمنج... |
| 🤖 **كابتشن تلقائي AI** | Groq Whisper (مجاني وسريع) أو Gemini — توقيتات كلمات للكاريوكي |
| 📄 **SRT** | استيراد وتصدير ملفات الترجمة |
| ✍️ **نصوص وستيكرز** | نصوص وإيموجي قابلة للسحب والتحجيم بتوقيت مخصص |
| 🎵 **صوت وموسيقى** | إضافة موسيقى خلفية + استخراج الصوت من الفيديو + Fade in/out |
| 🪄 **موشن جرافيك** | 5 قوالب جاهزة + توليد مشاهد بالـ AI (DSL خاص بيرندر في التطبيق) |
| 🧠 **Agent ذكي** | شات ينفذ أوامر على المشروع: بحث في الإنترنت، تعديلات، كابتشن، موشن |
| 🌐 **عربي/إنجليزي** | واجهة كاملة بالاتجاهين مع تبديل فوري |
| 📤 **تصدير** | 1080p/720p/480p + جودة عالية/متوسطة/خفيفة + حفظ في المعرض + مشاركة |

---

## 🚀 التشغيل خطوة بخطوة

### 1) المتطلبات
- [Flutter SDK 3.24+](https://docs.flutter.dev/get-started/install) (يحمل الدارت معه)
- Android Studio (لأندرويد SDK) — أو مجرد `flutter doctor` نضيف

### 2) جهّز المشروع (مرة واحدة فقط)

المشروع بيجي **من غير مجلدات android/ios** (عشان يفضل متوافق مع أي نسخة Flutter) — سكريبت التجهيز بيعملها لك:

**لينكس / ماك:**
```bash
cd montagy
chmod +x setup.sh
./setup.sh
```

**ويندوز:**
```bat
cd montagy
setup.bat
```

السكريبت بيعمل:
1. `flutter create .` — يولّد مجلدات المنصات
2. ينسخ باتش الأندرويد بتاعنا (أذونات، minSdk 24، FileProvider)
3. `flutter pub get`

### 3) شغّل

```bash
flutter run
```

### 4) اعمل APK

```bash
# APK عادي (يعمل على أي موبايل)
flutter build apk --release

# أو تقسيم حسب المعمارية (أصغر حجم)
flutter build apk --split-per-abi
```

الملف هيطلع في: `build/app/outputs/flutter-apk/app-release.apk`

---

## 🤖 إعداد الذكاء الاصطناعي (اختياري)

افتح **الإعدادات → مزودين الذكاء الاصطناعي** وحط أي مفتاح تحب:

| الخدمة | ليه؟ | منين المفتاح المجاني |
|---|---|---|
| **OpenRouter** | الشات + الـ Agent + تحسين/ترجمة النصوص + الموشن | [openrouter.ai/keys](https://openrouter.ai/keys) — الموديلات المجانية ليها `:free` |
| **Groq** | كابتشن تلقائي (صوت → نص) سرعة صاروخية | [console.groq.com/keys](https://console.groq.com/keys) |
| **Gemini** | بديل للكابتشن التلقائي | [aistudio.google.com](https://aistudio.google.com/app/apikey) |
| **Tavily** (اختياري) | بحث ويب أقوى للـ Agent | [tavily.com](https://tavily.com) — لو فاضي بنستخدم DuckDuckGo بدون مفتاح |

> 🔒 المفاتيح بتتخزن في `SharedPreferences` على جهازك **فقط** — مفيش أي سيرفر.

---

## 🏗️ بنية الكود

```
lib/
├── main.dart                  # bootstrap + settings
├── app.dart                   # MaterialApp + locale + theme
├── core/
│   ├── theme/app_theme.dart   # ثيم داكن زي CapCut (بنفسجي/سماوي نيون)
│   └── i18n/strings.dart      # ترجمة عربي/إنجليزي (165 مفتاح)
├── models/                    # project, caption, caption_style (12), filter (10),
│                              # transition (12), overlay_item, audio_track, motion_scene
├── services/
│   ├── ffmpeg_gateway.dart    # نقطة واحدة لاستيراد FFmpegKit (لو الفورك اتغير)
│   ├── ffmpeg_service.dart    # قص/سرعة/فيلاتر/xfade/مزج/حرق ASS/تصدير متدرج بالتقدم
│   ├── ass_service.dart       # ⭐ كابتشن → ASS (كاريوكي \k + نيون blur + بوكس)
│   ├── srt_service.dart       # SRT parse/export
│   ├── storage_service.dart   # مشاريع JSON محلية + media + thumbs
│   ├── motion/templates.dart  # 5 قوالب موشن جاهزة
│   └── ai/
│       ├── openrouter_service.dart    # chat + function calling (OpenAI-compatible)
│       ├── transcription_service.dart # Groq Whisper + Gemini audio
│       ├── ai_facade.dart             # auto-captions + polish + translate + motion JSON
│       ├── agent_tools.dart           # 10 أدوات الـ Agent (تعديل المشروع فعلياً)
│       ├── agent_loop.dart            # حلقة tool-calling (8 hops max)
│       └── web_search_service.dart    # DuckDuckGo (بدون مفتاح) + Tavily
├── state/
│   ├── settings_provider.dart # اللغة + المفاتيح (SharedPreferences)
│   └── editor_controller.dart # المشروع الحالي + playhead + undo/redo (25 snapshot)
└── ui/screens/
    ├── home_screen.dart           # معرض المشاريع
    ├── editor/
    │   ├── editor_screen.dart     # shell المحرر + toolbar
    │   ├── widgets/preview_canvas.dart  # فيديو + كابتشن + موشن + سحب الأوفرلايز
    │   ├── widgets/caption_renderer.dart # ⭐ رندر الـ 12 ستايل live (مطابق للحرق)
    │   ├── widgets/motion_engine.dart    # محرك الموشن (popIn/slide/pulse/shake...)
    │   ├── widgets/timeline.dart         # filmstrip + lanes + playhead + trim handles
    │   ├── widgets/ai_assistant_sheet.dart # شات الـ Agent جوه المحرر
    │   ├── panels/…              # كابتشن، ستايلات، نصوص/ستيكرز، فيلاتر، سرعة، صوت، انتقالات، موشن
    │   └── export/export_screen.dart     # دقة/جودة/حرق كابتشن + حفظ للمعرض
    ├── ai/ai_studio_screen.dart
    └── settings/settings_screen.dart
```

---

## 🧩 المكتبات الأساسية

- [`ffmpeg_kit_flutter_new_full_gpl`](https://pub.dev/packages/ffmpeg_kit_flutter_new_full_gpl) — فورك FFmpegKit الشغال (libass + fribidi + x264)
- `video_player` — المعاينة
- `flutter_riverpod` — إدارة الحالة
- `video_thumbnail` — الـ filmstrip
- `gal` + `share_plus` — حفظ ومشاركة

> ⚠️ لو الفورك غيّر أسماء ملفاته الداخلية، صلّح الـ import في **ملف واحد بس**: `lib/services/ffmpeg_gateway.dart`

---

## 💡 أفكار للتطوير

- [ ] كليبات متعددة في المعاينة (حاليًا المعاينة بتشغل أول كليب، والتصدير بيضم الكل صح)
- [ ] Keyframes للأوفرلايز
- [ ] Lottie stickers
- [ ] تسجيل صوت VO
- [ ] نسخة سطح مكتب (نفس الكود يعمل على ويندوز/ماك/لينكس)

## 📜 الترخيص والاعتمادات

- الكود مفتوح — استخدمه براحتك
- مستوحى من ميزات [OpenCut](https://github.com/OpenCut-app/OpenCut) و CapCut و VEED
- الخطوط: Google Fonts (OFL) — Tajawal, Almarai, Anton, Bebas Neue, Lalezar
