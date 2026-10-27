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

  ExportQuality _quality = ExportQuality.high;
  int _resIdx = 1; // 0=1080, 1=720, 2=480
  bool _burnCaptions = true;
  static const _resolutions = [(1920, 1080), (1280, 720), (854, 480)];

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

  Widget _optionsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.tr('resolution'), style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('${_resolutions[i].$1}p'),
                    selected: _resIdx == i,
                    onSelected: (_) => setState(() => _resIdx = i),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(context.tr('quality'), style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final q in ExportQuality.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(switch (q) {
                      ExportQuality.high => context.tr('high'),
                      ExportQuality.medium => context.tr('medium'),
                      ExportQuality.low => context.tr('low'),
                    }),
                    selected: _quality == q,
                    onSelected: (_) => setState(() => _quality = q),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('burn_captions'), style: GoogleFonts.cairo(fontSize: 14)),
          subtitle: Text('ASS/libass — karaoke + neon + box',
              style: GoogleFonts.cairo(fontSize: 11.5, color: AppColors.textDim)),
          value: _burnCaptions,
          activeColor: AppColors.primary,
          onChanged: (v) => setState(() => _burnCaptions = v),
        ),
        const Spacer(),
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

      final res = _resolutions[_resIdx];
      String? assPath;
      if (_burnCaptions && project.captions.isNotEmpty) {
        final tmp = await StorageService.instance.tmpDir();
        final styles = {for (final s in CaptionStylePresets.all) s.id: s};
        assPath = await AssService.writeAssFile(
          dir: tmp.path,
          captions: project.captions,
          stylesById: styles,
          videoW: res.$1,
          videoH: res.$2,
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
        targetW: res.$1,
        targetH: res.$2,
        totalDuration: project.totalDuration,
        quality: _quality,
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
