import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vault_audio.dart';
import '../presentation/vault_audio_controller.dart';
import 'audio_engine.dart';

/// Builds the engine the playback controller drives.
///
/// A provider rather than a static field so a widget test overrides it once
/// with [FakeVaultAudioEngine.new] and every path below plays without sound.
final vaultAudioEngineFactoryProvider = Provider<VaultAudioEngine Function()>(
  (ref) => AudioplayersVaultAudioEngine.new,
);

/// Everything the player UI renders: what is queued, what is playing, and how.
///
/// Immutable. [queue] is the stored order the vault lists; [playOrder] is the
/// same tracks in the order playback will take them (the stored order, or its
/// shuffle). [currentId] is the cursor into [playOrder].
@immutable
class VaultAudioPlaybackState {
  const VaultAudioPlaybackState({
    this.queue = const <VaultAudio>[],
    this.playOrder = const <VaultAudio>[],
    this.currentId,
    this.position = Duration.zero,
    this.duration,
    this.playing = false,
    this.loading = false,
    this.error,
    this.shuffled = false,
    this.repeat = RepeatMode.off,
  });

  final List<VaultAudio> queue;
  final List<VaultAudio> playOrder;
  final String? currentId;
  final Duration position;
  final Duration? duration;
  final bool playing;
  final bool loading;
  final String? error;
  final bool shuffled;
  final RepeatMode repeat;

  bool get hasQueue => queue.isNotEmpty;

  /// The track at the cursor, from the freshest [queue] copy.
  VaultAudio? get current {
    final id = currentId;
    if (id == null) return null;
    for (final audio in queue) {
      if (audio.id == id) return audio;
    }
    return null;
  }

  VaultAudioPlaybackState copyWith({
    List<VaultAudio>? queue,
    List<VaultAudio>? playOrder,
    String? currentId,
    bool clearCurrent = false,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    bool? playing,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? shuffled,
    RepeatMode? repeat,
  }) {
    return VaultAudioPlaybackState(
      queue: queue ?? this.queue,
      playOrder: playOrder ?? this.playOrder,
      currentId: clearCurrent ? null : (currentId ?? this.currentId),
      position: position ?? this.position,
      duration: clearDuration ? null : (duration ?? this.duration),
      playing: playing ?? this.playing,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      shuffled: shuffled ?? this.shuffled,
      repeat: repeat ?? this.repeat,
    );
  }
}

/// The app's one playback session: queue, cursor, shuffle, repeat, and engine.
///
/// It owns the engine rather than the player screen, so leaving the page does
/// not stop the sound — the screen is only a view over this state, and the
/// Android foreground service (see `vault_audio_handler.dart`) keeps the
/// process alive while a track plays. Non-autoDispose: the session lives as
/// long as the app, not as long as the page.
///
/// Every public method is safe to call before anything is queued; the state
/// simply stays empty.
class VaultAudioPlaybackController extends Notifier<VaultAudioPlaybackState> {
  /// Sound less than this from the end reads as "at the end" — the engine
  /// reports completion a beat late.
  static const Duration endTolerance = Duration(milliseconds: 1500);

  VaultAudioEngine? _engine;
  VaultAudioQueue _order = VaultAudioQueue(const <String>[]);
  final Map<String, VaultAudio> _byId = <String, VaultAudio>{};

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  /// True while swapping tracks, so the engine's stop echo is not read as end.
  bool _switching = false;

  /// Last reported playing value; a `false` arriving near the end of a playing
  /// track is how `onPlayerComplete` arrives.
  bool _wasPlaying = false;

  /// Bumped per load so a slow decrypt from an abandoned track cannot land.
  int _loadToken = 0;

  /// Set in `onDispose`; `Ref.mounted` does not exist on Riverpod 2.6's `Ref`.
  bool _disposed = false;

  @override
  VaultAudioPlaybackState build() {
    ref.onDispose(() {
      _disposed = true;
      _positionSub?.cancel();
      _durationSub?.cancel();
      _playingSub?.cancel();
      final engine = _engine;
      _engine = null;
      if (engine != null) unawaited(engine.dispose());
    });
    return const VaultAudioPlaybackState();
  }

  bool get _alive => !_disposed;

  VaultAudioEngine _ensureEngine() {
    final existing = _engine;
    if (existing != null) return existing;
    final engine = ref.read(vaultAudioEngineFactoryProvider)();
    _engine = engine;
    _positionSub = engine.onPositionChanged.listen((position) {
      if (!_alive) return;
      state = state.copyWith(position: position);
    });
    _durationSub = engine.onDurationChanged.listen((duration) {
      if (!_alive || duration == null) return;
      state = state.copyWith(duration: duration);
    });
    _playingSub = engine.onPlayingChanged.listen(_onPlayingEvent);
    return engine;
  }

  bool get _isAtEnd {
    final duration = state.duration;
    if (duration == null || duration <= Duration.zero) return false;
    return state.position >= duration - endTolerance;
  }

  void _onPlayingEvent(bool playing) {
    if (!_alive || _switching) {
      _wasPlaying = playing;
      return;
    }
    if (!playing && _wasPlaying && _isAtEnd) {
      _wasPlaying = false;
      unawaited(_onTrackEnd());
      return;
    }
    _wasPlaying = playing;
    state = state.copyWith(playing: playing);
  }

  /// Replaces the queue with [tracks] and starts at [index].
  ///
  /// This is what a tap on a list row does: the list you touched becomes the
  /// session. Resets shuffle; repeat is kept.
  Future<void> playFromList(List<VaultAudio> tracks, int index) async {
    if (tracks.isEmpty) return;
    _byId
      ..clear()
      ..addEntries(tracks.map((a) => MapEntry(a.id, a)));
    _order = VaultAudioQueue(tracks.map((a) => a.id).toList());
    _order.repeat = state.repeat;
    _order.index = index;
    state = state.copyWith(
      queue: List<VaultAudio>.unmodifiable(tracks),
      playOrder: _playOrderList(),
      currentId: _order.current,
      position: Duration.zero,
      clearDuration: true,
      shuffled: false,
      clearError: true,
    );
    await _load();
  }

  /// Opens the player on [id] without disturbing the queue.
  ///
  /// Used when a tapped row is already in the session, so returning to the
  /// library and tapping a queued track resumes it instead of rebuilding the
  /// queue.
  Future<void> jumpTo(String id) async {
    if (!_byId.containsKey(id)) return;
    _order.jumpTo(id);
    state = state.copyWith(currentId: _order.current);
    await _load();
  }

  bool contains(String id) => _byId.containsKey(id);

  /// Appends [tracks] to the session queue.
  ///
  /// Ids already queued are skipped. With nothing loaded yet the first added
  /// track starts playing; otherwise the queue grows behind the current track.
  Future<void> addToQueue(List<VaultAudio> tracks) async {
    final added = <VaultAudio>[];
    for (final audio in tracks) {
      if (_byId.containsKey(audio.id)) continue;
      _byId[audio.id] = audio;
      _order.append(audio.id);
      added.add(audio);
    }
    if (added.isEmpty) return;
    final wasIdle = state.currentId == null;
    state = state.copyWith(
      queue: _queueList(),
      playOrder: _playOrderList(),
      currentId: _order.current,
    );
    if (wasIdle) {
      _order.index = 0;
      state = state.copyWith(currentId: _order.current);
      await _load();
    }
  }

  /// Removes [id] from the session queue.
  ///
  /// Removing the track that is playing advances to what is now next, the way
  /// skipping would; removing the last one stops the engine.
  Future<void> removeFromQueue(String id) async {
    if (!_byId.containsKey(id)) return;
    final wasCurrent = _order.remove(id);
    _byId.remove(id);
    final nextId = _order.current;
    state = state.copyWith(
      queue: _queueList(),
      playOrder: _playOrderList(),
      currentId: nextId,
      clearCurrent: nextId == null,
    );
    if (!wasCurrent) return;
    if (nextId == null) {
      await _engine?.stop();
      state = state.copyWith(
        playing: false,
        position: Duration.zero,
        clearDuration: true,
        clearError: true,
      );
      return;
    }
    await _load();
  }

  Future<void> togglePlayPause() async {
    if (state.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Starts or resumes playback of the current track.
  ///
  /// With a queue but no engine yet (nothing has been played) this loads and
  /// plays the cursor; with nothing queued it is a no-op.
  Future<void> play() async {
    if (state.currentId == null) return;
    if (state.loading) return;
    if (state.error != null) {
      await skipForward();
      return;
    }
    final engine = _engine;
    if (engine == null) {
      await _load();
      return;
    }
    if (state.playing) return;
    if (_isAtEnd) await engine.seek(Duration.zero);
    await engine.resume();
  }

  Future<void> pause() async {
    if (state.playing) await _engine?.pause();
  }

  /// Stops the engine and parks the position at the start.
  Future<void> stopPlayback() async {
    await _engine?.stop();
    if (!_alive) return;
    state = state.copyWith(playing: false, position: Duration.zero);
  }

  /// The cursor's position in [VaultAudioPlaybackState.playOrder], for the
  /// notification's `queueIndex`.
  int get currentIndex => _order.isEmpty ? 0 : _order.index;

  void setShuffled(bool value) {
    _order.setShuffled(value);
    state = state.copyWith(
      shuffled: _order.shuffled,
      playOrder: _playOrderList(),
    );
  }

  void setRepeat(RepeatMode mode) {
    _order.repeat = mode;
    state = state.copyWith(repeat: mode);
  }

  Future<void> skipForward() async {
    final nextId = _order.next();
    if (nextId == null) {
      await _engine?.stop();
      state = state.copyWith(playing: false);
      return;
    }
    state = state.copyWith(currentId: _order.current);
    await _load();
  }

  Future<void> skipBack() async {
    if (state.position > const Duration(seconds: 3)) {
      await _engine?.seek(Duration.zero);
      return;
    }
    final previousId = _order.previous();
    if (previousId == null) {
      await _engine?.seek(Duration.zero);
      return;
    }
    state = state.copyWith(currentId: _order.current);
    await _load();
  }

  Future<void> seekTo(Duration position) async {
    state = state.copyWith(position: position);
    await _engine?.seek(position);
  }

  void toggleShuffle() {
    _order.setShuffled(!_order.shuffled);
    state = state.copyWith(
      shuffled: _order.shuffled,
      playOrder: _playOrderList(),
    );
  }

  void cycleRepeat() {
    _order.repeat = switch (_order.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeat: _order.repeat);
  }

  /// Replays the current track from the start without leaving the track.
  Future<void> replayCurrent() async {
    final engine = _engine;
    if (engine == null) return;
    await engine.seek(Duration.zero);
    if (!_alive) return;
    await engine.resume();
    state = state.copyWith(position: Duration.zero, playing: true);
  }

  Future<void> _onTrackEnd() async {
    if (_order.repeat == RepeatMode.one) {
      await replayCurrent();
      return;
    }
    final nextId = _order.next();
    if (nextId == null) {
      await _engine?.stop();
      if (!_alive) return;
      state = state.copyWith(
        playing: false,
        position: state.duration ?? state.position,
      );
      return;
    }
    state = state.copyWith(currentId: _order.current);
    await _load();
  }

  Future<void> _load() async {
    final audio = state.current;
    if (audio == null) {
      if (!_alive) return;
      state = state.copyWith(
        loading: false,
        playing: false,
        clearCurrent: true,
        error: 'Nothing to play.',
      );
      return;
    }
    final token = ++_loadToken;
    _switching = true;
    state = state.copyWith(
      loading: true,
      clearError: true,
      position: Duration.zero,
      duration: audio.durationMs == null
          ? null
          : Duration(milliseconds: audio.durationMs!),
      clearDuration: audio.durationMs == null,
    );
    try {
      final bytes = await ref
          .read(vaultAudiosProvider.notifier)
          .readAudio(audio);
      if (!_alive || token != _loadToken) return;
      final engine = _ensureEngine();
      await engine.play(bytes, mimeType: audio.mimeType);
      final measured = await engine.getDuration();
      if (!_alive || token != _loadToken) return;
      state = state.copyWith(
        duration: measured,
        clearDuration: measured == null,
        loading: false,
        playing: true,
      );
    } on VaultAudioMissingException catch (e) {
      if (!_alive || token != _loadToken) return;
      state = state.copyWith(
        loading: false,
        playing: false,
        error: '"${e.fileName}" is unavailable.',
      );
      _switching = false;
      final nextId = _order.next();
      if (nextId != null) {
        state = state.copyWith(currentId: _order.current);
        unawaited(_load());
      }
      return;
    } catch (_) {
      if (!_alive || token != _loadToken) return;
      state = state.copyWith(
        loading: false,
        playing: false,
        error: 'Could not play "${audio.fileName}".',
      );
    } finally {
      _switching = false;
    }
  }

  List<VaultAudio> _queueList() {
    return List<VaultAudio>.unmodifiable(<VaultAudio>[
      for (final id in _order.ids)
        if (_byId[id] != null) _byId[id]!,
    ]);
  }

  List<VaultAudio> _playOrderList() {
    return List<VaultAudio>.unmodifiable(<VaultAudio>[
      for (final id in _order.playOrder)
        if (_byId[id] != null) _byId[id]!,
    ]);
  }

  /// Pauses the engine when the app leaves the foreground.
  ///
  /// Retained for the non-Android/web paths; on Android the foreground service
  /// keeps playing, and `VaultAudioHandler` decides there.
  Future<void> pauseForBackground() async {
    if (state.playing) await _engine?.pause();
  }
}

/// The one playback session, wired into the root provider container.
final vaultAudioPlaybackProvider =
    NotifierProvider<VaultAudioPlaybackController, VaultAudioPlaybackState>(
      VaultAudioPlaybackController.new,
    );
