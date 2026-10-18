import 'dart:async';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../domain/vault_audio.dart';
import 'audio_engine.dart' show RepeatMode;
import '../presentation/vault_audio_controller.dart';
import '../presentation/vault_audio_widgets.dart';
import 'vault_audio_playback.dart';

/// The full-screen player over the one app-wide playback session.
///
/// The screen owns no engine and no queue: it renders
/// [vaultAudioPlaybackProvider] and calls its methods. Playback therefore
/// outlives the page — popping it while a track plays leaves the sound (and,
/// on Android, the notification) running. The engine seam tests override is
/// `vaultAudioEngineFactoryProvider`, not a static on this widget.
class VaultAudioPlayerScreen extends ConsumerStatefulWidget {
  const VaultAudioPlayerScreen({super.key});

  /// How many Up Next rows show before the "Show all" button appears.
  static const int upNextCollapsedCount = 5;

  /// Opens the player from the library, queue and all.
  ///
  /// Starts [tracks] at [index] unless the tapped track is already in the
  /// session, in which case the queue is preserved and the cursor moves.
  static void open(
    BuildContext context,
    WidgetRef ref,
    List<VaultAudio> tracks,
    int index,
  ) {
    if (tracks.isEmpty) return;
    final controller = ref.read(vaultAudioPlaybackProvider.notifier);
    final tapped = tracks[index.clamp(0, tracks.length - 1)];
    if (controller.contains(tapped.id)) {
      unawaited(controller.jumpTo(tapped.id));
    } else {
      unawaited(controller.playFromList(tracks, index));
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const VaultAudioPlayerScreen()),
    );
  }

  @override
  ConsumerState<VaultAudioPlayerScreen> createState() =>
      _VaultAudioPlayerScreenState();
}

class _VaultAudioPlayerScreenState
    extends ConsumerState<VaultAudioPlayerScreen> {
  bool _upNextExpanded = false;

  VaultAudioPlaybackController get _controller =>
      ref.read(vaultAudioPlaybackProvider.notifier);

  VaultAudio? _currentLive() {
    final playback = ref.watch(vaultAudioPlaybackProvider);
    final id = playback.currentId;
    if (id == null) return null;
    final audios = ref.watch(vaultAudiosProvider).valueOrNull?.audios;
    if (audios != null) {
      for (final audio in audios) {
        if (audio.id == id) return audio;
      }
    }
    return playback.current;
  }

  Future<void> _toggleFavorite(VaultAudio audio) async {
    await ref.read(vaultAudiosProvider.notifier).toggleFavorite(audio.id);
  }

  Future<void> _share(VaultAudio audio) async {
    try {
      await ref.read(vaultAudiosProvider.notifier).shareAudios(<VaultAudio>[
        audio,
      ]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share this audio.')),
      );
    }
  }

  Future<void> _pickCategory(VaultAudio audio) async {
    final picked = await showDialog<VaultAudioType?>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Category'),
        children: <Widget>[
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text(
              audio.categoryOverride == null ? 'Automatic ✓' : 'Automatic',
            ),
          ),
          for (final type in VaultAudioType.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(type),
              child: Text(
                audio.categoryOverride == type ? '${type.label} ✓' : type.label,
              ),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (picked == audio.categoryOverride) return;
    await ref.read(vaultAudiosProvider.notifier).setCategory(audio.id, picked);
  }

  void _openOverflow(VaultAudio audio) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_share(audio));
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_remove),
              title: const Text('Remove from queue'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_controller.removeFromQueue(audio.id));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File info'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(showVaultAudioInfo(context, audio));
              },
            ),
            ListTile(
              leading: const Icon(Icons.category_outlined),
              title: const Text('Category'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_pickCategory(audio));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(vaultAudioPlaybackProvider);
    final audio = _currentLive();

    return SecondaryPageScaffold(
      header: SecondaryPageHeader(
        title: 'Audio Player',
        trailing: audio == null
            ? null
            : AppIconButton(
                icon: Icons.more_vert,
                tooltip: 'Player options',
                onPressed: () => _openOverflow(audio),
              ),
      ),
      body: KeyedSubtree(
        key: const Key('vault-audio-player'),
        child: audio == null
            ? const EmptyState(
                icon: Icons.audio_file_outlined,
                title: 'Nothing to play',
              )
            : _PlayerBody(
                audio: audio,
                loading: playback.loading,
                error: playback.error,
                position: playback.position,
                duration: playback.duration,
                playing: playback.playing,
                shuffled: playback.shuffled,
                repeat: playback.repeat,
                upNextExpanded: _upNextExpanded,
                orderedQueue: playback.playOrder,
                currentId: audio.id,
                onSeek: (position) => unawaited(_controller.seekTo(position)),
                onTogglePlayPause: () =>
                    unawaited(_controller.togglePlayPause()),
                onNext: () => unawaited(_controller.skipForward()),
                onPrevious: () => unawaited(_controller.skipBack()),
                onToggleShuffle: _controller.toggleShuffle,
                onCycleRepeat: _controller.cycleRepeat,
                onToggleFavorite: () => unawaited(_toggleFavorite(audio)),
                onJump: (id) => unawaited(_controller.jumpTo(id)),
                onRemove: (id) => unawaited(_controller.removeFromQueue(id)),
                onToggleUpNext: () =>
                    setState(() => _upNextExpanded = !_upNextExpanded),
                onSkipError: () => unawaited(_controller.skipForward()),
              ),
      ),
    );
  }
}

/// The scrollable player below the header: artwork, title, scrubber,
/// transport, and the capped Up Next list.
class _PlayerBody extends StatelessWidget {
  const _PlayerBody({
    required this.audio,
    required this.loading,
    required this.error,
    required this.position,
    required this.duration,
    required this.playing,
    required this.shuffled,
    required this.repeat,
    required this.upNextExpanded,
    required this.orderedQueue,
    required this.currentId,
    required this.onSeek,
    required this.onTogglePlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onToggleShuffle,
    required this.onCycleRepeat,
    required this.onToggleFavorite,
    required this.onJump,
    required this.onRemove,
    required this.onToggleUpNext,
    required this.onSkipError,
  });

  final VaultAudio audio;
  final bool loading;
  final String? error;
  final Duration position;
  final Duration? duration;
  final bool playing;
  final bool shuffled;
  final RepeatMode repeat;
  final bool upNextExpanded;
  final List<VaultAudio> orderedQueue;
  final String currentId;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onToggleShuffle;
  final VoidCallback onCycleRepeat;
  final VoidCallback onToggleFavorite;
  final ValueChanged<String> onJump;
  final ValueChanged<String> onRemove;
  final VoidCallback onToggleUpNext;
  final VoidCallback onSkipError;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final totalMs = duration?.inMilliseconds ?? audio.durationMs ?? 0;
    final max = totalMs <= 0 ? 1.0 : totalMs.toDouble();
    final value = position.inMilliseconds.toDouble().clamp(0.0, max);
    final visibleUpNext = upNextExpanded
        ? orderedQueue
        : orderedQueue
              .take(VaultAudioPlayerScreen.upNextCollapsedCount)
              .toList();

    return ListView(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        bottom: AppSpacing.bottomSafe,
      ),
      children: <Widget>[
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: VaultAudioTypeTile(type: audio.effectiveType, dimension: 232),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    audio.fileName,
                    style: context.type.screenTitleCompact,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    audioMetaLine(audio),
                    style: context.type.rowSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            AppIconButton(
              icon: audio.isFavorite ? Icons.star : Icons.star_outline,
              tooltip: audio.isFavorite
                  ? 'Remove from favorites'
                  : 'Add to favorites',
              color: audio.isFavorite ? colors.accent : null,
              bordered: false,
              onPressed: onToggleFavorite,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  error!,
                  style: context.type.rowSubtitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: onSkipError, child: const Text('Skip')),
              ],
            ),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Slider(
                key: const Key('vault-audio-seek'),
                value: value,
                max: max,
                activeColor: colors.accent,
                onChanged: (v) => onSeek(Duration(milliseconds: v.round())),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    formatAudioDuration(position),
                    style: context.type.caption,
                  ),
                  Text(
                    formatAudioDuration(duration ?? audio.durationMs),
                    style: context.type.caption,
                  ),
                ],
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.md),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            AppIconButton(
              icon: Icons.shuffle,
              tooltip: shuffled ? 'Shuffle on' : 'Shuffle off',
              color: shuffled ? colors.accent : colors.textSecondary,
              bordered: false,
              onPressed: onToggleShuffle,
            ),
            AppIconButton(
              key: const Key('vault-audio-prev'),
              icon: Icons.skip_previous,
              tooltip: 'Previous',
              bordered: false,
              onPressed: onPrevious,
            ),
            SizedBox.square(
              dimension: 64,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.accent,
                ),
                child: IconButton(
                  key: const Key('vault-audio-play-pause'),
                  tooltip: playing ? 'Pause' : 'Play',
                  icon: Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    size: 32,
                    color: colors.textOnAccent,
                  ),
                  onPressed: onTogglePlayPause,
                ),
              ),
            ),
            AppIconButton(
              key: const Key('vault-audio-next'),
              icon: Icons.skip_next,
              tooltip: 'Next',
              bordered: false,
              onPressed: onNext,
            ),
            AppIconButton(
              icon: switch (repeat) {
                RepeatMode.one => Icons.repeat_one,
                _ => Icons.repeat,
              },
              tooltip: switch (repeat) {
                RepeatMode.off => 'Repeat off',
                RepeatMode.all => 'Repeat all',
                RepeatMode.one => 'Repeat one',
              },
              color: repeat == RepeatMode.off
                  ? colors.textSecondary
                  : colors.accent,
              bordered: false,
              onPressed: onCycleRepeat,
            ),
          ],
        ),
        SectionHeader(
          'Up Next',
          key: const Key('vault-audio-up-next'),
          trailing:
              orderedQueue.length > VaultAudioPlayerScreen.upNextCollapsedCount
              ? TextButton(
                  onPressed: onToggleUpNext,
                  child: Text(
                    upNextExpanded
                        ? 'Show less'
                        : 'Show all (${orderedQueue.length})',
                  ),
                )
              : null,
        ),
        for (var i = 0; i < visibleUpNext.length; i++)
          _UpNextRow(
            index: i,
            audio: visibleUpNext[i],
            current: visibleUpNext[i].id == currentId,
            onTap: () => onJump(visibleUpNext[i].id),
            onRemove: () => onRemove(visibleUpNext[i].id),
          ),
      ],
    );
  }
}

/// One compact queue row: position, name, meta, duration, and a remove action;
/// the current track wears the accent plus an equalizer glyph.
class _UpNextRow extends StatelessWidget {
  const _UpNextRow({
    required this.index,
    required this.audio,
    required this.current,
    required this.onTap,
    required this.onRemove,
  });

  final int index;
  final VaultAudio audio;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: current ? colors.surfaceSelected : colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: current
              ? Border.all(color: colors.accent, width: 1.5)
              : Border.all(color: colors.cardBorder),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.card),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  SizedBox(
                    width: 24,
                    child: current
                        ? Icon(Icons.equalizer, size: 18, color: colors.accent)
                        : Text(
                            '${index + 1}',
                            style: context.type.rowSubtitle,
                            textAlign: TextAlign.center,
                          ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  VaultAudioTypeTile(type: audio.effectiveType, dimension: 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          audio.fileName,
                          style: context.type.rowTitle.copyWith(
                            color: current ? colors.accent : colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          audioMetaLine(audio),
                          style: context.type.rowSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatAudioDuration(audio.durationMs),
                    style: context.type.rowSubtitle,
                  ),
                  IconButton(
                    key: Key('vault-audio-remove-${audio.id}'),
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    tooltip: 'Remove from queue',
                    color: colors.textSecondary,
                    onPressed: onRemove,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
