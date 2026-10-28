import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────
/// نماذج بيانات مونتاجي v2
/// ─────────────────────────────────────────────

enum MediaType { video, photo }

enum AspectKind { r1_1, r4_5, r5_4, r9_16, r16_9, r2_3, r3_2, r3_4, r4_3 }

extension AspectKindX on AspectKind {
  double get ratio {
    switch (this) {
      case AspectKind.r1_1: return 1;
      case AspectKind.r4_5: return 4 / 5;
      case AspectKind.r5_4: return 5 / 4;
      case AspectKind.r9_16: return 9 / 16;
      case AspectKind.r16_9: return 16 / 9;
      case AspectKind.r2_3: return 2 / 3;
      case AspectKind.r3_2: return 3 / 2;
      case AspectKind.r3_4: return 3 / 4;
      case AspectKind.r4_3: return 4 / 3;
    }
  }

  String get label {
    switch (this) {
      case AspectKind.r1_1: return '1:1';
      case AspectKind.r4_5: return '4:5';
      case AspectKind.r5_4: return '5:4';
      case AspectKind.r9_16: return '9:16';
      case AspectKind.r16_9: return '16:9';
      case AspectKind.r2_3: return '2:3';
      case AspectKind.r3_2: return '3:2';
      case AspectKind.r3_4: return '3:4';
      case AspectKind.r4_3: return '4:3';
    }
  }
}

enum CanvasBg { black, white, custom, blur }

enum TextAnim { none, fade, slideUp, slideDown, slideLeft, slideRight }

enum AudioKind { music, voice, extracted }

/// إطار مفتاحي للطبقات (نص/ملصق/فيديو) — نمط CapCut.
class OvKeyframe {
  double t;          // ثانية على التايم لاين
  double nx, ny;     // الموضع 0..1
  double scale;
  double opacity;
  double rotation;   // درجات

  OvKeyframe({
    required this.t,
    this.nx = 0.5,
    this.ny = 0.5,
    this.scale = 1,
    this.opacity = 1,
    this.rotation = 0,
  });

  Map<String, dynamic> toJson() => {
        't': t, 'nx': nx, 'ny': ny, 's': scale, 'o': opacity, 'r': rotation,
      };

  static OvKeyframe fromJson(Map<String, dynamic> j) => OvKeyframe(
        t: (j['t'] ?? 0).toDouble(),
        nx: (j['nx'] ?? 0.5).toDouble(),
        ny: (j['ny'] ?? 0.5).toDouble(),
        scale: (j['s'] ?? 1).toDouble(),
        opacity: (j['o'] ?? 1).toDouble(),
        rotation: (j['r'] ?? 0).toDouble(),
      );

  OvKeyframe clone() => OvKeyframe(
      t: t, nx: nx, ny: ny, scale: scale, opacity: opacity, rotation: rotation);

  /// استيفاء خطي بين الإطارات عند زمن معين.
  static OvKeyframe? interpolate(List<OvKeyframe> kfs, double t) {
    if (kfs.isEmpty) return null;
    if (kfs.length == 1 || t <= kfs.first.t) {
      final k = kfs.first;
      return OvKeyframe(
          t: t,
          nx: k.nx,
          ny: k.ny,
          scale: k.scale,
          opacity: k.opacity,
          rotation: k.rotation);
    }
    if (t >= kfs.last.t) {
      final k = kfs.last;
      return OvKeyframe(
          t: t,
          nx: k.nx,
          ny: k.ny,
          scale: k.scale,
          opacity: k.opacity,
          rotation: k.rotation);
    }
    for (var i = 0; i < kfs.length - 1; i++) {
      final a = kfs[i], b = kfs[i + 1];
      if (t >= a.t && t <= b.t) {
        final f = (b.t - a.t) <= 0.0001 ? 0.0 : (t - a.t) / (b.t - a.t);
        double lerp(double x, double y) => x + (y - x) * f;
        return OvKeyframe(
          t: t,
          nx: lerp(a.nx, b.nx),
          ny: lerp(a.ny, b.ny),
          scale: lerp(a.scale, b.scale),
          opacity: lerp(a.opacity, b.opacity),
          rotation: lerp(a.rotation, b.rotation),
        );
      }
    }
    final k = kfs.last;
    return OvKeyframe(
        t: t,
        nx: k.nx,
        ny: k.ny,
        scale: k.scale,
        opacity: k.opacity,
        rotation: k.rotation);
  }

  /// تعبير FFmpeg لتعبير x/y مع استيفاء خطي بين الإطارات.
  /// يُبنى كسلسلة if متداخلة: if(lt(t,t1), lerp01, if(lt(t,t2), lerp12, ...)).
  static String ffExpr(List<OvKeyframe> kfs, double Function(OvKeyframe) get,
      {String unit = ''}) {
    String val(double v) =>
        unit.isEmpty ? _n(v) : '(${_n(v)}${unit == 'W' ? '*W' : '*H'})';
    String vAt(OvKeyframe k) =>
        unit.isEmpty ? _n(get(k)) : '(${_n(get(k))}*${unit})';
    if (kfs.isEmpty) return val(0.5);
    if (kfs.length == 1) return vAt(kfs.first);
    var expr = vAt(kfs.last);
    for (var i = kfs.length - 2; i >= 0; i--) {
      final a = kfs[i], b = kfs[i + 1];
      final fa = get(a), fb = get(b);
      final lerp =
          unit.isEmpty
              ? '(${_n(fa)}+(${_n(fb - fa)})*(t-${_n(a.t)}))'
              : '((${_n(fa)}+(${_n(fb - fa)})*(t-${_n(a.t)}))*${unit})';
      expr = 'if(lt(t,${_n(b.t)}),$lerp,$expr)';
    }
    return expr;
  }

  static String _n(double v) {
    var s = v.toStringAsFixed(4);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s.isEmpty || s == '-' ? '0' : s;
  }
}

/// بارامترات التدرج اللوني — كلها 0 = بلا تغيير (ما عدا ما يُذكر).
class ColorParams {
  final double brightness;   // -1..1
  final double contrast;     // -1..1
  final double saturation;   // -1..1
  final double warmth;       // -1..1 (سالب = بارد)
  final double tint;         // -1..1 (أخضر ↔ أرجواني)
  final double fade;         // 0..1 رفع الأسود
  final double vignette;     // 0..1
  final double monochrome;   // 0..1
  final double sharpen;      // 0..1 حدة
  final double highlights;   // -1..1 إبرازات
  final double shadows;      // -1..1 ظلال
  final double hue;          // -1..1 دورة الهوى (180°)

  const ColorParams({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
    this.tint = 0,
    this.fade = 0,
    this.vignette = 0,
    this.monochrome = 0,
    this.sharpen = 0,
    this.highlights = 0,
    this.shadows = 0,
    this.hue = 0,
  });

  factory ColorParams.neutral() => const ColorParams();

  ColorParams copyWith({
    double? brightness,
    double? contrast,
    double? saturation,
    double? warmth,
    double? tint,
    double? fade,
    double? vignette,
    double? monochrome,
    double? sharpen,
    double? highlights,
    double? shadows,
    double? hue,
  }) =>
      ColorParams(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        warmth: warmth ?? this.warmth,
        tint: tint ?? this.tint,
        fade: fade ?? this.fade,
        vignette: vignette ?? this.vignette,
        monochrome: monochrome ?? this.monochrome,
        sharpen: sharpen ?? this.sharpen,
        highlights: highlights ?? this.highlights,
        shadows: shadows ?? this.shadows,
        hue: hue ?? this.hue,
      );

  bool get isNeutral =>
      brightness == 0 && contrast == 0 && saturation == 0 && warmth == 0 &&
      tint == 0 && fade == 0 && vignette == 0 && monochrome == 0 &&
      sharpen == 0 && highlights == 0 && shadows == 0 && hue == 0;
}

/// مقطع في التايم لاين.
class ClipItem {
  final String id;
  final MediaType type;
  final String sourcePath;
  final String title;

  double inPoint;      // ثوانٍ من المصدر
  double outPoint;
  double photoDuration; // للصور
  double speed;         // 0.25..4
  double volume;        // 0..2
  bool muted;
  bool reversed;
  int rotation;         // 0/90/180/270
  bool flipH, flipV;
  Rect? crop;           // normalized في اتجاه العرض (بعد التدوير)

  String? filterPreset;
  double filterIntensity; // 0..1
  ColorParams adjust;

  /// مؤثرات المقطع: id → شدة 0..1 (نمط CapCut).
  Map<String, double> effects;

  String? transitionOutId;    // الانتقال للمقطع التالي
  double transitionDuration;

  // بيانات مُخزنة من الاستيراد
  double sourceDuration;
  Size sourceSize;
  bool hasAudio;
  String? thumbPath;

  ClipItem({
    required this.id,
    required this.type,
    required this.sourcePath,
    required this.title,
    this.inPoint = 0,
    this.outPoint = 0,
    this.photoDuration = 3,
    this.speed = 1,
    this.volume = 1,
    this.muted = false,
    this.reversed = false,
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.crop,
    this.filterPreset,
    this.filterIntensity = 1,
    ColorParams? adjust,
    Map<String, double>? effects,
    this.transitionOutId,
    this.transitionDuration = 0.5,
    this.sourceDuration = 0,
    this.sourceSize = Size.zero,
    this.hasAudio = true,
    this.thumbPath,
  })  : adjust = adjust ?? ColorParams.neutral(),
        effects = effects ?? {};

  /// مدة المقطع على التايم لاين (بالثواني).
  double get timelineDuration {
    if (type == MediaType.photo) {
      return (photoDuration / speed).clamp(0.1, 600);
    }
    final raw = (outPoint - inPoint) / speed;
    return raw.clamp(0.1, 3600).toDouble();
  }

  double get trimDuration => type == MediaType.photo ? photoDuration : (outPoint - inPoint);

  ClipItem copyWith({
    double? inPoint,
    double? outPoint,
    double? photoDuration,
    double? speed,
    double? volume,
    bool? muted,
    bool? reversed,
    int? rotation,
    bool? flipH,
    bool? flipV,
    Rect? crop,
    bool clearCrop = false,
    String? filterPreset,
    bool clearFilter = false,
    double? filterIntensity,
    ColorParams? adjust,
    Map<String, double>? effects,
    String? transitionOutId,
    bool clearTransition = false,
    double? transitionDuration,
  }) =>
      ClipItem(
        id: id,
        type: type,
        sourcePath: sourcePath,
        title: title,
        inPoint: inPoint ?? this.inPoint,
        outPoint: outPoint ?? this.outPoint,
        photoDuration: photoDuration ?? this.photoDuration,
        speed: speed ?? this.speed,
        volume: volume ?? this.volume,
        muted: muted ?? this.muted,
        reversed: reversed ?? this.reversed,
        rotation: rotation ?? this.rotation,
        flipH: flipH ?? this.flipH,
        flipV: flipV ?? this.flipV,
        crop: clearCrop ? null : (crop ?? this.crop),
        filterPreset: clearFilter ? null : (filterPreset ?? this.filterPreset),
        filterIntensity: filterIntensity ?? this.filterIntensity,
        adjust: adjust ?? this.adjust,
        effects: effects != null ? Map<String, double>.of(effects) : this.effects,
        transitionOutId:
            clearTransition ? null : (transitionOutId ?? this.transitionOutId),
        transitionDuration: transitionDuration ?? this.transitionDuration,
        sourceDuration: sourceDuration,
        sourceSize: sourceSize,
        hasAudio: hasAudio,
        thumbPath: thumbPath,
      );

  Map<String, dynamic> toJson() => {
        'id': id, 'type': type.name, 'src': sourcePath, 'title': title,
        'in': inPoint, 'out': outPoint, 'pd': photoDuration, 'sp': speed,
        'vol': volume, 'muted': muted, 'rev': reversed, 'rot': rotation,
        'fh': flipH, 'fv': flipV,
        'crop': crop == null ? null : [crop!.left, crop!.top, crop!.width, crop!.height],
        'fp': filterPreset, 'fi': filterIntensity,
        'adj': _paramsToJson(adjust),
        'fx': effects,
        'tr': transitionOutId, 'trd': transitionDuration,
        'sd': sourceDuration, 'sw': sourceSize.width, 'sh': sourceSize.height,
        'au': hasAudio, 'thumb': thumbPath,
      };

  static ClipItem fromJson(Map<String, dynamic> j) {
    final c = j['crop'] as List?;
    return ClipItem(
      id: j['id'],
      type: j['type'] == 'photo' ? MediaType.photo : MediaType.video,
      sourcePath: j['src'],
      title: j['title'] ?? '',
      inPoint: (j['in'] ?? 0).toDouble(),
      outPoint: (j['out'] ?? 0).toDouble(),
      photoDuration: (j['pd'] ?? 3).toDouble(),
      speed: (j['sp'] ?? 1).toDouble(),
      volume: (j['vol'] ?? 1).toDouble(),
      muted: j['muted'] ?? false,
      reversed: j['rev'] ?? false,
      rotation: j['rot'] ?? 0,
      flipH: j['fh'] ?? false,
      flipV: j['fv'] ?? false,
      crop: c == null ? null : Rect.fromLTWH(c[0].toDouble(), c[1].toDouble(), c[2].toDouble(), c[3].toDouble()),
      filterPreset: j['fp'],
      filterIntensity: (j['fi'] ?? 1).toDouble(),
      adjust: _paramsFromJson(j['adj']),
      effects: j['fx'] == null
          ? {}
          : (j['fx'] as Map).map((k, v) =>
              MapEntry(k.toString(), (v as num).toDouble())),
      transitionOutId: j['tr'],
      transitionDuration: (j['trd'] ?? 0.5).toDouble(),
      sourceDuration: (j['sd'] ?? 0).toDouble(),
      sourceSize: Size((j['sw'] ?? 0).toDouble(), (j['sh'] ?? 0).toDouble()),
      hasAudio: j['au'] ?? true,
      thumbPath: j['thumb'],
    );
  }
}

Map<String, dynamic> _paramsToJson(ColorParams p) => {
      'b': p.brightness, 'c': p.contrast, 's': p.saturation, 'w': p.warmth,
      't': p.tint, 'f': p.fade, 'v': p.vignette, 'm': p.monochrome,
      'sh': p.sharpen, 'hl': p.highlights, 'sd': p.shadows, 'hu': p.hue,
    };

ColorParams _paramsFromJson(Map<String, dynamic>? j) => j == null
    ? ColorParams.neutral()
    : ColorParams(
        brightness: (j['b'] ?? 0).toDouble(),
        contrast: (j['c'] ?? 0).toDouble(),
        saturation: (j['s'] ?? 0).toDouble(),
        warmth: (j['w'] ?? 0).toDouble(),
        tint: (j['t'] ?? 0).toDouble(),
        fade: (j['f'] ?? 0).toDouble(),
        vignette: (j['v'] ?? 0).toDouble(),
        monochrome: (j['m'] ?? 0).toDouble(),
        sharpen: (j['sh'] ?? 0).toDouble(),
        highlights: (j['hl'] ?? 0).toDouble(),
        shadows: (j['sd'] ?? 0).toDouble(),
        hue: (j['hu'] ?? 0).toDouble(),
      );

/// طبقة نص.
class TextOverlay {
  final String id;
  String text;
  String fontFamily;
  double fontSize;    // نسبة من ارتفاع الفيديو (0.02..0.25)
  Color color;
  int textAlign;      // 0 center, 1 right, 2 left (visual)
  bool hasBg;
  Color bgColor;
  double bgOpacity;
  bool hasStroke;
  Color strokeColor;
  double strokeWidth; // نسبة من حجم الخط
  bool hasShadow;
  double rotation;    // درجات
  double nx, ny;      // مركز طبيعي 0..1
  double scale;       // مضاعف إضافي
  double start, end;  // ثوانٍ على التايم لاين
  TextAnim animIn, animOut;
  double animDur;

  /// الإطارات المفتاحية (اختياري).
  List<OvKeyframe> keyframes;

  TextOverlay({
    required this.id,
    this.text = '',
    this.fontFamily = 'Alexandria',
    this.fontSize = 0.06,
    this.color = Colors.white,
    this.textAlign = 0,
    this.hasBg = false,
    this.bgColor = Colors.black,
    this.bgOpacity = 0.6,
    this.hasStroke = false,
    this.strokeColor = Colors.black,
    this.strokeWidth = 0.08,
    this.hasShadow = true,
    this.rotation = 0,
    this.nx = 0.5,
    this.ny = 0.5,
    this.scale = 1,
    this.start = 0,
    this.end = 3,
    this.animIn = TextAnim.fade,
    this.animOut = TextAnim.fade,
    this.animDur = 0.4,
    List<OvKeyframe>? keyframes,
  }) : keyframes = keyframes ?? [];

  /// الخصائص الفعالة عند زمن معين (مع الإطارات المفتاحية).
  ({double nx, double ny, double scale, double rotation, double opacity})
      resolvedAt(double t) {
    if (keyframes.length < 2) {
      return (nx: nx, ny: ny, scale: scale, rotation: rotation, opacity: 1);
    }
    final k = OvKeyframe.interpolate(keyframes, t);
    if (k == null) {
      return (nx: nx, ny: ny, scale: scale, rotation: rotation, opacity: 1);
    }
    return (
      nx: k.nx, ny: k.ny, scale: k.scale, rotation: k.rotation, opacity: k.opacity);
  }

  Map<String, dynamic> toJson() => {
        'id': id, 't': text, 'f': fontFamily, 'fs': fontSize,
        'c': color.value, 'al': textAlign,
        'bg': hasBg, 'bc': bgColor.value, 'bo': bgOpacity,
        'st': hasStroke, 'sc': strokeColor.value, 'sw': strokeWidth,
        'sh': hasShadow, 'rot': rotation, 'nx': nx, 'ny': ny, 'sc2': scale,
        's': start, 'e': end, 'ai': animIn.name, 'ao': animOut.name, 'ad': animDur,
        'kf': keyframes.map((e) => e.toJson()).toList(),
      };

  static TextOverlay fromJson(Map<String, dynamic> j) => TextOverlay(
        id: j['id'],
        text: j['t'] ?? '',
        fontFamily: j['f'] ?? 'Alexandria',
        fontSize: (j['fs'] ?? 0.06).toDouble(),
        color: Color(j['c'] ?? 0xFFFFFFFF),
        textAlign: j['al'] ?? 0,
        hasBg: j['bg'] ?? false,
        bgColor: Color(j['bc'] ?? 0xFF000000),
        bgOpacity: (j['bo'] ?? 0.6).toDouble(),
        hasStroke: j['st'] ?? false,
        strokeColor: Color(j['sc'] ?? 0xFF000000),
        strokeWidth: (j['sw'] ?? 0.08).toDouble(),
        hasShadow: j['sh'] ?? true,
        rotation: (j['rot'] ?? 0).toDouble(),
        nx: (j['nx'] ?? 0.5).toDouble(),
        ny: (j['ny'] ?? 0.5).toDouble(),
        scale: (j['sc2'] ?? 1).toDouble(),
        start: (j['s'] ?? 0).toDouble(),
        end: (j['e'] ?? 3).toDouble(),
        animIn: TextAnim.values.firstWhere(
            (e) => e.name == j['ai'], orElse: () => TextAnim.fade),
        animOut: TextAnim.values.firstWhere(
            (e) => e.name == j['ao'], orElse: () => TextAnim.fade),
        animDur: (j['ad'] ?? 0.4).toDouble(),
        keyframes: j['kf'] == null
            ? []
            : ((j['kf'] as List)
                .map((e) => OvKeyframe.fromJson(Map<String, dynamic>.from(e)))
                .toList()),
      );
}

/// ملصق (إيموجي أو صورة) أو طبقة فيديو PiP.
class ImageOverlay {
  final String id;
  final String? emoji;
  final String? imagePath;
  // طبقة فيديو (PiP) — نمط CapCut "Overlay"
  final String? videoPath;
  double videoInPoint;   // داخل ملف الفيديو
  double videoSpeed;
  double videoVolume;
  bool videoMuted;

  double nx, ny;
  double scale;      // نسبة من ارتفاع الفيديو (0.03..1)
  double rotation;   // درجات
  double opacity;
  double start, end;
  TextAnim animIn, animOut;
  double animDur;

  /// الإطارات المفتاحية (فارغة = الخصائص الأساسية ثابتة).
  List<OvKeyframe> keyframes;

  bool get isVideoLayer => videoPath != null;

  ImageOverlay({
    required this.id,
    this.emoji,
    this.imagePath,
    this.videoPath,
    this.videoInPoint = 0,
    this.videoSpeed = 1,
    this.videoVolume = 1,
    this.videoMuted = false,
    this.nx = 0.5,
    this.ny = 0.5,
    this.scale = 0.18,
    this.rotation = 0,
    this.opacity = 1,
    this.start = 0,
    this.end = 3,
    this.animIn = TextAnim.fade,
    this.animOut = TextAnim.fade,
    this.animDur = 0.3,
    List<OvKeyframe>? keyframes,
  })  : assert(emoji != null || imagePath != null || videoPath != null),
        keyframes = keyframes ?? [];

  /// الخصائص الفعالة عند زمن معين (مع الإطارات المفتاحية).
  ({double nx, double ny, double scale, double opacity, double rotation})
      resolvedAt(double t) {
    if (keyframes.length < 2) {
      return (
        nx: nx, ny: ny, scale: scale, opacity: opacity, rotation: rotation);
    }
    final k = OvKeyframe.interpolate(keyframes, t);
    if (k == null) {
      return (
        nx: nx, ny: ny, scale: scale, opacity: opacity, rotation: rotation);
    }
    return (
      nx: k.nx, ny: k.ny, scale: k.scale, opacity: k.opacity, rotation: k.rotation);
  }

  Map<String, dynamic> toJson() => {
        'id': id, 'em': emoji, 'im': imagePath,
        'vp': videoPath, 'vi': videoInPoint, 'vs': videoSpeed,
        'vv': videoVolume, 'vm': videoMuted,
        'nx': nx, 'ny': ny, 'sc': scale, 'rot': rotation, 'op': opacity,
        's': start, 'e': end, 'ai': animIn.name, 'ao': animOut.name, 'ad': animDur,
        'kf': keyframes.map((e) => e.toJson()).toList(),
      };

  static ImageOverlay fromJson(Map<String, dynamic> j) => ImageOverlay(
        id: j['id'],
        emoji: j['em'],
        imagePath: j['im'],
        videoPath: j['vp'],
        videoInPoint: (j['vi'] ?? 0).toDouble(),
        videoSpeed: (j['vs'] ?? 1).toDouble(),
        videoVolume: (j['vv'] ?? 1).toDouble(),
        videoMuted: j['vm'] ?? false,
        nx: (j['nx'] ?? 0.5).toDouble(),
        ny: (j['ny'] ?? 0.5).toDouble(),
        scale: (j['sc'] ?? 0.18).toDouble(),
        rotation: (j['rot'] ?? 0).toDouble(),
        opacity: (j['op'] ?? 1).toDouble(),
        start: (j['s'] ?? 0).toDouble(),
        end: (j['e'] ?? 3).toDouble(),
        animIn: TextAnim.values.firstWhere(
            (e) => e.name == j['ai'], orElse: () => TextAnim.fade),
        animOut: TextAnim.values.firstWhere(
            (e) => e.name == j['ao'], orElse: () => TextAnim.fade),
        animDur: (j['ad'] ?? 0.3).toDouble(),
        keyframes: j['kf'] == null
            ? []
            : ((j['kf'] as List)
                .map((e) => OvKeyframe.fromJson(Map<String, dynamic>.from(e)))
                .toList()),
      );
}

/// تراك صوتي.
class AudioTrack {
  final String id;
  final String path;
  final AudioKind kind;
  String title;
  double startAt;   // على التايم لاين
  double inPoint;   // داخل الملف
  double outPoint;
  double volume;
  double fadeIn, fadeOut;

  AudioTrack({
    required this.id,
    required this.path,
    required this.kind,
    this.title = '',
    this.startAt = 0,
    this.inPoint = 0,
    this.outPoint = 0,
    this.volume = 1,
    this.fadeIn = 0,
    this.fadeOut = 0,
  });

  double get duration => (outPoint - inPoint).clamp(0.1, 7200).toDouble();

  Map<String, dynamic> toJson() => {
        'id': id, 'p': path, 'k': kind.name, 't': title,
        'sa': startAt, 'in': inPoint, 'out': outPoint,
        'vol': volume, 'fi': fadeIn, 'fo': fadeOut,
      };

  static AudioTrack fromJson(Map<String, dynamic> j) => AudioTrack(
        id: j['id'],
        path: j['p'],
        kind: AudioKind.values.firstWhere((e) => e.name == j['k'],
            orElse: () => AudioKind.music),
        title: j['t'] ?? '',
        startAt: (j['sa'] ?? 0).toDouble(),
        inPoint: (j['in'] ?? 0).toDouble(),
        outPoint: (j['out'] ?? 0).toDouble(),
        volume: (j['vol'] ?? 1).toDouble(),
        fadeIn: (j['fi'] ?? 0).toDouble(),
        fadeOut: (j['fo'] ?? 0).toDouble(),
      );
}

class CanvasSettings {
  AspectKind aspect;
  CanvasBg bg;
  Color customColor;

  CanvasSettings({
    this.aspect = AspectKind.r9_16,
    this.bg = CanvasBg.black,
    this.customColor = Colors.black,
  });

  Map<String, dynamic> toJson() =>
      {'a': aspect.name, 'bg': bg.name, 'c': customColor.value};

  static CanvasSettings fromJson(Map<String, dynamic> j) => CanvasSettings(
        aspect: AspectKind.values
            .firstWhere((e) => e.name == j['a'], orElse: () => AspectKind.r9_16),
        bg: CanvasBg.values
            .firstWhere((e) => e.name == j['bg'], orElse: () => CanvasBg.black),
        customColor: Color(j['c'] ?? 0xFF000000),
      );
}

class ExportSettings {
  int height;      // 480/720/1080/1440
  int fps;         // 24/30/60
  int crf;         // 17..26

  ExportSettings({this.height = 1080, this.fps = 30, this.crf = 20});

  Map<String, dynamic> toJson() => {'h': height, 'fps': fps, 'crf': crf};

  static ExportSettings fromJson(Map<String, dynamic> j) => ExportSettings(
        height: j['h'] ?? 1080, fps: j['fps'] ?? 30, crf: j['crf'] ?? 20);
}

/// المشروع.
class Project {
  final String id;
  String name;
  DateTime created;
  DateTime modified;
  List<ClipItem> clips;
  List<TextOverlay> texts;
  List<ImageOverlay> overlays;
  List<AudioTrack> audio;
  CanvasSettings canvas;
  ExportSettings exportSettings;

  Project({
    required this.id,
    this.name = 'مشروع جديد',
    DateTime? created,
    DateTime? modified,
    List<ClipItem>? clips,
    List<TextOverlay>? texts,
    List<ImageOverlay>? overlays,
    List<AudioTrack>? audio,
    CanvasSettings? canvas,
    ExportSettings? exportSettings,
  })  : created = created ?? DateTime.now(),
        modified = modified ?? DateTime.now(),
        clips = clips ?? [],
        texts = texts ?? [],
        overlays = overlays ?? [],
        audio = audio ?? [],
        canvas = canvas ?? CanvasSettings(),
        exportSettings = exportSettings ?? ExportSettings();

  Map<String, dynamic> toJson() => {
        'id': id, 'name': name,
        'created': created.millisecondsSinceEpoch,
        'modified': modified.millisecondsSinceEpoch,
        'clips': clips.map((e) => e.toJson()).toList(),
        'texts': texts.map((e) => e.toJson()).toList(),
        'overlays': overlays.map((e) => e.toJson()).toList(),
        'audio': audio.map((e) => e.toJson()).toList(),
        'canvas': canvas.toJson(),
        'export': exportSettings.toJson(),
        'v': 2,
      };

  static Project fromJson(Map<String, dynamic> j) => Project(
        id: j['id'],
        name: j['name'] ?? 'مشروع',
        created: DateTime.fromMillisecondsSinceEpoch(j['created'] ?? 0),
        modified: DateTime.fromMillisecondsSinceEpoch(j['modified'] ?? 0),
        clips: ((j['clips'] ?? []) as List)
            .map((e) => ClipItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        texts: ((j['texts'] ?? []) as List)
            .map((e) => TextOverlay.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        overlays: ((j['overlays'] ?? []) as List)
            .map((e) => ImageOverlay.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        audio: ((j['audio'] ?? []) as List)
            .map((e) => AudioTrack.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        canvas: j['canvas'] == null
            ? CanvasSettings()
            : CanvasSettings.fromJson(Map<String, dynamic>.from(j['canvas'])),
        exportSettings: j['export'] == null
            ? ExportSettings()
            : ExportSettings.fromJson(Map<String, dynamic>.from(j['export'])),
      );
}

/// ملف موجود؟ (للتحقق من صلاحية المسارات عند فتح مشروع)
bool fileExists(String? path) => path != null && File(path).existsSync();
