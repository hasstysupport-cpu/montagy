import 'package:flutter/material.dart';

/// A look-up "filter" implemented with FFmpeg eq/hue/curves filters.
class FilterPreset {
  final String id;
  /// FFmpeg filter string; {i} = intensity 0..1 placeholder.
  final String ffmpeg;
  final Color swatch1;
  final Color swatch2;

  const FilterPreset(this.id, this.ffmpeg, this.swatch1, this.swatch2);

  String build(double intensity) => ffmpeg.replaceAll('{i}', intensity.toStringAsFixed(3));
}

class Filters {
  Filters._();
  static const original = FilterPreset('original', '', Color(0xFF555555), Color(0xFF888888));
  static const vivid = FilterPreset('vivid',
      'eq=saturation={i}:contrast=1.0+0.15*{i}', const Color(0xFFFF5F6D), const Color(0xFFFFC371));
  static const cinematic = FilterPreset('cinematic',
      'eq=contrast=1.0+0.18*{i}:saturation=1.0-0.1*{i}:colorbalance=rs=-0.06*{i}:bs=0.08*{i}',
      const Color(0xFF0F2027), const Color(0xFF2C5364));
  static const bw = FilterPreset('bw', 'hue=s=0', const Color(0xFF111111), const Color(0xFFEEEEEE));
  static const vintage = FilterPreset('vintage',
      'eq=saturation=1.0-0.25*{i}:gamma=1.0+0.08*{i},colorbalance=rs=0.08*{i}:gs=0.03*{i}',
      const Color(0xFFC79081), const Color(0xFFDFA579));
  static const cool = FilterPreset('cool',
      'colorbalance=bs=0.15*{i}:rs=-0.06*{i}', const Color(0xFF2193B0), const Color(0xFF6DD5ED));
  static const warm = FilterPreset('warm',
      'colorbalance=rs=0.15*{i}:bs=-0.06*{i}', const Color(0xFFF7797D), const Color(0xFFC471ED));
  static const fade = FilterPreset('fade',
      'eq=contrast=1.0-0.15*{i}:saturation=1.0-0.2*{i}', const Color(0xFFABB2B9), const Color(0xFFEAEAEA));
  static const noir = FilterPreset('noir',
      'hue=s=0,eq=contrast=1.0+0.35*{i}:brightness=-0.03*{i}', const Color(0xFF000000), const Color(0xFF9E9E9E));
  static const neonDream = FilterPreset('neondream',
      'eq=saturation=1.0+0.5*{i}:contrast=1.0+0.1*{i},colorbalance=ms=0.12*{i}:bs=0.10*{i}',
      const Color(0xFFDA22FF), const Color(0xFF9733EE));

  static const List<FilterPreset> all = [
    original, vivid, cinematic, bw, vintage, cool, warm, fade, noir, neonDream,
  ];

  static FilterPreset byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => original);
}
