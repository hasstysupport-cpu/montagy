import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

import '../data/color_engine.dart';
import '../data/models.dart';
import '../services/ffmpeg_gateway.dart';
import '../services/projects_store.dart';

/// الحالة المركزية للمحرر — تشغيل + تعديلات + تايم لاين + صوت.
class EditorState extends ChangeNotifier {
  Project project;

  EditorState(this.project) {
    _initPlayback();
  }

  // ── تحديد ──
  String? selectedClipId;
  String? selectedTextId;
  String? selectedStickerId;

  ClipItem? get selectedClip =>
      project.clips.firstWhereOrNull((c) => c.id == selectedClipId);
  TextOverlay? get selectedText =>
      project.texts.firstWhereOrNull((t) => t.id == selectedTextId);
  ImageOverlay? get selectedSticker =>
      project.overlays.firstWhereOrNull((s) => s.id == selectedStickerId);

  void selectClip(String? id) {
    selectedClipId = id;
    if (id != null) {
      selectedTextId = null;
      selectedStickerId = null;
    }
    notifyListeners();
  }

  /// إلغاء كل التحديد (زر ✕ في شريط الأدوات).
  void clearSelection() {
    selectedClipId = null;
    selectedTextId = null;
    selectedStickerId = null;
    notifyListeners();
  }

  void selectText(String? id) {
    selectedTextId = id;
    if (id != null) {
      selectedClipId = null;
      selectedStickerId = null;
    }
    notifyListeners();
  }

  void selectSticker(String? id) {
    selectedStickerId = id;
    if (id != null) {
      selectedClipId = null;
      selectedTextId = null;
    }
    notifyListeners();
  }

  // ── حسابات التايم لاين (مع الانتقالات) ──

  bool _hasTransition(int i) =>
      i >= 0 &&
      i < project.clips.length - 1 &&
      project.clips[i].transitionOutId != null;

  double _transitionDur(int i) {
    if (!_hasTransition(i)) return 0;
    final d = project.clips[i].transitionDuration.clamp(0.15, 2.0);
    // الانتقال لا يتجاوز نصف أي من المقطعين
    final a = project.clips[i].timelineDuration;
    final b = project.clips[i + 1].timelineDuration;
    return d.clamp(0.15, (a < b ? a : b) / 2.2).toDouble();
  }

  /// بداية كل مقطع على التايم لاين.
  List<double> get clipStarts {
    final out = <double>[];
    var t = 0.0;
    for (var i = 0; i < project.clips.length; i++) {
      out.add(t);
      t += project.clips[i].timelineDuration - _transitionDur(i);
    }
    return out;
  }

  double get totalDuration {
    if (project.clips.isEmpty) return 0;
    final starts = clipStarts;
    return starts.last + project.clips.last.timelineDuration;
  }

  int clipIndexAt(double t) {
    final starts = clipStarts;
    for (var i = starts.length - 1; i >= 0; i--) {
      if (t >= starts[i] - 0.0001) return i;
    }
    return 0;
  }

  // ── التشغيل ──
  bool playing = false;
  double projectTime = 0;
  int currentClipIndex = 0;
  bool get isBusy => _activating;

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, AudioPlayer> _musicPlayers = {};
  final Set<String> _musicLoading = {};
  Timer? _ticker;
  final Stopwatch _clock = Stopwatch();
  bool _activating = false;

  VideoPlayerController? controllerFor(ClipItem clip) => _controllers[clip.id];

  Future<VideoPlayerController> _controllerFor(ClipItem clip) async {
    var c = _controllers[clip.id];
    if (c == null) {
      c = VideoPlayerController.file(File(clip.sourcePath));
      _controllers[clip.id] = c;
      try {
        await c.initialize();
      } catch (_) {
        // نتركه — المعاينة ستظهر الصورة المصغرة
      }
    }
    return c;
  }

  Future<void> _initPlayback() async {
    if (project.clips.isEmpty) return;
    // نسخة احتياطية للصور المصغرة المفقودة
    for (final c in project.clips) {
      if (c.type == MediaType.video && (c.outPoint <= c.inPoint)) {
        c.outPoint = c.sourceDuration > 0 ? c.sourceDuration : c.inPoint + 1;
      }
      if (!File(c.sourcePath).existsSync()) {
        // نتجاهل بصمت — الفلتر أدناه يزيله
      }
    }
    project.clips.removeWhere((c) => !File(c.sourcePath).existsSync());
    await _activateClip(0, autoplay: false);
    _clock.start();
  }

  Future<void> _activateClip(int index, {bool? autoplay}) async {
    if (index < 0 || index >= project.clips.length) return;
    _activating = true;
    final clip = project.clips[index];
    final starts = clipStarts;
    final localT = (projectTime - (index < starts.length ? starts[index] : 0))
        .clamp(0.0, clip.timelineDuration);

    // أوقف بقية المتحكمات
    for (final e in _controllers.entries) {
      if (e.key != clip.id && e.value.value.isPlaying) {
        try { await e.value.pause(); } catch (_) {}
      }
    }

    currentClipIndex = index;
    if (clip.type == MediaType.video) {
      final ctrl = await _controllerFor(clip);
      if (_controllers[clip.id] == ctrl) {
        final srcPos = clip.inPoint + localT * clip.speed;
        try {
          await ctrl.seekTo(Duration(milliseconds: (srcPos * 1000).round()));
          await ctrl.setPlaybackSpeed(clip.speed.clamp(0.25, 4));
          await ctrl.setVolume(clip.muted ? 0.0 : clip.volume.clamp(0, 2));
          final shouldPlay = autoplay ?? playing;
          if (shouldPlay) {
            await ctrl.play();
          } else {
            await ctrl.pause();
          }
        } catch (_) {}
      }
    }
    _activating = false;
    notifyListeners();
  }

  void _startTicker() {
    _ticker?.cancel();
    _clock.reset();
    _clock.start();
    _ticker = Timer.periodic(const Duration(milliseconds: 40), (_) => _onTick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick() {
    if (!playing || project.clips.isEmpty) return;
    final dt = _clock.elapsedMilliseconds / 1000.0;
    _clock.reset();

    final starts = clipStarts;
    final i = currentClipIndex;
    if (i >= project.clips.length) {
      pause();
      return;
    }
    final clip = project.clips[i];
    final clipStart = starts[i];
    final clipDur = clip.timelineDuration;

    if (clip.type == MediaType.video) {
      final ctrl = _controllers[clip.id];
      if (ctrl != null && ctrl.value.isInitialized) {
        final pos = ctrl.value.position.inMilliseconds / 1000.0;
        final local = ((pos - clip.inPoint) / clip.speed)
            .clamp(0.0, clipDur)
            .toDouble();
        projectTime = clipStart + local;
        // استئناف إن توقف تلقائياً (نهاية المخزن المؤقت)
        if (playing && !ctrl.value.isPlaying && local < clipDur - 0.05) {
          try { ctrl.play(); } catch (_) {}
        }
      } else {
        projectTime += dt;
      }
    } else {
      projectTime = (projectTime + dt).clamp(clipStart, clipStart + clipDur);
    }

    // عبور الحدود
    if (projectTime >= clipStart + clipDur - 0.001) {
      if (i >= project.clips.length - 1) {
        projectTime = totalDuration;
        playing = false;
        _stopTicker();
        _pauseAllControllers();
        _syncMusic();
        notifyListeners();
        return;
      }
      _activateClip(i + 1);
    }

    _syncMusic();
    notifyListeners();
  }

  void _pauseAllControllers() {
    for (final c in _controllers.values) {
      try { c.pause(); } catch (_) {}
    }
  }

  Future<void> play() async {
    if (project.clips.isEmpty) return;
    if (projectTime >= totalDuration - 0.03) {
      projectTime = 0;
      await _activateClip(0, autoplay: true);
    } else if (project.clips[currentClipIndex].type == MediaType.video) {
      final ctrl = _controllers[project.clips[currentClipIndex].id];
      if (ctrl != null) {
        try { await ctrl.play(); } catch (_) {}
      }
    }
    playing = true;
    _startTicker();
    _syncMusic();
    notifyListeners();
  }

  Future<void> pause() async {
    playing = false;
    _stopTicker();
    _pauseAllControllers();
    _syncMusic();
    notifyListeners();
  }

  Future<void> togglePlay() => playing ? pause() : play();

  Future<void> seekTo(double t) async {
    final total = totalDuration;
    projectTime = t.clamp(0, total).toDouble();
    final i = clipIndexAt(projectTime);
    if (i != currentClipIndex || !playing) {
      await _activateClip(i, autoplay: playing);
    } else {
      final clip = project.clips[i];
      if (clip.type == MediaType.video) {
        final ctrl = _controllers[clip.id];
        if (ctrl != null) {
          final local = projectTime - clipStarts[i];
          final srcPos = clip.inPoint + local * clip.speed;
          try {
            await ctrl.seekTo(Duration(milliseconds: (srcPos * 1000).round()));
          } catch (_) {}
        }
      }
    }
    _syncMusic();
    notifyListeners();
  }

  // ── موسيقى ──

  Future<AudioPlayer?> _musicPlayerFor(AudioTrack track) async {
    if (_musicLoading.contains(track.id)) return null;
    var p = _musicPlayers[track.id];
    if (p == null) {
      _musicLoading.add(track.id);
      try {
        p = AudioPlayer();
        await p.setFilePath(track.path);
        _musicPlayers[track.id] = p;
      } catch (_) {
        try { p?.dispose(); } catch (_) {}
        p = null;
      } finally {
        _musicLoading.remove(track.id);
      }
    }
    return p;
  }

  Future<void> _syncMusic() async {
    for (final track in project.audio) {
      final p = await _musicPlayerFor(track);
      if (p == null) continue;
      final trackEnd = track.startAt + track.duration;
      final active = projectTime >= track.startAt && projectTime < trackEnd;
      try {
        if (playing && active) {
          final offset = track.inPoint + (projectTime - track.startAt);
          final cur = p.position.inMilliseconds / 1000.0;
          if (!p.playing) {
            await p.seek(Duration(milliseconds: (offset * 1000).round()));
            await p.setVolume(track.volume.clamp(0, 2));
            await p.play();
          } else if ((cur - offset).abs() > 0.45) {
            await p.seek(Duration(milliseconds: (offset * 1000).round()));
          }
        } else {
          if (p.playing) await p.pause();
        }
      } catch (_) {}
    }
  }

  // ── عمليات التعديل ──

  Future<void> addClips(List<ClipItem> newClips, {bool select = true}) async {
    pushUndo();
    project.clips.addAll(newClips);
    if (select && newClips.isNotEmpty) selectedClipId = newClips.last.id;
    if (project.clips.length == newClips.length) {
      await _activateClip(0, autoplay: false);
      projectTime = 0;
    }
    _autosave();
    notifyListeners();
  }

  Future<void> insertClipAt(ClipItem clip, int index) async {
    pushUndo();
    project.clips.insert(index.clamp(0, project.clips.length), clip);
    selectedClipId = clip.id;
    _autosave();
    notifyListeners();
  }

  bool get canSplit {
    if (project.clips.isEmpty) return false;
    final i = clipIndexAt(projectTime);
    final start = clipStarts[i];
    final end = start + project.clips[i].timelineDuration;
    return projectTime > start + 0.12 && projectTime < end - 0.12;
  }

  /// تقسيم المقطع عند المؤشر.
  Future<void> splitAtPlayhead() async {
    if (!canSplit) return;
    pushUndo();
    final i = clipIndexAt(projectTime);
    final clip = project.clips[i];
    final local = projectTime - clipStarts[i];
    final cutSource = clip.inPoint + local * clip.speed;

    final left = clip.copyWith(
        outPoint: cutSource.clamp(clip.inPoint + 0.05, clip.outPoint - 0.05));
    final right = clip.copyWith(
        inPoint: cutSource.clamp(clip.inPoint + 0.05, clip.outPoint - 0.05));
    // الانتقال يبقى مع المقطع الأيسر
    project.clips[i] = left;
    project.clips.insert(i + 1, right);
    selectedClipId = right.id;
    _autosave();
    notifyListeners();
  }

  void deleteClip(ClipItem clip) {
    if (project.clips.length <= 1) return;
    pushUndo();
    project.clips.remove(clip);
    _controllers.remove(clip.id)?.dispose();
    // إزالة تراكب الصوت المستخرج المرتبط (اختياري: نبقيه)
    if (currentClipIndex >= project.clips.length) {
      currentClipIndex = project.clips.length - 1;
    }
    if (selectedClipId == clip.id) selectedClipId = null;
    projectTime = projectTime.clamp(0, totalDuration).toDouble();
    _activateClip(clipIndexAt(projectTime), autoplay: playing);
    _autosave();
    notifyListeners();
  }

  void duplicateClip(ClipItem clip) {
    pushUndo();
    final idx = project.clips.indexOf(clip);
    final copy = ClipItem.fromJson(_snapshotClip(clip));
    copy.transitionOutId = null;
    project.clips.insert(idx + 1, copy);
    selectedClipId = copy.id;
    _autosave();
    notifyListeners();
  }

  Map<String, dynamic> _snapshotClip(ClipItem c) {
    final j = c.toJson();
    j['id'] = ProjectsStore.newId();
    return j;
  }

  void moveClip(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= project.clips.length) return;
    pushUndo();
    if (newIndex > oldIndex) newIndex--;
    final clip = project.clips.removeAt(oldIndex);
    project.clips.insert(newIndex.clamp(0, project.clips.length), clip);
    _activateClip(clipIndexAt(projectTime), autoplay: playing);
    _autosave();
    notifyListeners();
  }

  /// إعادة ترتيب حية أثناء السحب الطويل — بدون تعبئة التراجع (نستدعي
  /// beginUndoGroup مرة عند بدء السحب).
  void reorderLive(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= project.clips.length) return;
    if (newIndex < 0 || newIndex >= project.clips.length) return;
    if (oldIndex == newIndex) return;
    final clip = project.clips.removeAt(oldIndex);
    project.clips.insert(newIndex, clip);
    currentClipIndex = newIndex;
    _autosave();
    notifyListeners();
  }

  void updateClip(ClipItem clip,
      {bool seekAfter = false, bool structural = false}) {
    if (structural) pushUndo();
    final i = project.clips.indexOf(clip);
    if (i >= 0) project.clips[i] = clip;
    final active = currentClipIndex == i;
    if (active && clip.type == MediaType.video) {
      final ctrl = _controllers[clip.id];
      if (ctrl != null && ctrl.value.isInitialized) {
        try {
          ctrl.setPlaybackSpeed(clip.speed.clamp(0.25, 4));
          ctrl.setVolume(clip.muted ? 0.0 : clip.volume.clamp(0, 2));
          if (seekAfter) {
            final local = (projectTime - clipStarts[i])
                .clamp(0.0, clip.timelineDuration);
            final srcPos = clip.inPoint + local * clip.speed;
            ctrl.seekTo(Duration(milliseconds: (srcPos * 1000).round()));
          }
        } catch (_) {}
      }
    }
    _autosave();
    notifyListeners();
  }

  void applyFilterToAll(String? presetId, double intensity) {
    pushUndo();
    for (final c in project.clips) {
      project.clips[project.clips.indexOf(c)] =
          c.copyWith(filterPreset: presetId, filterIntensity: intensity);
    }
    _autosave();
    notifyListeners();
  }

  /// استخراج الصوت من مقطع فيديو إلى تراك صوتي مستقل.
  Future<bool> extractAudio(ClipItem clip) async {
    if (clip.type != MediaType.video) return false;
    final idx = project.clips.indexOf(clip);
    final startAt = idx >= 0 && idx < clipStarts.length ? clipStarts[idx] : 0;

    final dir = await ProjectsStore.mediaDir();
    final outPath = '${dir.path}/${ProjectsStore.newId()}.m4a';

    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-i', clip.sourcePath,
      '-vn',
      '-ac', '2',
      '-ar', '44100',
      '-c:a', 'aac',
      '-b:a', '160k',
      outPath,
    ]);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) return false;
    if (!File(outPath).existsSync()) return false;

    // مدة الصوت من الملف الناتج
    var dur = clip.trimDuration;
    try {
      final probe = await FFprobeKit.getMediaInformation(outPath);
      final info = probe.getMediaInformation();
      final d = double.tryParse(info?.getDuration() ?? '');
      if (d != null && d > 0) dur = d;
    } catch (_) {}

    addAudio(AudioTrack(
      id: ProjectsStore.newId(),
      path: outPath,
      kind: AudioKind.extracted,
      title: 'صوت: ${clip.title}',
      startAt: startAt.clamp(0.0, totalDuration).toDouble(),
      inPoint: 0,
      outPoint: dur,
      volume: 1,
    ));
    return true;
  }

  /// تجميد الإطار الحالي للمؤشر — يضيف صورة بعد المقطع النشط.
  Future<bool> freezeFrameAtPlayhead() async {
    if (project.clips.isEmpty) return false;
    final i = clipIndexAt(projectTime);
    final clip = project.clips[i];
    if (clip.type != MediaType.video) return false;
    final starts = clipStarts;
    final localT =
        (projectTime - starts[i]).clamp(0.0, clip.timelineDuration);
    final srcPos = clip.inPoint + localT * clip.speed;

    final tmp = await ProjectsStore.thumbsDir();
    final outPath = '${tmp.path}/${ProjectsStore.newId()}.png';

    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-ss', srcPos.toStringAsFixed(3),
      '-i', clip.sourcePath,
      '-frames:v', '1',
      '-q:v', '2',
      outPath,
    ]);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) return false;
    if (!File(outPath).existsSync()) return false;

    final photo = ClipItem(
      id: ProjectsStore.newId(),
      type: MediaType.photo,
      sourcePath: outPath,
      title: 'إطار مجمد',
      photoDuration: 1,
      sourceDuration: 1,
      hasAudio: false,
      thumbPath: outPath,
      filterPreset: clip.filterPreset,
      filterIntensity: clip.filterIntensity,
      adjust: clip.adjust,
    );
    await insertClipAt(photo, i + 1);
    return true;
  }

  /// استبدال مصدر المقطع بملف جديد مع الحفاظ على المكانه والتعديلات.
  Future<bool> replaceClipSource(ClipItem clip, String newPath, String title) async {
    final i = project.clips.indexOf(clip);
    if (i < 0) return false;
    pushUndo();
    // فحص الملف الجديد
    double? dur;
    try {
      final probe = await FFprobeKit.getMediaInformation(newPath);
      final info = probe.getMediaInformation();
      dur = double.tryParse(info?.getDuration() ?? '');
    } catch (_) {}
    if (dur == null || dur <= 0) return false;

    final isVideo = !newPath.toLowerCase().endsWith(('.jpg')) &&
        !newPath.toLowerCase().endsWith('.jpeg') &&
        !newPath.toLowerCase().endsWith('.png') &&
        !newPath.toLowerCase().endsWith('.webp');

    final thumb = await ProjectsStore.makeThumb(newPath, maxHeight: 288);
    final old = project.clips[i];
    final replacement = ClipItem(
      id: old.id,
      type: isVideo ? MediaType.video : MediaType.photo,
      sourcePath: newPath,
      title: title,
      inPoint: 0,
      outPoint: isVideo ? dur : old.outPoint,
      photoDuration: old.photoDuration,
      speed: old.speed,
      volume: old.volume,
      muted: old.muted,
      rotation: old.rotation,
      flipH: old.flipH,
      flipV: old.flipV,
      crop: old.crop,
      filterPreset: old.filterPreset,
      filterIntensity: old.filterIntensity,
      adjust: old.adjust,
      transitionOutId: old.transitionOutId,
      transitionDuration: old.transitionDuration,
      sourceDuration: dur,
      sourceSize: old.sourceSize,
      hasAudio: isVideo,
      thumbPath: thumb,
    );
    _controllers.remove(old.id)?.dispose();
    project.clips[i] = replacement;
    selectedClipId = replacement.id;
    await _activateClip(i, autoplay: false);
    _autosave();
    notifyListeners();
    return true;
  }

  void setAspect(AspectKind kind) {
    project.canvas.aspect = kind;
    _autosave();
    notifyListeners();
  }

  void setCanvasBg(CanvasBg bg, {Color? color}) {
    project.canvas.bg = bg;
    if (color != null) project.canvas.customColor = color;
    _autosave();
    notifyListeners();
  }

  // ── النصوص ──

  void addText(TextOverlay t) {
    pushUndo();
    project.texts.add(t);
    selectedTextId = t.id;
    selectedClipId = null;
    selectedStickerId = null;
    _autosave();
    notifyListeners();
  }

  void updateText(TextOverlay t) {
    final i = project.texts.indexOf(t);
    if (i >= 0) project.texts[i] = t;
    _autosave();
    notifyListeners();
  }

  void deleteText(TextOverlay t) {
    pushUndo();
    project.texts.remove(t);
    if (selectedTextId == t.id) selectedTextId = null;
    _autosave();
    notifyListeners();
  }

  void duplicateText(TextOverlay t) {
    pushUndo();
    final j = t.toJson();
    j['id'] = ProjectsStore.newId();
    final copy = TextOverlay.fromJson(j);
    copy.nx = (copy.nx + 0.05).clamp(0.05, 0.95);
    project.texts.add(copy);
    selectedTextId = copy.id;
    _autosave();
    notifyListeners();
  }

  // ── الملصقات ──

  void addSticker(ImageOverlay s) {
    pushUndo();
    project.overlays.add(s);
    selectedStickerId = s.id;
    selectedClipId = null;
    selectedTextId = null;
    _autosave();
    notifyListeners();
  }

  void updateSticker(ImageOverlay s) {
    final i = project.overlays.indexOf(s);
    if (i >= 0) project.overlays[i] = s;
    _autosave();
    notifyListeners();
  }

  void deleteSticker(ImageOverlay s) {
    pushUndo();
    project.overlays.remove(s);
    if (selectedStickerId == s.id) selectedStickerId = null;
    _autosave();
    notifyListeners();
  }

  // ── الصوت ──

  void addAudio(AudioTrack track) {
    pushUndo();
    project.audio.add(track);
    _autosave();
    notifyListeners();
  }

  void updateAudio(AudioTrack t) {
    final i = project.audio.indexOf(t);
    if (i >= 0) project.audio[i] = t;
    final p = _musicPlayers[t.id];
    if (p != null) {
      try { p.setVolume(t.volume.clamp(0, 2)); } catch (_) {}
    }
    _syncMusic();
    _autosave();
    notifyListeners();
  }

  void deleteAudio(AudioTrack t) {
    pushUndo();
    project.audio.remove(t);
    _musicPlayers.remove(t.id)?.dispose();
    _autosave();
    notifyListeners();
  }

  /// تحديث مسارات التراكات الصوتية بعد تغيير التايم لاين (قص/حذف).
  void relinkAudioPositions() {
    // التراكات مستقلة عن المقاطع — لا شيء مطلوب حالياً
  }

  // ── التراجع والإعادة ──
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  /// بدء مجموعة تعديل (نستدعيها مرة عند بداية السحب وليس مع كل إطار).
  void beginUndoGroup() => pushUndo();

  void pushUndo() {
    try {
      _undoStack.add(_encodeProject());
      if (_undoStack.length > 20) _undoStack.removeAt(0);
      _redoStack.clear();
    } catch (_) {}
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final raw = _redoStack.removeLast();
    try {
      final restored = _decodeProject(raw);
      if (restored != null) {
        _undoStack.add(_encodeProject());
        await pause();
        project = restored;
        selectedClipId = null;
        selectedTextId = null;
        selectedStickerId = null;
        final ids = project.clips.map((c) => c.id).toSet();
        _controllers.removeWhere((k, v) {
          if (!ids.contains(k)) {
            try { v.dispose(); } catch (_) {}
            return true;
          }
          return false;
        });
        projectTime = projectTime.clamp(0, totalDuration).toDouble();
        await _activateClip(clipIndexAt(projectTime), autoplay: false);
        _autosave();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final raw = _undoStack.removeLast();
    try {
      final restored = _decodeProject(raw);
      if (restored != null) {
        // الحالة الحالية تذهب لمكدس الإعادة
        try { _redoStack.add(_encodeProject()); } catch (_) {}
        await pause();
        project = restored;
        selectedClipId = null;
        selectedTextId = null;
        selectedStickerId = null;
        // حرر المتحكمات غير الموجودة
        final ids = project.clips.map((c) => c.id).toSet();
        _controllers.removeWhere((k, v) {
          if (!ids.contains(k)) {
            try { v.dispose(); } catch (_) {}
            return true;
          }
          return false;
        });
        projectTime = projectTime.clamp(0, totalDuration).toDouble();
        await _activateClip(clipIndexAt(projectTime), autoplay: false);
        _autosave();
        notifyListeners();
      }
    } catch (_) {}
  }

  String _encodeProject() {
    return projectToJsonString(project);
  }

  Project? _decodeProject(String raw) {
    try {
      return projectFromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  // ── الحفظ التلقائي ──
  Timer? _saveDebounce;

  void _autosave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 900), () {
      ProjectsStore.save(project);
    });
  }

  Future<void> saveNow() => ProjectsStore.save(project);

  // ── التنظيف ──

  @override
  void dispose() {
    _stopTicker();
    for (final c in _controllers.values) {
      try { c.dispose(); } catch (_) {}
    }
    for (final p in _musicPlayers.values) {
      try { p.dispose(); } catch (_) {}
    }
    _saveDebounce?.cancel();
    super.dispose();
  }

  // ── أدوات مساعدة للمعاينة ──

  Iterable<TextOverlay> activeTexts(double t) =>
      project.texts.where((x) => t >= x.start && t <= x.end);

  Iterable<ImageOverlay> activeStickers(double t) =>
      project.overlays.where((x) => t >= x.start && t <= x.end);

  /// مصفوفة الفلتر الحالية للمقطع النشط.
  List<double>? activeFilterMatrix(ClipItem clip) {
    if (clip.filterPreset == null && clip.adjust.isNeutral) return null;
    return ColorFilterResolver.previewMatrix(
      presetId: clip.filterPreset,
      intensity: clip.filterIntensity,
      adjust: clip.adjust,
    );
  }

  double activeVignette(ClipItem clip) => ColorFilterResolver.vignetteOf(
        presetId: clip.filterPreset,
        intensity: clip.filterIntensity,
        adjust: clip.adjust,
      );
}

/// ترميز/فك مشروع.
String projectToJsonString(Project p) => jsonEncode(p.toJson());

Project? projectFromJsonString(String raw) {
  try {
    return Project.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

extension FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
