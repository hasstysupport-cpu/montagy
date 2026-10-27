import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_font.dart';
import '../../core/strings.dart';
import '../../services/export_service.dart';
import '../editor/editor_screen.dart';

/// شاشة التصدير — إعدادات + تنفيذ حقيقي + نتيجة.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  late int _height;
  late int _fps;
  late int _crf;
  bool _running = false;
  bool _cancelled = false;
  double _progress = 0;
  String _phase = '';
  ExportResult? _result;
  VideoPlayerController? _previewCtrl;

  @override
  void initState() {
    super.initState();
    final state = EditorScope.of(context);
    _height = state.project.exportSettings.height;
    _fps = state.project.exportSettings.fps;
    _crf = state.project.exportSettings.crf;
  }

  @override
  void dispose() {
    _previewCtrl?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final state = EditorScope.of(context);
    setState(() {
      _running = true;
      _cancelled = false;
      _progress = 0;
      _phase = S.preparing;
      _result = null;
    });

    state.project.exportSettings
      ..height = _height
      ..fps = _fps
      ..crf = _crf;
    await state.saveNow();

    final result = await ExportService.run(ExportJob(
      project: state.project,
      height: _height,
      fps: _fps,
      crf: _crf,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            _progress = p.value;
            _phase = p.phase;
          });
        }
      },
      isCancelled: () => _cancelled,
    ));

    if (!mounted) return;
    setState(() {
      _running = false;
      _result = result;
    });

    if (result.outputPath != null) {
      final c = VideoPlayerController.file(File(result.outputPath!));
      await c.initialize();
      if (mounted) {
        setState(() => _previewCtrl = c);
        c.setLooping(true);
        c.play();
      } else {
        c.dispose();
      }
    }
  }

  void _cancel() {
    setState(() => _cancelled = true);
  }

  Future<void> _saveToGallery() async {
    final path = _result?.outputPath;
    if (path == null) return;
    try {
      await Gal.putVideo(path, album: 'Montagy');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(S.savedToGallery)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الحفظ — استخدم زر المشاركة')),
        );
      }
    }
  }

  Future<void> _share() async {
    final path = _result?.outputPath;
    if (path == null) return;
    await Share.shareXFiles(
      [XFile(path)],
      text: 'صنعت بـ مونتاجي 🎬',
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = EditorScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (w, h) = ExportService.canvasSize(
        state.project.canvas.aspect, _height);

    return Scaffold(
      appBar: AppBar(
        title: AppFont.w(700, size: 16).make(S.exportVideo),
      ),
      body: SafeArea(
        child: _running || _result != null
            ? _buildProgress(dark)
            : _buildSettings(context, dark, w, h),
      ),
    );
  }

  Widget _buildSettings(BuildContext context, bool dark, int w, int h) {
    final state = EditorScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ملخص
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: dark ? AppColors.darkBorder : AppColors.lightBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.movie_creation_outlined,
                    color: AppColors.blue, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppFont.w(700, size: 13.5).make(state.project.name),
                      AppFont.w(500, size: 11,
                              color: dark
                                  ? AppColors.darkTextDim
                                  : AppColors.lightTextDim)
                          .make(
                        '${state.project.clips.length} مقطع • ${S.durationLabel(state.totalDuration)} • $w×$h',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          _Label(S.resolution),
          _ChipRow(
            options: const [(480, '480p'), (720, '720p'), (1080, '1080p'), (1440, '2K')],
            value: _height,
            onChanged: (v) => setState(() => _height = v),
          ),
          const SizedBox(height: 18),

          _Label(S.frameRate),
          _ChipRow(
            options: const [(24, '24'), (30, '30'), (60, '60')],
            value: _fps,
            onChanged: (v) => setState(() => _fps = v),
          ),
          const SizedBox(height: 18),

          _Label(S.quality),
          _ChipRow(
            options: const [(23, S.qualityStd), (20, S.qualityHigh), (17, S.qualityUltra)],
            value: _crf,
            onChanged: (v) => setState(() => _crf = v),
          ),
          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _start,
              icon: const Icon(Icons.rocket_launch_outlined),
              label: AppFont.w(800, size: 15).make(S.startExport),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: AppFont.w(400, size: 11,
                    color: dark
                        ? AppColors.darkTextDim
                        : AppColors.lightTextDim)
                .make(S.keepScreenOn),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(bool dark) {
    final result = _result;
    if (result != null) {
      if (result.cancelled) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel_outlined, size: 60, color: AppColors.warn),
              const SizedBox(height: 14),
              AppFont.w(700, size: 16).make(S.exportCancelled),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(S.close),
              ),
            ],
          ),
        );
      }
      if (result.outputPath != null) {
        return _buildSuccess(dark, result);
      }
      return _buildError(dark, result);
    }

    // جارٍ
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: _progress <= 0 ? null : _progress,
                    strokeWidth: 7,
                    backgroundColor:
                        dark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                AppFont.w(900, size: 26, color: AppColors.blue)
                    .make('${(_progress * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 26),
            AppFont.w(700, size: 15).make(_phase),
            const SizedBox(height: 8),
            AppFont.w(400, size: 12,
                    color: dark
                        ? AppColors.darkTextDim
                        : AppColors.lightTextDim)
                .make(S.keepScreenOn),
            const SizedBox(height: 30),
            OutlinedButton.icon(
              onPressed: _cancel,
              icon: const Icon(Icons.close, size: 17),
              label: const Text(S.cancelExport),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(bool dark, ExportResult result) {
    final file = File(result.outputPath!);
    final sizeMb = file.existsSync() ? file.lengthSync() / 1024 / 1024 : 0.0;
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: _previewCtrl != null &&
                    _previewCtrl!.value.isInitialized
                ? Stack(
                    alignment: Alignment.bottomLeft,
                    children: [
                      Center(child: AspectRatio(
                        aspectRatio: _previewCtrl!.value.size.aspectRatio,
                        child: VideoPlayer(_previewCtrl!),
                      )),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: AppFont.w(600, size: 11, color: Colors.white)
                              .make(
                            '${_previewCtrl!.value.size.width.round()}×${_previewCtrl!.value.size.height.round()} • ${sizeMb.toStringAsFixed(1)}MB',
                          ),
                        ),
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 22),
                  const SizedBox(width: 8),
                  AppFont.w(800, size: 15).make(S.exportDone),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saveToGallery,
                      icon: const Icon(Icons.download, size: 18),
                      label: AppFont.w(700, size: 13).make(S.saveToGallery),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share, size: 18),
                      label: AppFont.w(700, size: 13).make(S.share),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(bool dark, ExportResult result) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 58, color: AppColors.danger),
            const SizedBox(height: 14),
            AppFont.w(700, size: 16).make(S.exportFailed),
            const SizedBox(height: 8),
            AppFont.w(400, size: 12.5,
                    color: dark
                        ? AppColors.darkTextDim
                        : AppColors.lightTextDim)
                .make(result.error ?? ''),
            if (result.logTail != null && result.logTail!.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    result.logTail!,
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 9.5),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => setState(() => _result = null),
              child: const Text(S.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppFont.w(800, size: 13.5).make(text),
    );
  }
}

class _ChipRow<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  const _ChipRow({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        for (final (v, label) in options) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: v == value
                      ? AppColors.blue
                      : (dark
                          ? AppColors.darkSurfaceHi
                          : AppColors.lightSurfaceHi),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        v == value ? AppColors.blue : Colors.transparent,
                    width: 1.6,
                  ),
                ),
                child: Center(
                  child: AppFont.w(v == value ? 700 : 500, size: 12.5,
                          color: v == value ? Colors.white : null)
                      .make(label),
                ),
              ),
            ),
          ),
          if (v != options.last.$1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
