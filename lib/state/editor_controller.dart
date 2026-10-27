import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/audio_track.dart';
import '../models/caption.dart';
import '../models/overlay_item.dart';
import '../models/project.dart';
import '../models/transition.dart';
import '../services/storage_service.dart';

/// Live editing session state (project + playhead + selection + undo).
class EditorState {
  final VideoProject project;
  final double playhead; // timeline seconds
  final bool playing;
  final bool dirty;
  final int selectedCaptionIndex;
  final String? selectedOverlayId;
  final String activePanel; // '', 'captions', 'styles', 'text', 'stickers', 'filters', 'speed', 'audio', 'transitions', 'motion'
  final String? motionSceneJson; // applied AI scene (persisted into overlays by engine)
  final bool busy;
  final String busyLabel;

  const EditorState({
    required this.project,
    this.playhead = 0,
    this.playing = false,
    this.dirty = false,
    this.selectedCaptionIndex = -1,
    this.selectedOverlayId,
    this.activePanel = '',
    this.motionSceneJson,
    this.busy = false,
    this.busyLabel = '',
  });

  EditorState copyWith({
    VideoProject? project,
    double? playhead,
    bool? playing,
    bool? dirty,
    int? selectedCaptionIndex,
    String? selectedOverlayId,
    String? activePanel,
    String? motionSceneJson,
    bool? busy,
    String? busyLabel,
    bool clearOverlaySel = false,
    bool clearMotion = false,
  }) =>
      EditorState(
        project: project ?? this.project,
        playhead: playhead ?? this.playhead,
        playing: playing ?? this.playing,
        dirty: dirty ?? this.dirty,
        selectedCaptionIndex: selectedCaptionIndex ?? this.selectedCaptionIndex,
        selectedOverlayId: clearOverlaySel ? null : (selectedOverlayId ?? this.selectedOverlayId),
        activePanel: activePanel ?? this.activePanel,
        motionSceneJson: clearMotion ? null : (motionSceneJson ?? this.motionSceneJson),
        busy: busy ?? this.busy,
        busyLabel: busyLabel ?? this.busyLabel,
      );
}

class EditorController extends StateNotifier<EditorState> {
  final _uuid = const Uuid();
  final List<String> _undoStack = [];
  final List<String> _redoStack = [];

  EditorController(VideoProject project) : super(EditorState(project: project));

  // ---------------- Undo / Redo ----------------

  void _snapshot() {
    _undoStack.add(jsonEncode(state.project.toJson()));
    if (_undoStack.length > 25) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void mutate(void Function(VideoProject p) fn, {bool snapshot = true}) {
    if (snapshot) _snapshot();
    final p = state.project;
    fn(p);
    p.updatedAt = DateTime.now();
    state = state.copyWith(project: p, dirty: true);
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(jsonEncode(state.project.toJson()));
    final prev = VideoProject.fromJson(jsonDecode(_undoStack.removeLast()));
    state = state.copyWith(project: prev, dirty: true);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(jsonEncode(state.project.toJson()));
    final next = VideoProject.fromJson(jsonDecode(_redoStack.removeLast()));
    state = state.copyWith(project: next, dirty: true);
  }

  // ---------------- Playhead ----------------

  void setPlayhead(double t) => state = state.copyWith(playhead: t.clamp(0, state.project.totalDuration));
  void setPlaying(bool v) => state = state.copyWith(playing: v);
  void setBusy(bool v, [String label = '']) =>
      state = state.copyWith(busy: v, busyLabel: v ? label : '');
  void openPanel(String id) =>
      state = state.copyWith(activePanel: state.activePanel == id ? '' : id, clearOverlaySel: true);
  void selectCaption(int i) => state = state.copyWith(selectedCaptionIndex: i);
  void selectOverlay(String? id) => state = state.copyWith(selectedOverlayId: id, clearOverlaySel: false);

  // ---------------- Clips ----------------

  Future<void> addClip(VideoClip clip) => Future.microtask(() {
        mutate((p) {
          p.clips.add(clip);
        });
      });

  void splitAtPlayhead() {
    final t = state.playhead;
    final p = state.project;
    var cursor = 0.0;
    for (var i = 0; i < p.clips.length; i++) {
      final c = p.clips[i];
      final len = c.timelineLength;
      if (t > cursor + 0.2 && t < cursor + len - 0.2) {
        final localT = (t - cursor) * c.speed;
        final left = c.copyWith(trimEnd: c.trimStart + localT);
        final right = VideoClip(
          id: _uuid.v4(),
          path: c.path,
          name: c.name,
          sourceDuration: c.sourceDuration,
          trimStart: c.trimStart + localT,
          trimEnd: c.trimEnd,
          speed: c.speed,
          volume: c.volume,
          filterId: c.filterId,
          filterIntensity: c.filterIntensity,
          transitionToNext: c.transitionToNext,
        );
        mutate((p2) {
          p2.clips[i] = left;
          p2.clips.insert(i + 1, right);
        });
        return;
      }
      cursor += len;
    }
  }

  void deleteClip(int index) {
    if (state.project.clips.length <= 1) return;
    mutate((p) => p.clips.removeAt(index));
  }

  void updateClip(int index, void Function(VideoClip c) fn, {bool snapshot = true}) {
    mutate((p) {
      fn(p.clips[index]);
    }, snapshot: snapshot);
  }

  /// Index of the clip under the playhead (-1 when empty timeline).
  int clipIndexAtPlayhead() {
    final t = state.playhead;
    final p = state.project;
    var cursor = 0.0;
    for (var i = 0; i < p.clips.length; i++) {
      final len = p.clips[i].timelineLength;
      if (t < cursor + len || i == p.clips.length - 1) {
        if (t >= cursor - 0.001) return i;
      }
      cursor += len;
    }
    return p.clips.isEmpty ? -1 : 0;
  }

  /// Split the clip at [index] into segments at in-file time [marks]
  /// (used by silence/scene auto-cut).
  void autoSplitClip(int index, List<double> marks) {
    if (marks.isEmpty) return;
    mutate((p) {
      final c = p.clips[index];
      final bounds = <double>[c.trimStart, ...marks.where((m) => m > c.trimStart + 0.25 && m < c.trimEnd - 0.25), c.trimEnd];
      bounds.sort();
      final parts = <VideoClip>[];
      for (var i = 0; i < bounds.length - 1; i++) {
        parts.add(VideoClip(
          id: i == 0 ? c.id : _uuid.v4(),
          path: c.path,
          name: c.name,
          sourceDuration: c.sourceDuration,
          trimStart: bounds[i],
          trimEnd: bounds[i + 1],
          speed: c.speed,
          volume: c.volume,
          filterId: c.filterId,
          filterIntensity: c.filterIntensity,
          transitionToNext: i == bounds.length - 2 ? c.transitionToNext : Transitions.none,
        ));
      }
      p.clips
        ..removeAt(index)
        ..insertAll(index, parts);
    });
  }

  // ---------------- Captions ----------------

  void addCaption(CaptionSegment c) {
    mutate((p) {
      p.captions.add(c);
      p.captions.sort((a, b) => a.start.compareTo(b.start));
    });
  }

  void updateCaption(int index, void Function(CaptionSegment c) fn) {
    mutate((p) => fn(p.captions[index]));
  }

  void deleteCaption(int index) => mutate((p) => p.captions.removeAt(index));

  void setAllCaptions(List<CaptionSegment> segs) {
    mutate((p) {
      p.captions
        ..clear()
        ..addAll(segs);
    });
  }

  void setCaptionStyleEverywhere(String styleId) {
    mutate((p) {
      p.captionStyleId = styleId;
      for (final c in p.captions) {
        c.styleId = styleId;
      }
    });
  }

  // ---------------- Overlays ----------------

  void addOverlay(OverlayItem o) => mutate((p) => p.overlays.add(o));

  void updateOverlay(String id, void Function(OverlayItem o) fn, {bool snapshot = true}) {
    mutate((p) {
      final i = p.overlays.indexWhere((o) => o.id == id);
      if (i != -1) fn(p.overlays[i]);
    }, snapshot: snapshot);
  }

  void deleteOverlay(String id) => mutate((p) => p.overlays.removeWhere((o) => o.id == id));

  void applyMotionSceneJson(String json) {
    mutate((p) {
      // Overlays are generated by the engine at render time from the scene.
    });
    state = state.copyWith(motionSceneJson: json);
  }

  // ---------------- Audio ----------------

  void addAudioTrack(AudioTrack t) => mutate((p) => p.audioTracks.add(t));
  void removeAudioTrack(String id) => mutate((p) => p.audioTracks.removeWhere((a) => a.id == id));
  void updateAudio(String id, void Function(AudioTrack a) fn, {bool snapshot = true}) {
    mutate((p) {
      final i = p.audioTracks.indexWhere((a) => a.id == id);
      if (i != -1) fn(p.audioTracks[i]);
    }, snapshot: snapshot);
  }

  // ---------------- Persistence ----------------

  Future<void> save() async {
    await StorageService.instance.saveProject(state.project);
    state = state.copyWith(dirty: false);
  }
}

final editorProvider =
    StateNotifierProvider<EditorController, EditorState>((ref) => throw UnimplementedError('override in editor route'));
