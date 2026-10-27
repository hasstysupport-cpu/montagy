import 'package:flutter/material.dart';

/// A look-up "filter" implemented with FFmpeg eq/hue/curves filters.
/// All chains are LINEAR (single stream) so they compose with the rest
/// of the per-clip pipeline.
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
      'eq=contrast=1.0+0.18*{i}:saturation=1.0-0.1*{i},colorbalance=rs=-0.06*{i}:bs=0.08*{i}',
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

  // ---- v1.1 pack (CapCut/InShot style looks) ----
  static const tealOrange = FilterPreset('tealorange',
      'colorbalance=rs=0.10*{i}:gs=0.02*{i}:bs=-0.08*{i}:rm=0.05*{i}:bm=-0.10*{i},eq=contrast=1.0+0.12*{i}',
      const Color(0xFF0E7490), const Color(0xFFF59E0B));
  static const sunset = FilterPreset('sunset',
      'colorbalance=rs=0.18*{i}:bs=-0.12*{i},eq=saturation=1.0+0.2*{i}:gamma=1.0+0.05*{i}',
      const Color(0xFFFF7E5F), const Color(0xFFFEB47B));
  static const moonlight = FilterPreset('moonlight',
      'colorbalance=bs=0.20*{i}:rs=-0.10*{i},eq=brightness=-0.04*{i}:saturation=1.0-0.15*{i}',
      const Color(0xFF16222A), const Color(0xFF3A6073));
  static const pop = FilterPreset('pop',
      'eq=saturation=1.0+0.35*{i}:contrast=1.0+0.2*{i}:gamma=1.0-0.04*{i}',
      const Color(0xFFF857A6), const Color(0xFFFF5858));
  static const matte = FilterPreset('matte',
      'eq=contrast=1.0-0.2*{i}:saturation=1.0-0.1*{i}:gamma=1.0+0.06*{i},colorbalance=rm=0.04*{i}:bm=0.04*{i}',
      const Color(0xFF8E9EAB), const Color(0xFFEEF2F3));
  static const aqua = FilterPreset('aqua',
      'colorbalance=bs=0.16*{i}:gs=0.08*{i}:rs=-0.08*{i},eq=saturation=1.0+0.1*{i}',
      const Color(0xFF13547A), const Color(0xFF80D0C7));
  static const gold = FilterPreset('gold',
      'colorbalance=rs=0.14*{i}:gs=0.06*{i}:bs=-0.14*{i},eq=saturation=1.0+0.08*{i}:gamma=1.0+0.04*{i}',
      const Color(0xFFB8860B), const Color(0xFFFFD700));
  static const cyberpunk = FilterPreset('cyberpunk',
      'eq=saturation=1.0+0.45*{i}:contrast=1.0+0.22*{i},colorbalance=ms=0.16*{i}:bs=0.12*{i}:rs=-0.06*{i}',
      const Color(0xFF00F260), const Color(0xFF0575E6));
  static const retro = FilterPreset('retro',
      'eq=saturation=1.0-0.3*{i}:contrast=1.0-0.1*{i},noise=alls=8*{i}:allf=t,colorbalance=rs=0.06*{i}:gm=0.03*{i}',
      const Color(0xFFAB2839), const Color(0xFFE5B25D));
  static const glitch = FilterPreset('glitch',
      'rgbashift=rh=3*{i}:bh=-3*{i},eq=saturation=1.0+0.25*{i}:contrast=1.0+0.1*{i}',
      const Color(0xFFF953C6), const Color(0xFFB91D73));
  static const kodak = FilterPreset('kodak',
      'colorbalance=rs=0.08*{i}:bs=-0.06*{i},eq=contrast=1.0+0.15*{i}:saturation=1.0+0.05*{i}:gamma=1.0-0.02*{i}',
      const Color(0xFFC1976B), const Color(0xFFF5E1C0));
  static const pastel = FilterPreset('pastel',
      'eq=saturation=1.0-0.35*{i}:gamma=1.0+0.1*{i}:brightness=0.02*{i},colorbalance=bm=0.03*{i}:gm=0.02*{i}',
      const Color(0xFFFBC2EB), const Color(0xFFA6C1EE));
  static const dreamy = FilterPreset('dreamy',
      'unsharp=5:5:-0.7*{i}:5:5:0.0,eq=saturation=1.0+0.1*{i}:brightness=0.03*{i}',
      const Color(0xFFD9AFD9), const Color(0xFF97D9E1));
  static const fireplace = FilterPreset('fireplace',
      'colorbalance=rs=0.20*{i}:bs=-0.18*{i},eq=brightness=-0.05*{i}:saturation=1.0+0.12*{i}:gamma=1.0+0.06*{i}',
      const Color(0xFF3E1F0D), const Color(0xFFFF8C42));

  static const List<FilterPreset> all = [
    original, vivid, cinematic, bw, vintage, cool, warm, fade, noir, neonDream,
    tealOrange, sunset, moonlight, pop, matte, aqua, gold, cyberpunk, retro,
    glitch, kodak, pastel, dreamy, fireplace,
  ];

  static FilterPreset byId(String id) =>
      all.firstWhere((f) => f.id == id, orElse: () => original);
}
