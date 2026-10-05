/// Consecutive wrong attempts and the 30-second lockout they earn (D-88).
///
/// **This reverses D-85**, which recorded "no attempt counter, no lockout, no
/// delay" as a deliberate decision. The reasoning behind that decision still
/// stands in one part â€” 10â´ codes are free to try, and a lockout is a
/// denial-of-service tool aimed at whoever owns the phone â€” so what changed is
/// the cost, not the principle. Three attempts is short enough that an owner who
/// mistypes their own code is not punished past a half-minute, and long enough
/// that a script hammering the keypad no longer gets 10â´ guesses for free. D-88
/// supersedes D-85; the old record is left in place rather than rewritten, since
/// the reasoning it holds is what the new limit was drawn against.
///
/// **Why this is a controller and not widget state.** The lockout has to
/// survive the PIN screen being rebuilt, navigated away from, and returned to â€”
/// otherwise "leave and come straight back" is a bypass, and a bypass that takes
/// one tap is worse than no lockout at all. Riverpod state outlives the widget
/// that wrote it, and the deadline outlives the process, so the countdown is
/// anchored to a *wall-clock instant* rather than to ticks a widget happened to
/// receive.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/preferences_provider.dart';

/// How many wrong attempts are allowed before the screen locks (D-88).
const int secretMaxAttempts = 3;

/// How long the screen stays locked, in seconds (D-88).
const int secretLockoutSeconds = 30;

/// The clock the lockout measures its deadline against (D-88).
///
/// **A seam, not a convenience.** The deadline is deliberately a wall-clock
/// instant rather than a counter the ticker decrements — that is what makes the
/// lockout survive a backgrounded app or a restarted process — but it means
/// every remaining-time question bottoms out in `DateTime.now()`, which a widget
/// test cannot advance: `tester.pump` moves timers forward and leaves the real
/// clock where it was. Without this, the countdown could be read but not tested,
/// and a countdown that cannot be tested is a countdown nobody will change
/// again.
///
/// So the now-provider is injected, defaulting to the real clock. Production
/// gets `DateTime.now` and the property that motivated the design; a test
/// overrides it with a clock it controls and can advance alongside `pump`.
final Provider<DateTime Function()> secretClockProvider =
    Provider<DateTime Function()>((ref) => DateTime.now);

/// The storage key holding the lockout deadline.
///
/// Exposed so a test can seed and inspect the real store rather than a parallel
/// copy of the schema, matching how the settings and secret repositories' keys
/// are used.
const String lockoutUntilKey = 'secretLockoutUntil';

/// The attempt counter and the lockout deadline (D-88).
@immutable
class SecretLockoutState {
  /// A tick count that exists purely to make each tick a *distinct* state (D-88).
  ///
  /// [copyWith] with no arguments used to be the tick's whole effect, but
  /// [SecretLockoutState] compares by value and `lockedUntil` is deliberately
  /// never reassigned by a tick — so every tick published a state equal to the
  /// one before it, Riverpod saw no change, and no listener was notified. The
  /// countdown was therefore frozen on "30s" for the whole lock: the message
  /// rendered correctly once and then never moved. This field is what a tick
  /// increments so that "a second passed" is representable as a state change,
  /// which is the only thing that can schedule a repaint.
  final int ticks;

  /// Creates a state. Public for tests and for [SecretLockoutNotifier.restore].
  const SecretLockoutState({
    this.failedAttempts = 0,
    this.lockedUntil,
    this.ticks = 0,
  });

  /// The starting state: no attempts, no lock.
  static const SecretLockoutState initial = SecretLockoutState();

  /// Wrong attempts since the last success or unlock.
  final int failedAttempts;

  /// The instant the lockout ends, or null when the screen is not locked.
  ///
  /// A **wall-clock deadline** rather than a remaining-seconds counter, and that
  /// is the whole of the unevadability. A countdown stored as "23 seconds left"
  /// would need a timer to decrement it, and any gap where the timer was not
  /// running â€” a backgrounded app, a rebuilt widget, a restarted process â€” would
  /// leave the user locked out for longer than they were told, or not at all.
  /// Compared against [DateTime.now] every time it is read, the remaining time is
  /// always simply true, and the only thing the ticker does is decide when to
  /// repaint.
  final DateTime? lockedUntil;

  /// Whether the keypad should be inert right now.
  ///
  /// Takes the current time as an argument rather than reading the clock itself
  /// (D-88): see [secretClockProvider] for why, and [SecretLockoutNotifier.isLocked]
  /// for the reading the screen actually uses.
  bool isLockedAt(DateTime now) {
    final deadline = lockedUntil;
    return deadline != null && now.isBefore(deadline);
  }

  /// Whole seconds left on the lock, or 0 when unlocked.
  ///
  /// `ceil`, not `round`: at 29.4 seconds remaining the user must still be told
  /// "30s", because telling them "29s" starts the visible countdown at a number
  /// they were never shown. Rounding would put the same effect a second early
  /// every single time.
  int secondsRemainingAt(DateTime now) {
    final deadline = lockedUntil;
    if (deadline == null) return 0;
    final remaining = deadline.difference(now).inMilliseconds;
    if (remaining <= 0) return 0;
    return (remaining / 1000).ceil();
  }

  /// Attempts still available before the next lock.
  int get attemptsRemaining => secretMaxAttempts - failedAttempts;

  SecretLockoutState copyWith({int? failedAttempts, DateTime? lockedUntil}) =>
      SecretLockoutState(
        failedAttempts: failedAttempts ?? this.failedAttempts,
        lockedUntil: lockedUntil ?? this.lockedUntil,
        ticks: ticks,
      );

  /// This state, marked as having been republished one tick later (D-88).
  ///
  /// The ticker's only move, and it changes nothing a caller can observe except
  /// [ticks] — which is the point. It exists so that "another second passed" is a
  /// *distinct* state, because Riverpod only notifies on a change and a state
  /// equal to the last one is silence.
  SecretLockoutState ticked() => SecretLockoutState(
        failedAttempts: failedAttempts,
        lockedUntil: lockedUntil,
        ticks: ticks + 1,
      );

  @override
  bool operator ==(Object other) =>
      other is SecretLockoutState &&
      other.failedAttempts == failedAttempts &&
      other.lockedUntil == lockedUntil &&
      // Part of identity, not an implementation detail: if it were excluded, two
      // states differing only by a tick would compare equal and the tick would
      // stop repainting — the bug [ticked] exists to fix.
      other.ticks == ticks;

  @override
  int get hashCode => Object.hash(failedAttempts, lockedUntil, ticks);
}
/// Owns the failed-attempt count and the lockout countdown (D-88).
///
/// A plain [Notifier] rather than the feature's `AsyncNotifier`: nothing here
/// needs to be read *before* the store answers, because [restore] reads it when
/// the PIN screen mounts and the screen is not interactive until it has. An
/// `AsyncNotifier` would put every consumer behind a loading state to buy a
/// guarantee the screen does not need.
class SecretLockoutNotifier extends Notifier<SecretLockoutState> {
  /// Ticks once a second while locked, and is cancelled the moment the lock ends.
  ///
  /// Owned by the controller rather than a widget for the reason the deadline
  /// itself is: a timer started by a `State` dies with that `State`, and a
  /// rebuild during the lockout would otherwise freeze the countdown on screen
  /// while the deadline kept running.
  Timer? _ticker;

  @override
  SecretLockoutState build() {
    ref.onDispose(_stopTicker);
    return SecretLockoutState.initial;
  }

  /// Re-reads any lockout left over from a previous run of the app (D-88).
  ///
  /// Called by the PIN screen when it mounts. A stored deadline that has already
  /// passed is discarded rather than restored, so a user whose 30 seconds
  /// elapsed while the app was closed is not told to wait out a lock that ended.
  ///
  /// The attempt count is deliberately **not** restored when there is no active
  /// lock: the counter exists to count towards the next lockout, and an app that
  /// was closed for an hour is not "consecutive" in any sense the user would
  /// recognise. What survives is the lock, which is the part actually being
  /// served.
  Future<void> restore() async {
    try {
      final store = await ref.read(preferencesProvider);
      final deadline = _readDeadline(store);
      if (deadline == null || !_now.isBefore(deadline)) {
        await _clear();
        return;
      }
      state = SecretLockoutState(
        failedAttempts: secretMaxAttempts,
        lockedUntil: deadline,
      );
      _startTicker();
    } catch (_) {
      // A store that cannot be read must not lock the user out of their own PIN
      // screen. Failing open is the safer of the two failures: the worst case is
      // that a restart resets the counter â€” which is what D-85 allowed in full â€”
      // and the alternative is a screen nobody can get past.
    }
  }

  /// Records one wrong attempt, locking the screen if it was the third (D-88).
  ///
  /// A no-op while locked, which is what makes a burst of rapid taps harmless:
  /// four digits can only reach this once per completed entry, and once locked no
  /// further entry can complete at all. The count cannot run away from a
  /// double-tap on the last digit, which the field's own in-flight guard already
  /// blocks but which is cheap to make impossible here too.
  void registerFailure() {
    if (isLocked) return;

    final attempts = state.failedAttempts + 1;
    if (attempts < secretMaxAttempts) {
      state = state.copyWith(failedAttempts: attempts);
      return;
    }

    state = SecretLockoutState(
      failedAttempts: secretMaxAttempts,
      lockedUntil: _now.add(
        const Duration(seconds: secretLockoutSeconds),
      ),
    );
    unawaited(_persist());
    _startTicker();
  }

  /// Clears the counter after a correct code (D-88).
  void registerSuccess() {
    _stopTicker();
    state = SecretLockoutState.initial;
    unawaited(_clear());
  }

  /// The current time, per [secretClockProvider] (D-88).
  DateTime get _now => ref.read(secretClockProvider)();

  /// Whether the pad should be inert, read through the injected clock (D-88).
  ///
  /// The screen reads this rather than calling [SecretLockoutState.isLockedAt]
  /// itself, so there is exactly one reading of "now" in the feature and it is
  /// the one a test can move.
  bool get isLocked => state.isLockedAt(_now);

  /// Whole seconds left on the lock, read through the injected clock (D-88).
  int get secondsRemaining => state.secondsRemainingAt(_now);

  /// The message shown while locked, or null when the screen is usable.
  ///
  /// The countdown is folded into the sentence rather than shown beside it:
  /// "Too many attempts. Try again in 30s" states what happened *and* when it
  /// stops, where a bare "Locked" beside a separate timer makes the user read
  /// two things and reconcile them.
  String? get lockoutMessage {
    if (!isLocked) return null;
    return 'Too many attempts. Try again in ${secondsRemaining}s';
  }

  void _startTicker() {
    _stopTicker();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      // The deadline is never reassigned here, so the lock cannot be *extended*
      // by a slow frame â€” a tick only decides when to repaint, never how long
      // the wait is.
      if (!isLocked) {
        // The deadline passed between two ticks. Unlock exactly as if the final
        // tick had arrived on time, and hand the user their three attempts back.
        registerSuccess();
        return;
      }
      state = state.ticked();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  /// Writes the active deadline, or erases the key when there is none.
  Future<void> _persist() async {
    try {
      final store = await ref.read(preferencesProvider);
      final deadline = state.lockedUntil;
      if (deadline == null) {
        await store.remove(lockoutUntilKey);
      } else {
        await store.setString(lockoutUntilKey, deadline.toIso8601String());
      }
    } catch (_) {
      // As in [restore]: a store that cannot be written loses the
      // across-restart guarantee and nothing else. The in-memory lock still
      // holds for this session, which is the part a tap cannot get past.
    }
  }

  Future<void> _clear() async {
    try {
      final store = await ref.read(preferencesProvider);
      await store.remove(lockoutUntilKey);
    } catch (_) {
      // Nothing to do â€” see [_persist].
    }
  }
}

/// The lockout policy, as a provider (D-88).
final NotifierProvider<SecretLockoutNotifier, SecretLockoutState>
secretLockoutProvider =
    NotifierProvider<SecretLockoutNotifier, SecretLockoutState>(
      SecretLockoutNotifier.new,
    );

/// Reads the stored deadline, degrading anything malformed to null.
///
/// The same guard the settings repository uses, for the same reason: the
/// plugin's typed getters are casts, so a hand-edited or partially-written key
/// would raise a `TypeError` and take the screen down rather than merely losing
/// the lockout.
DateTime? _readDeadline(SharedPreferences store) {
  try {
    final raw = store.getString(lockoutUntilKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  } on TypeError {
    return null;
  }
}
