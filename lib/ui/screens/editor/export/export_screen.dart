import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/i18n/strings.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/caption_style.dart';
import '../../../../models/filter.dart';
import '../../../../models/project.dart';
import '../../../../services/ass_service.dart';
import '../../../../services/ffmpeg_service.dart';
import '../../../../services/storage_service.dart';

class ExportScreen extends ConsumerStatefulWidget {
  final String projectId;
  const ExportScreen({super.key, required this.projectId});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  double _progress = 0;
  String _stage = '';
  bool _busy = false;
  bool _done = false;
  String? _outPath;
  String? _error;

  // v1.1 export ladder
  int _resIdx = 1; // 0=auto, 1=1080p, 2=720p, 3=2K, 4=4K
  static const _resolutions = [
    (0, 'Auto'),
    (1080, '1080p'),
    (720, '720p'),
    (1440, '2K'),
    (2160, '4K'),
  ];
  int _fps = 30;
  ExportQuality _quality = ExportQuality.high;
  double _mbps = 0; // 0 = use quality CRF, else custom bitrate
  bool _burnCaptions = true;
  bool _bgBlur = false;

  (int, int)? _sourceDims;

  @override
  void initState() {
    super.initState();
    _probeSource();
  }

  Future<void> _probeSource() async {
    try {
      final projects = await StorageService.instance.listProjects();
      final project = projects.firstWhere((p) => p.id == widget.projectId);
      if (project.clips.isEmpty) return;
      final info = await FfmpegService.instance.probe(project.clips.first.path);
      if (mounted) setState(() => _sourceDims = (info.width, info.height));
    } catch (_) {}
  }

  (int, int) _targetDims() {
    final sel = _resolutions[_resIdx].$1;
    final src = _sourceDims ?? (1920, 1080);
    if (sel == 0) {
      // auto — keep source, even dims, capped to 4K
      final scale = (2160 / (src.$1 > src.$2 ? src.$1 : src.$2)).clamp(0.0, 1.0);
      return (((src.$1 * scale) ~/ 2) * 2, ((src.$2 * scale) ~/ 2) * 2);
    }
    // height-based ladder, keep source aspect
    final isPortrait = src.$2 > src.$1;
    if (isPortrait) {
      final w = sel;
      final h = ((w * src.$2 / src.$1) ~/ 2) * 2;
      return (w, h);
    }
    final h = sel;
    final w = ((h * src.$1 / src.$2) ~/ 2) * 2;
    return (w, h);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('export_video'))),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: _done ? _doneView() : _optionsView(),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t, style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13.5)),
      );

  Widget _optionsView() {
    final dims = _targetDims();
    return ListView(
      children: [
        _sectionLabel(context.tr('resolution')),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            for (var i = 0; i < _resolutions.length; i++)
              ChoiceChip(
                label: Text(_resolutions[i].$2),
                selected: _resIdx == i,
                onSelected: (_) => setState(() => _resIdx = i),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${dims.$1} × ${dims.$2} px',
              style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textDim)),
        ),
        const SizedBox(height: 14),
        _sectionLabel('FPS'),
        Wrap(
          spacing: 8,
          children: [
            for (final f in [24, 30, 60])
              ChoiceChip(
                label: Text('$f'),
                selected: _fps == f,
                onSelected: (_) => setState(() => _fps = f),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _sectionLabel(context.tr('quality')),
        Wrap(
          spacing: 8,
          children: [
            for (final q in ExportQuality.values)
              ChoiceChip(
                label: Text(switch (q) {
                  ExportQuality.high => context.tr('high'),
                  ExportQuality.medium => context.tr('medium'),
                  ExportQuality.low => context.tr('low'),
                }),
                selected: _quality == q && _mbps == 0,
                onSelected: (_) => setState(() {
                  _quality = q;
                  _mbps = 0;
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text(context.tr('custom_bitrate'),
              style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textDim)),
          const Spacer(),
          Text(_mbps == 0 ? 'CRF' : '${_mbps.toStringAsFixed(1)} Mbps',
              style: GoogleFonts.cairo(
                  fontSize: 11.5, color: _mbps == 0 ? AppColors.textDim : AppColors.primary)),
        ]),
        Slider(
          value: _mbps,
          min: 0, max: 40,
          divisions: 80,
          activeColor: _mbps == 0 ? AppColors.border : AppColors.primary,
          onChanged: (v) => setState(() => _mbps = v == 0 ? 0 : v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('burn_captions'), style: GoogleFonts.cairo(fontSize: 14)),
          subtitle: Text('ASS/libass — karaoke + neon + box',
              style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textDim)),
          value: _burnCaptions,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _burnCaptions = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('bg_blur'), style: GoogleFonts.cairo(fontSize: 14)),
          subtitle: Text(context.tr('bg_blur_hint'),
              style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textDim)),
          value: _bgBlur,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _bgBlur = v),
        ),
        const SizedBox(height: 10),
        if (_busy) ...[
          Text('${context.tr('exporting')} ${(_progress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.cairo(fontSize: 13)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _progress, minHeight: 7, borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: 6),
          Text('stage: $_stage', style: GoogleFonts.cairo(fontSize: 10.5, color: AppColors.textDim)),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: GoogleFonts.cairo(fontSize: 11, color: AppColors.danger)),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () {
              FfmpegService.instance.cancel();
              setState(() => _busy = false);
            },
            child: Text(context.tr('cancel')),
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(0, 52)),
              onPressed: _export,
              icon: const Icon(Icons.movie_creation),
              label: Text(context.tr('export'),
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _doneView() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96, height: 96,
            decoration: const BoxDecoration(gradient: AppColors.gradPrimary, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 54, color: Colors.white),
          ),
          const SizedBox(height: 18),
          Text(context.tr('export_done'),
              style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saveToGallery,
                  icon: const Icon(Icons.save_alt),
                  label: Text(context.tr('save_gallery')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  icon: const Icon(Icons.share),
                  label: Text(context.tr('share')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _done = false;
              _busy = false;
              _progress = 0;
            }),
            child: Text(context.tr('export_video')),
          ),
        ],
      );

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      final projects = await StorageService.instance.listProjects();
      final project = projects.firstWhere((p) => p.id == widget.projectId);
      final outDir = await StorageService.instance.exportsDir();
      final safeName = project.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final outPath =
          '${outDir.path}/${safeName}_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final dims = _targetDims();
      String? assPath;
      if (_burnCaptions && project.captions.isNotEmpty) {
        final tmp = await StorageService.instance.tmpDir();
        final styles = {for (final s in CaptionStylePresets.all) s.id: s};
        assPath = await AssService.writeAssFile(
          dir: tmp.path,
          captions: project.captions,
          stylesById: styles,
          videoW: dims.$1,
          videoH: dims.$2,
        );
      }

      final musicSpecs = [
        for (final a in project.audioTracks)
          {
            'path': a.path,
            'volume': a.volume,
            'fadeIn': a.fadeIn,
            'fadeOut': a.fadeOut,
            'startAt': a.startAt,
            'duration': project.totalDuration,
          },
      ];

      await FfmpegService.instance.exportProject(
        clipSpecs: _buildClipSpecs(project),
        outPath: outPath,
        settings: ExportSettings(
          width: dims.$1,
          height: dims.$2,
          fps: _fps,
          quality: _quality,
          customMbps: _mbps == 0 ? null : _mbps,
        ),
        totalDuration: project.totalDuration,
        assPath: assPath,
        musicSpecs: musicSpecs,
        onProgress: (p, stage) {
          if (!mounted) return;
          setState(() {
            _progress = p;
            _stage = stage;
          });
        },
      );
      setState(() {
        _busy = false;
        _done = true;
        _outPath = outPath;
      });
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _busy = false;
        _error = msg.length > 220 ? msg.substring(0, 220) : msg;
      });
    }
  }

  List<Map<String, dynamic>> _buildClipSpecs(VideoProject p) {
    final specs = <Map<String, dynamic>>[];
    for (final c in p.clips) {
      final filter = c.filterId == 'original' ? '' : Filters.byId(c.filterId).build(c.filterIntensity);
      specs.add({
        'path': c.path,
        'trimStart': c.trimStart,
        'trimEnd': c.trimEnd,
        'speed': c.speed,
        'volume': c.volume,
        'mute': c.volume == 0,
        'filter': filter,
        'transition': c.transitionToNext.toJson(),
        // v1.1 tools
        'rotate': c.rotate,
        'mirror': c.mirror,
        'flipV': c.flipV,
        'reverse': c.reverse,
        'freezeDur': c.freezeDur,
        'cropAspect': c.cropAspect,
        'kenBurns': c.kenBurns,
        'chromaEnabled': c.chromaEnabled,
        'chromaColor': c.chromaColor,
        'chromaSimilarity': c.chromaSimilarity,
        'chromaBlend': c.chromaBlend,
        'brightness': c.brightness,
        'contrast': c.contrast,
        'saturation': c.saturation,
        'warmth': c.warmth,
        'sharpen': c.sharpen,
        'vignette': c.vignette,
        'grain': c.grain,
        'pitch': c.pitch,
        'bass': c.bass,
        'treble': c.treble,
        'echo': c.echo,
        'bgBlur': _bgBlur,
      });
    }
    return specs;
  }

  Future<void> _saveToGallery() async {
    if (_outPath == null) return;
    try {
      await Gal.putVideo(_outPath!, album: 'Montagy');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('✓ ${context.tr('save_gallery')}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _share() async {
    if (_outPath == null) return;
    await Share.shareXFiles([XFile(_outPath!)]);
  }
}
