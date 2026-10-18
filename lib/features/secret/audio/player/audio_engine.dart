import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// How [VaultAudioQueue] moves past the ends of the list.
enum RepeatMode { off, all, one }

/// The seam over the player plugin: decrypted in-memory bytes in, sound out.
///
/// The controller decrypts; the engine never sees the vault, only the bytes
/// it is asked to play. `audioplayers` 6.8.1 plays those via `BytesSource`,
/// so no plaintext temp file is ever written.
abstract class VaultAudioEngine {
  Future<void> play(Uint8List bytes, {String? mimeType});

  Future<void> pause();

  Future<void> resume();

  Future<void> seek(Duration position);

  Future<void> stop();

  Future<void> dispose();

  /// Roughly every 200ms while playing; drives the progress bar.
  Stream<Duration> get onPositionChanged;

  /// Fires when the duration becomes known; `null` until then.
  Stream<Duration?> get onDurationChanged;

  /// `true` while sound is coming out, `false` on pause/stop/completion.
  Stream<bool> get onPlayingChanged;

  Future<Duration?> getDuration();
}

/// The production engine over a single `AudioPlayer` (one track at a time).
///
/// `ReleaseMode.stop` keeps resources intact after a stop so replaying does
/// not re-buffer; completion arrives via `onPlayerComplete` and is mapped to
/// `onPlayingChanged == false`, since the queue (not the plugin) decides
/// what "ended" means.
class AudioplayersVaultAudioEngine implements VaultAudioEngine {
  AudioplayersVaultAudioEngine({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _player.setReleaseMode(ReleaseMode.stop);
    _completeSub = _player.onPlayerComplete.listen((_) {
      _playingController.add(false);
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      _playingController.add(state == PlayerState.playing);
    });
  }

  final AudioPlayer _player;
  final _playingController = StreamController<bool>.broadcast();
  late final StreamSubscription<void> _completeSub;
  late final StreamSubscription<PlayerState> _stateSub;

  @override
  Future<void> play(Uint8List bytes, {String? mimeType}) =>
      _player.play(BytesSource(bytes, mimeType: mimeType));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _completeSub.cancel();
    await _stateSub.cancel();
    await _playingController.close();
    await _player.dispose();
  }

  @override
  Stream<Duration> get onPositionChanged => _player.onPositionChanged;

  @override
  Stream<Duration?> get onDurationChanged =>
      _player.onDurationChanged.map<Duration?>(
        (duration) => duration == Duration.zero ? null : duration,
      );

  @override
  Stream<bool> get onPlayingChanged => _playingController.stream;

  @override
  Future<Duration?> getDuration() => _player.getDuration();
}

/// In-memory engine for tests: no plugin, no platform channel.
///
/// The duration is whatever the test sets; [complete] simulates the plugin's
/// end-of-track event so the queue can be exercised without sound.
class FakeVaultAudioEngine implements VaultAudioEngine {
  Duration? fakeDuration;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();

  /// Ends the current track the way `onPlayerComplete` would.
  void complete() => _playingController.add(false);

  void emitPosition(Duration position) => _positionController.add(position);

  @override
  Future<void> play(Uint8List bytes, {String? mimeType}) async {
    _playingController.add(true);
    _durationController.add(fakeDuration);
  }

  @override
  Future<void> pause() async => _playingController.add(false);

  @override
  Future<void> resume() async => _playingController.add(true);

  @override
  Future<void> seek(Duration position) async {
    _positionController.add(position);
  }

  @override
  Future<void> stop() async => _playingController.add(false);

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _durationController.close();
    await _playingController.close();
  }

  @override
  Stream<Duration> get onPositionChanged => _positionController.stream;

  @override
  Stream<Duration?> get onDurationChanged => _durationController.stream;

  @override
  Stream<bool> get onPlayingChanged => _playingController.stream;

  @override
  Future<Duration?> getDuration() async => fakeDuration;
}

/// Pure-Dart play order over an id list: index, shuffle, repeat, and mutation.
///
/// Holds no bytes and no player — the controller owns the ids, the engine owns
/// the sound, and this owns the "what's next" answer. It keeps two orders: the
/// stored order (what the vault lists) and the play order (the stored order,
/// or its shuffle once [setShuffled] is on). Keeping both is what lets shuffle
/// be toggled off without losing where the user was, and what makes append and
/// remove cheap: the play order is simply edited in place.
///
/// Unit-tested in isolation.
class VaultAudioQueue {
  VaultAudioQueue(List<String> ids)
    : _stored = List<String>.of(ids),
      _order = List<String>.of(ids);

  final List<String> _stored;
  final List<String> _order;

  bool shuffled = false;
  RepeatMode repeat = RepeatMode.off;

  int _index = 0;

  /// The stored order, as the vault lists it (unshuffled).
  List<String> get ids => List<String>.unmodifiable(_stored);

  /// The play order: [_order], shuffle applied if [shuffled].
  List<String> get playOrder => List<String>.unmodifiable(_order);

  int get length => _order.length;

  bool get isEmpty => _order.isEmpty;

  /// The cursor's position inside [playOrder].
  int get index => _index;

  set index(int value) {
    if (_order.isEmpty) {
      _index = 0;
    } else {
      _index = value.clamp(0, _order.length - 1);
    }
  }

  /// The id at the cursor, or `null` when the list is empty.
  String? get current => isEmpty ? null : _order[_index];

  /// Advances past the end per [repeat]; returns the new current id.
  ///
  /// `one` never advances (the engine replays the same track); `all` wraps;
  /// `off` parks past the end and returns `null`.
  String? next() {
    if (isEmpty) return null;
    if (repeat == RepeatMode.one) return current;
    if (_index + 1 < _order.length) {
      _index++;
      return current;
    }
    if (repeat == RepeatMode.all) {
      _index = 0;
      return current;
    }
    return null;
  }

  /// Steps back; at the start, `all` wraps to the end, else stays.
  String? previous() {
    if (isEmpty) return null;
    if (repeat == RepeatMode.one) return current;
    if (_index > 0) {
      _index--;
      return current;
    }
    if (repeat == RepeatMode.all) {
      _index = _order.length - 1;
      return current;
    }
    return current;
  }

  /// Jumps the cursor to [id]; unknown ids are ignored.
  void jumpTo(String id) {
    final position = _order.indexOf(id);
    if (position >= 0) _index = position;
  }

  /// Adds [id] at the end of both orders; the cursor stays where it was.
  void append(String id) {
    _stored.add(id);
    _order.add(id);
  }

  /// Removes [id]; returns `true` when it was the track at the cursor.
  ///
  /// Removing ahead of the cursor shifts it back so the same track stays
  /// current; removing the current track leaves the cursor on what is now the
  /// next one (clamped to the end), which is what lets the caller advance.
  bool remove(String id) {
    final storedPosition = _stored.indexOf(id);
    if (storedPosition >= 0) _stored.removeAt(storedPosition);
    final orderPosition = _order.indexOf(id);
    if (orderPosition < 0) return false;
    final wasCurrent = orderPosition == _index;
    _order.removeAt(orderPosition);
    if (_order.isEmpty) {
      _index = 0;
    } else if (orderPosition < _index) {
      _index--;
    } else {
      _index = _index.clamp(0, _order.length - 1);
    }
    return wasCurrent;
  }

  /// Turns shuffle on or off, keeping the current track at the cursor.
  ///
  /// On: the current track stays first and the rest are shuffled behind it.
  /// Off: the stored order returns and the cursor follows the current track.
  /// A [random] can be injected so tests shuffle deterministically.
  void setShuffled(bool value, {Random? random}) {
    if (value == shuffled) return;
    shuffled = value;
    final currentId = current;
    if (value) {
      final rest = List<String>.of(_stored);
      if (currentId != null) rest.remove(currentId);
      rest.shuffle(random ?? Random());
      _order
        ..clear()
        ..addAll(<String>[?currentId, ...rest]);
      _index = 0;
    } else {
      _order
        ..clear()
        ..addAll(_stored);
      _index = currentId == null ? 0 : _order.indexOf(currentId);
      if (_index < 0) _index = 0;
    }
  }
}
