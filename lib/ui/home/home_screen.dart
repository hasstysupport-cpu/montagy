import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../core/app_colors.dart';
import '../../core/app_font.dart';
import '../../core/strings.dart';
import '../../data/models.dart';
import '../../services/projects_store.dart';
import '../editor/editor_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final SharedPreferences prefs;
  final ValueChanged<ThemeMode> onThemeChanged;
  final ThemeMode themeMode;
  const HomeScreen({
    super.key,
    required this.prefs,
    required this.onThemeChanged,
    required this.themeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Project> _projects = [];
  bool _loading = true;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    _projects = await ProjectsStore.listAll();
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.videos,
      Permission.photos,
      Permission.audio,
    ].request();
    final ok = statuses.values.any((s) => s.isGranted || s.isLimited);
    if (!ok) {
      // قد تكون الأذونات مرفوضة نهائياً
      final perm = await Permission.videos.status;
      if (perm.isPermanentlyDenied && mounted) {
        _showPermDialog();
      }
    }
    return true; // نكمل دائماً — منتقي الملفات يعمل دون أذونات
  }

  void _showPermDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.appName),
        content: const Text(S.mediaPermission),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text(S.openSettings),
          ),
        ],
      ),
    );
  }

  Future<void> _newProject({bool photos = false}) async {
    await _ensurePermissions();
    HapticFeedback.lightImpact();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: photos ? FileType.image : FileType.video,
        allowMultiple: true,
      );
      if (result == null || result.paths.isEmpty) return;
      final valid = result.paths.whereType<String>().toList();
      if (valid.isEmpty) return;

      if (!mounted) return;
      setState(() => _importing = true);

      final clips = await ProjectsStore.importFiles(valid);
      if (clips.isEmpty) {
        if (mounted) {
          setState(() => _importing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم نتمكن من استيراد الملفات المختارة')),
          );
        }
        return;
      }

      final project = Project(
        id: ProjectsStore.newId(),
        name: _projects.isEmpty ? 'مشروع جديد' : 'مشروع ${_projects.length + 1}',
        clips: clips,
      );
      await ProjectsStore.save(project);
      if (!mounted) return;
      setState(() => _importing = false);
      await _openEditor(project);
      _reload();
    } catch (e) {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _openEditor(Project project) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorScreen(project: project),
    ));
    _reload();
  }

  Future<void> _projectMenu(Project project) async {
    final controller = TextEditingController(text: project.name);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text(S.rename),
              onTap: () async {
                Navigator.pop(ctx);
                final name = await _renameDialog(project, controller);
                if (name != null && name.trim().isNotEmpty) {
                  project.name = name.trim();
                  await ProjectsStore.save(project);
                  _reload();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text(S.duplicate),
              onTap: () {
                Navigator.pop(ctx, 'dup');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: const Text(S.delete, style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx, 'del');
              },
            ),
          ],
        ),
      ),
    );
    if (action == 'dup') {
      final copy = Project.fromJson(
          jsonDecode(jsonEncode(project.toJson())) as Map<String, dynamic>);
      copy.name = '${S.copyOf} ${project.name}';
      await ProjectsStore.save(copy);
      _reload();
    } else if (action == 'del') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text(S.confirmDelete),
          content: Text(project.name),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(S.delete),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ProjectsStore.delete(project);
        _reload();
      }
    }
  }

  Future<String?> _renameDialog(Project project, TextEditingController controller) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(S.rename),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(S.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text(S.save)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── الهيدر ──
          SliverAppBar(
            expandedHeight: 168,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _Header(
                onSettings: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      prefs: widget.prefs,
                      themeMode: widget.themeMode,
                      onThemeChanged: widget.onThemeChanged,
                    ),
                  ));
                },
              ),
            ),
          ),

          // ── زر مشروع جديد ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _BigNewButton(
                      icon: Icons.movie_creation_outlined,
                      label: S.newProject,
                      sub: S.pickVideos,
                      onTap: () => _newProject(photos: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigNewButton(
                      icon: Icons.photo_library_outlined,
                      label: S.newProject,
                      sub: S.pickPhotos,
                      onTap: () => _newProject(photos: true),
                      accent: false,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── المشاريع ──
          if (!_loading && _projects.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(text: text),
            )
          else ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: _SectionTitle(S.projects),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 340,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final prj = _projects[i];
                    return _ProjectCard(
                      project: prj,
                      onTap: () => _openEditor(prj),
                      onLongPress: () => _projectMenu(prj),
                    );
                  },
                  childCount: _projects.length,
                ),
              ),
            ),
          ],
        ],
      ),
      // استيراد جارٍ
      bottomSheet: _importing
          ? Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 14),
                  Text('جارٍ استيراد الوسائط...',
                      style: AppFont.w(600, size: 14)),
                ],
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────
// عناصر الواجهة
// ─────────────────────────────────────────────

class _Header extends StatelessWidget {
  final VoidCallback onSettings;
  const _Header({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? AppColors.darkBg : AppColors.lightBg;
    final text = dark ? AppColors.darkText : AppColors.lightText;
    final dim = dark ? AppColors.darkTextDim : AppColors.lightTextDim;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [bg, const Color(0xFF0A1428), bg]
              : [bg, const Color(0xFFE9EFFB), bg],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const MontagyLogo(size: 46),
                  IconButton(
                    onPressed: onSettings,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: dark
                            ? AppColors.darkSurface
                            : AppColors.lightSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: dark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Icon(Icons.settings_outlined,
                          size: 20, color: text),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(S.appName, style: AppFont.w(900, size: 34, color: text)),
              const SizedBox(height: 4),
              Text(S.tagline, style: AppFont.w(500, size: 13, color: dim)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: context.accentGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: AppFont.w(800, size: 18)),
      ],
    );
  }
}

class _BigNewButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;
  final bool accent;
  const _BigNewButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
    this.accent = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: accent
                ? context.accentGradient
                : null,
            color: accent
                ? null
                : (dark ? AppColors.darkSurfaceHi : AppColors.lightSurface),
            border: accent
                ? null
                : Border.all(color: dark ? AppColors.darkBorder : AppColors.lightBorder),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent
                      ? Colors.white.withValues(alpha: 0.18)
                      : context.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent ? Colors.white : context.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: AppFont.w(800,
                            size: 15, color: accent ? Colors.white : null),
                        maxLines: 1),
                    Text(sub,
                        style: AppFont.w(500,
                            size: 11,
                            color: accent
                                ? Colors.white.withValues(alpha: 0.85)
                                : (dark
                                    ? AppColors.darkTextDim
                                    : AppColors.lightTextDim)),
                        maxLines: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _ProjectCard({
    required this.project,
    required this.onTap,
    required this.onLongPress,
  });

  String get _duration {
    var total = 0.0;
    for (final c in project.clips) {
      total += c.timelineDuration;
    }
    return S.durationLabel(total);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final thumb = project.clips.isNotEmpty ? project.clips.first.thumbPath : null;
    final hasThumb = thumb != null && File(thumb).existsSync();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: dark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSurfaceHi : AppColors.lightSurfaceHi,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasThumb
                      ? Image.file(File(thumb),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          cacheWidth: 320,
                          errorBuilder: (_, __, ___) => _fallback(context))
                      : _fallback(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(project.name,
                          style: AppFont.w(700, size: 13.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(_duration,
                        style: AppFont.w(600, size: 11, color: context.accent)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Icon(Icons.movie_outlined,
          size: 40,
          color: dark ? AppColors.darkTextDim : AppColors.lightTextDim),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final TextTheme text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  context.accent.withValues(alpha: 0.14),
                  AppColors.cyan.withValues(alpha: 0.10),
                ]),
                shape: BoxShape.circle,
              ),
              child: const MontagyLogo(size: 64),
            ),
            const SizedBox(height: 22),
            Text(S.noProjects, style: AppFont.w(800, size: 20)),
            const SizedBox(height: 8),
            Text(S.noProjectsHint,
                textAlign: TextAlign.center,
                style: AppFont.w(400,
                    size: 13,
                    color: dark ? AppColors.darkTextDim : AppColors.lightTextDim)),
          ],
        ),
      ),
    );
  }
}
