import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../core/i18n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/project.dart';
import '../../services/ffmpeg_service.dart';
import '../../services/storage_service.dart';
import '../../state/settings_provider.dart';
import 'editor/editor_screen.dart';
import 'ai/ai_studio_screen.dart';
import 'settings/settings_screen.dart';

final projectsProvider =
    FutureProvider.autoDispose<List<VideoProject>>((ref) => StorageService.instance.listProjects());

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tab) { 0 => _projectsTab(), 1 => const AiStudioScreen(), _ => const SettingsScreen() },
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.movie_creation_outlined), label: context.tr('nav_projects')),
          BottomNavigationBarItem(icon: const Icon(Icons.auto_awesome), label: context.tr('nav_ai')),
          BottomNavigationBarItem(icon: const Icon(Icons.settings_outlined), label: context.tr('nav_settings')),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              heroTag: 'new_project',
              onPressed: _createProject,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(context.tr('new_project'), style: const TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Future<void> _createProject() async {
    final picker = ImagePicker();
    final x = await picker.pickVideo(source: ImageSource.gallery);
    if (x == null) return;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('loading'))));

    final localPath = await StorageService.instance.importMedia(x.path);
    final info = await FfmpegService.instance.probe(localPath);
    final id = const Uuid().v4();
    final thumb = await FfmpegService.instance.thumbnail(localPath, atSec: (info.duration * 0.1).clamp(0, info.duration));
    final name = x.name.replaceAll(RegExp(r'\.[^.]+$'), '');

    final project = VideoProject(
      id: id,
      name: name.isEmpty ? 'Project $id'.substring(0, 10) : name,
      clips: [
        VideoClip(
          id: const Uuid().v4(),
          path: localPath,
          name: name,
          sourceDuration: info.duration,
        )
      ],
      thumbPath: thumb,
    );
    await StorageService.instance.saveProject(project);
    ref.invalidate(projectsProvider);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EditorScreen(projectId: id)));
  }

  Widget _projectsTab() {
    final projects = ref.watch(projectsProvider);
    final locale = ref.watch(settingsProvider).locale;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(gradient: AppColors.gradPrimary, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.content_cut, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('app_name'),
                          style: GoogleFonts.cairo(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(context.tr('tagline'),
                          style: GoogleFonts.cairo(fontSize: 12, color: AppColors.textDim)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(context.tr('my_projects'),
                style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Expanded(
              child: projects.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(context.tr('error_generic'))),
                data: (list) => list.isEmpty
                    ? _emptyState()
                    : RefreshIndicator(
                        onRefresh: () async => ref.invalidate(projectsProvider),
                        child: GridView.builder(
                          padding: const EdgeInsets.only(bottom: 100, top: 4),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
                          itemCount: list.length,
                          itemBuilder: (context, i) => _projectCard(list[i], locale),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.video_library_outlined, size: 48, color: AppColors.textDim),
            ),
            const SizedBox(height: 16),
            Text(context.tr('no_projects'), style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                context.tr('no_projects_hint'),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(fontSize: 13, color: AppColors.textDim),
              ),
            ),
          ],
        ),
      );

  Widget _projectCard(VideoProject p, String locale) {
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => EditorScreen(projectId: p.id))),
      onLongPress: () => _projectMenu(p),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: p.thumbPath.isNotEmpty && File(p.thumbPath).existsSync()
                    ? Image.file(File(p.thumbPath), fit: BoxFit.cover)
                    : Container(
                        color: AppColors.surface2,
                        child: const Icon(Icons.movie_outlined, color: AppColors.textDim, size: 40),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 3),
                  Text(
                    '${p.totalDuration.toStringAsFixed(0)} ${locale == 'ar' ? 'ثانية' : 'sec'} • ${p.captions.length} 📝',
                    style: GoogleFonts.cairo(fontSize: 11, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _projectMenu(VideoProject p) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text(context.tr('delete')),
              onTap: () async {
                Navigator.pop(ctx);
                await StorageService.instance.deleteProject(p.id);
                ref.invalidate(projectsProvider);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.tr('rename')),
              onTap: () async {
                Navigator.pop(ctx);
                _renameProject(p);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameProject(VideoProject p) async {
    final ctrl = TextEditingController(text: p.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('rename')),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('ok'))),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      p.name = ctrl.text.trim();
      await StorageService.instance.saveProject(p);
      ref.invalidate(projectsProvider);
    }
  }
}
