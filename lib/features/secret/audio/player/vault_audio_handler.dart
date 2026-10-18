import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/vault_audio.dart';
import 'audio_engine.dart' show RepeatMode;
import 'vault_audio_playback.dart';

/// Bridges the app's one playback session to Android's media session.
///
/// The session itself lives in [VaultAudioPlaybackController], which owns the
/// engine and the queue; this class only mirrors that state onto
/// [playbackState], [mediaItem], and [queue] so the system notification and
/// lock screen can draw it, and forwards their transport commands back. The
/// separation is deliberate: playback works identically when this handler is
/// never built (web, tests), and the handler holds no sound of its own.
class VaultAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  VaultAudioHandler(this._container) {
    _subscription = _container.listen<VaultAudioPlaybackState>(
      vaultAudioPlaybackProvider,
      (previous, next) => _sync(next),
      fireImmediately: true,
    );
  }

  final ProviderContainer _container;
  ProviderSubscription<VaultAudioPlaybackState>? _subscription;

  VaultAudioPlaybackController get _playback =>
      _container.read(vaultAudioPlaybackProvider.notifier);

  void dispose() {
    _subscription?.close();
    _subscription = null;
  }

  void _sync(VaultAudioPlaybackState state) {
    final items = <MediaItem>[
      for (final audio in state.playOrder) _mediaItem(audio),
    ];
    queue.add(items);

    final current = state.current;
    if (current == null) {
      mediaItem.add(null);
    } else {
      mediaItem.add(_mediaItem(current));
    }

    playbackState.add(
      PlaybackState(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{MediaAction.seek},
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: state.error != null
            ? AudioProcessingState.error
            : state.loading
            ? AudioProcessingState.buffering
            : state.hasQueue
            ? AudioProcessingState.ready
            : AudioProcessingState.idle,
        playing: state.playing,
        updatePosition: state.position,
        bufferedPosition: state.duration ?? state.position,
        queueIndex: state.hasQueue ? _playback.currentIndex : null,
        repeatMode: _repeatMode(state.repeat),
        shuffleMode: state.shuffled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        errorMessage: state.error,
      ),
    );
  }

  MediaItem _mediaItem(VaultAudio audio) {
    return MediaItem(
      id: audio.id,
      title: audio.fileName,
      album: 'Private audio vault',
      artist: audio.effectiveType.label,
      duration: audio.durationMs == null
          ? null
          : Duration(milliseconds: audio.durationMs!),
      extras: <String, dynamic>{'extension': audio.extensionLabel},
    );
  }

  static AudioServiceRepeatMode _repeatMode(RepeatMode mode) {
    return switch (mode) {
      RepeatMode.off => AudioServiceRepeatMode.none,
      RepeatMode.all => AudioServiceRepeatMode.all,
      RepeatMode.one => AudioServiceRepeatMode.one,
    };
  }

  @override
  Future<void> play() => _playback.play();

  @override
  Future<void> pause() => _playback.pause();

  @override
  Future<void> stop() async {
    await _playback.stopPlayback();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _playback.seekTo(position);

  @override
  Future<void> skipToNext() => _playback.skipForward();

  @override
  Future<void> skipToPrevious() => _playback.skipBack();

  @override
  Future<void> skipToQueueItem(int index) async {
    final state = _container.read(vaultAudioPlaybackProvider);
    if (index < 0 || index >= state.playOrder.length) return;
    await _playback.jumpTo(state.playOrder[index].id);
    await super.skipToQueueItem(index);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _playback.setRepeat(switch (repeatMode) {
      AudioServiceRepeatMode.one => RepeatMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group => RepeatMode.all,
      AudioServiceRepeatMode.none => RepeatMode.off,
    });
    await super.setRepeatMode(repeatMode);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _playback.setShuffled(shuffleMode != AudioServiceShuffleMode.none);
    await super.setShuffleMode(shuffleMode);
  }
}

/// Starts the Android foreground service and returns its handler, or `null`
/// where audio_service has no platform support (web, desktop) or fails to
/// initialise.
///
/// Call once, after the root [ProviderContainer] exists and before `runApp`.
/// The handler is returned so the caller can keep it alive; it also wires the
/// container's playback session into the media session, so nothing else needs
/// to hold it.
Future<VaultAudioHandler?> initVaultAudioService(
  ProviderContainer container,
) async {
  if (kIsWeb) return null;
  try {
    return await AudioService.init(
      builder: () => VaultAudioHandler(container),
      config: const AudioServiceConfig(
        androidNotificationChannelId:
            'com.hasanmahadi.calculator.audio.channel',
        androidNotificationChannelName: 'Audio playback',
        androidNotificationChannelDescription:
            'Playback controls for the private audio vault',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (_) {
    // Desktop and any platform without audio_service: the in-app session
    // still plays, just without a media session behind it.
    return null;
  }
}
