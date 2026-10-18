import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/uuid.dart';
import '../../documents/data/vault_document_downloader.dart';
import '../data/vault_audio_picker.dart';
import '../data/vault_audio_repository.dart';
import '../domain/vault_audio.dart';
import 'vault_audio_providers.dart';
import 'vault_audio_state.dart';

/// A rename was rejected: empty, or a name another audio already wears.
///
/// Carries a message the screen can drop straight into a snackbar, for the
/// same reason the image gallery's `AlbumNameException` does.
class VaultAudioNameException implements Exception {
  const VaultAudioNameException(this.message);

  final String message;

  @override
  String toString() => 'VaultAudioNameException: $message';
}

/// An audio's bytes were expected but the vault has none.
class VaultAudioMissingException implements Exception {
  const VaultAudioMissingException(this.fileName);

  final String fileName;

  @override
  String toString() =>
      'VaultAudioMissingException: no stored bytes for $fileName';
}

/// Reads, imports, renames, trashes, restores, and sorts vault audios.
///
/// Mirrors `VaultDocumentsNotifier`: the repository is awaited per call, every
/// mutation re-saves the whole metadata list and then `invalidateSelf()` so
/// the list rebuilds from storage rather than from a stale copy. All
/// mutations run through [_serialize], so two overlapping read-modify-writes
/// over the one preferences key cannot drop each other's change.
class VaultAudiosNotifier extends AsyncNotifier<VaultAudiosState> {
  /// How long a trashed audio is kept before it is deleted for good.
  static const Duration trashRetention = Duration(days: 30);

  Future<void> _mutations = Future<void>.value();

  @override
  Future<VaultAudiosState> build() async {
    final repository = await ref.watch(vaultAudioRepositoryProvider.future);
    var audios = await repository.loadAudios();
    final sort = await repository.loadSort();

    if (kIsWeb && await ref.read(vaultAudioStoreProvider).isEmpty) {
      // A browser refresh drops the in-memory blob store but keeps the
      // localStorage metadata, and the new session key cannot decrypt the old
      // blobs. Drop the rows that no longer have readable bytes; the screen
      // would otherwise list entries that can never play.
      if (audios.isNotEmpty) {
        audios = const <VaultAudio>[];
        await repository.saveAudios(audios);
      }
    }

    await _purgeExpiredTrash(audios, repository);
    return VaultAudiosState(audios: audios, sort: sort);
  }

  /// Runs [action] after every mutation queued before it has finished.
  ///
  /// The gate always completes normally, even when [action] throws, so one
  /// failed mutation cannot wedge the queue; the caller still receives
  /// [action]'s own result or error.
  Future<T> _serialize<T>(Future<T> Function() action) {
    final gate = Completer<void>();
    final previous = _mutations;
    _mutations = gate.future;
    return previous.then((_) => action()).whenComplete(() {
      if (!gate.isCompleted) gate.complete();
    });
  }

  Future<VaultAudioRepository> get _repository =>
      ref.read(vaultAudioRepositoryProvider.future);

  Future<void> _purgeExpiredTrash(
    List<VaultAudio> audios,
    VaultAudioRepository repository,
  ) async {
    final store = ref.read(vaultAudioStoreProvider);
    final now = DateTime.now();
    var changed = false;
    final kept = <VaultAudio>[];
    for (final audio in audios) {
      final trashedAt = audio.trashedAt;
      if (trashedAt != null && now.difference(trashedAt) > trashRetention) {
        try {
          await store.deletePermanently(audio.vaultFileName);
        } catch (_) {
          // A file that is already gone is not a reason to keep the row.
        }
        changed = true;
      } else {
        kept.add(audio);
      }
    }
    if (changed) await repository.saveAudios(kept);
  }

  /// The audio's decrypted bytes, for the player.
  ///
  /// Throws [VaultAudioMissingException] when the blob is gone or cannot be
  /// decrypted, so the player can show an honest "unavailable" state rather
  /// than spinning forever.
  Future<Uint8List> readAudio(VaultAudio audio) async {
    final bytes = await ref
        .read(vaultAudioStoreProvider)
        .readBytes(audio.vaultFileName, trashed: audio.isTrashed);
    if (bytes == null) {
      throw VaultAudioMissingException(audio.fileName);
    }
    return bytes;
  }

  /// Picks files and imports them into the vault.
  ///
  /// Pass [selection] to import a set the user already chose (the "add the
  /// duplicates anyway" path) instead of reopening the picker. When
  /// [allowDuplicates] is false, a file whose contents, or name and size,
  /// match an audio already in the vault is reported in
  /// [VaultAudioImportResult.duplicates] and not stored. A per-file
  /// read/encrypt failure is counted, never thrown, so one unreadable file
  /// cannot abort the rest of a multi-select.
  Future<VaultAudioImportResult> importAudios({
    List<PickedAudio>? selection,
    bool allowDuplicates = false,
  }) {
    return _serialize(() async {
      List<PickedAudio> picked;
      if (selection != null) {
        picked = selection;
      } else {
        picked = await ref.read(vaultAudioPickerProvider).pickAudios();
        if (picked.isEmpty) {
          return const VaultAudioImportResult(cancelled: true);
        }
      }

      final repository = await _repository;
      final store = ref.read(vaultAudioStoreProvider);
      // Copied into a mutable list *before* anything is appended: the
      // repository is free to hand back an unmodifiable view (the in-memory
      // fallback does), and mutating what a store returned is how a
      // repository change would silently break the import path.
      final existing = <VaultAudio>[...await repository.loadAudios()];

      var imported = 0;
      var failed = 0;
      final duplicates = <PickedAudio>[];

      for (final pick in picked) {
        try {
          final bytes = pick.bytes;
          if (bytes.isEmpty) {
            failed++;
            continue;
          }
          final hash = await _sha256Hex(bytes);
          if (!allowDuplicates && _isDuplicate(existing, pick, hash)) {
            duplicates.add(pick);
            continue;
          }
          final name = allowDuplicates
              ? _uniqueName(existing, _sanitizeName(pick.name))
              : _sanitizeName(pick.name);
          final now = DateTime.now();
          final id = uuidV4();
          final vaultName = '$id.bin';
          await store.importBytes(bytes, vaultName);
          existing.add(
            VaultAudio(
              id: id,
              fileName: name,
              vaultFileName: vaultName,
              mimeType: pick.mimeType ?? _mimeTypeOf(name),
              fileSize: bytes.length,
              dateAdded: now,
              dateModified: now,
              contentHash: hash,
            ),
          );
          imported++;
        } catch (_) {
          failed++;
        }
      }

      if (imported > 0) {
        await repository.saveAudios(existing);
        ref.invalidateSelf();
        await future;
      }
      return VaultAudioImportResult(
        imported: imported,
        duplicates: duplicates,
        failed: failed,
      );
    });
  }

  /// Imports [picks] even when they duplicate audios already in the vault.
  ///
  /// The duplicates screen's "add anyway" button lands here: forced names get
  /// a `name (2)`-style suffix via [_uniqueName] so the two rows stay tellable
  /// apart instead of listing the same filename twice.
  Future<VaultAudioImportResult> importDuplicatesAnyway(
    List<PickedAudio> picks,
  ) {
    return importAudios(selection: picks, allowDuplicates: true);
  }

  /// Renames [id], keeping the stored blob untouched.
  Future<void> renameAudio(String id, String newName) {
    return _serialize(() async {
      final trimmed = newName.trim();
      if (trimmed.isEmpty) {
        throw const VaultAudioNameException('Enter a name.');
      }
      if (trimmed.contains('/') || trimmed.contains('\\')) {
        throw const VaultAudioNameException(
          'A name cannot contain "/" or "\\".',
        );
      }
      final repository = await _repository;
      final audios = await repository.loadAudios();
      VaultAudio? target;
      for (final audio in audios) {
        if (audio.id == id) {
          target = audio;
          break;
        }
      }
      if (target == null) return;

      final taken = audios.any(
        (a) =>
            a.id != id &&
            !a.isTrashed &&
            a.fileName.toLowerCase() == trimmed.toLowerCase(),
      );
      if (taken) {
        throw VaultAudioNameException(
          'An audio named "$trimmed" already exists.',
        );
      }
      await repository.saveAudios(<VaultAudio>[
        for (final audio in audios)
          if (audio.id == id) audio.copyWith(fileName: trimmed) else audio,
      ]);
      ref.invalidateSelf();
      await future;
    });
  }

  /// Stars or unstars [id]; the row keeps its place in the stored order.
  Future<void> toggleFavorite(String id) {
    return _serialize(() async {
      final repository = await _repository;
      final audios = await repository.loadAudios();
      await repository.saveAudios(<VaultAudio>[
        for (final audio in audios)
          if (audio.id == id)
            audio.copyWith(isFavorite: !audio.isFavorite)
          else
            audio,
      ]);
      ref.invalidateSelf();
      await future;
    });
  }

  /// Pins [id] to [type], or clears the pin when [type] is `null` so the
  /// filename guess decides again.
  Future<void> setCategory(String id, VaultAudioType? type) {
    return _serialize(() async {
      final repository = await _repository;
      final audios = await repository.loadAudios();
      await repository.saveAudios(<VaultAudio>[
        for (final audio in audios)
          if (audio.id == id)
            type == null
                ? audio.copyWith(clearCategoryOverride: true)
                : audio.copyWith(categoryOverride: type)
          else
            audio,
      ]);
      ref.invalidateSelf();
      await future;
    });
  }

  /// Moves [ids] to the recycle bin.
  Future<void> moveToTrash(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
      final repository = await _repository;
      final store = ref.read(vaultAudioStoreProvider);
      final audios = await repository.loadAudios();
      final now = DateTime.now();
      final next = <VaultAudio>[];
      for (final audio in audios) {
        if (!ids.contains(audio.id)) {
          next.add(audio);
          continue;
        }
        try {
          await store.moveToTrash(audio.vaultFileName);
        } catch (_) {
          // Keep the row; a failed move must not lose the metadata.
        }
        next.add(audio.copyWith(trashedAt: now));
      }
      await repository.saveAudios(next);
      ref.invalidateSelf();
      await future;
    });
  }

  Future<void> restoreFromTrash(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
      final repository = await _repository;
      final store = ref.read(vaultAudioStoreProvider);
      final audios = await repository.loadAudios();
      final next = <VaultAudio>[];
      for (final audio in audios) {
        if (!ids.contains(audio.id)) {
          next.add(audio);
          continue;
        }
        try {
          await store.restoreFromTrash(audio.vaultFileName);
        } catch (_) {}
        next.add(audio.copyWith(clearTrash: true));
      }
      await repository.saveAudios(next);
      ref.invalidateSelf();
      await future;
    });
  }

  Future<void> deletePermanently(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
      final repository = await _repository;
      final store = ref.read(vaultAudioStoreProvider);
      final audios = await repository.loadAudios();
      final next = <VaultAudio>[];
      for (final audio in audios) {
        if (!ids.contains(audio.id)) {
          next.add(audio);
          continue;
        }
        try {
          await store.deletePermanently(audio.vaultFileName);
        } catch (_) {}
      }
      await repository.saveAudios(next);
      ref.invalidateSelf();
      await future;
    });
  }

  /// Drops every row currently in the recycle bin, blobs included.
  Future<void> emptyTrash() {
    return _serialize(() async {
      final repository = await _repository;
      final store = ref.read(vaultAudioStoreProvider);
      final audios = await repository.loadAudios();
      final next = <VaultAudio>[];
      for (final audio in audios) {
        if (!audio.isTrashed) {
          next.add(audio);
          continue;
        }
        try {
          await store.deletePermanently(audio.vaultFileName);
        } catch (_) {}
      }
      await repository.saveAudios(next);
      ref.invalidateSelf();
      await future;
    });
  }

  Future<void> setSort(VaultAudioSort sort) {
    return _serialize(() async {
      final repository = await _repository;
      await repository.saveSort(sort);
      ref.invalidateSelf();
      await future;
    });
  }

  /// Deletes trashed audios older than [trashRetention], blobs included.
  Future<void> purgeExpiredTrash() {
    return _serialize(() async {
      final repository = await _repository;
      final audios = await repository.loadAudios();
      await _purgeExpiredTrash(audios, repository);
      ref.invalidateSelf();
      await future;
    });
  }

  /// Shares [audios] as decrypted temporary files.
  ///
  /// The plaintext copies live in a private cache directory only for the
  /// duration of the share sheet and are deleted afterwards, best-effort —
  /// the plaintext never lands anywhere the user or another app can browse
  /// to. On the web there is no share sheet, so the same action becomes a
  /// browser download. A genuine failure (an unreadable audio, a refused
  /// share) throws, so the caller can tell "not supported here" apart from
  /// "went wrong".
  Future<bool> shareAudios(List<VaultAudio> audios) async {
    if (audios.isEmpty) return true;
    if (kIsWeb) {
      for (final audio in audios) {
        final bytes = await readAudio(audio);
        await downloadDocument(audio.fileName, bytes, audio.mimeType);
      }
      return true;
    }
    final scratch = Directory(
      '${(await getTemporaryDirectory()).path}/vault-share',
    );
    if (!await scratch.exists()) await scratch.create(recursive: true);
    final files = <XFile>[];
    for (final audio in audios) {
      final bytes = await readAudio(audio);
      final temp = File('${scratch.path}/${audio.fileName}');
      await temp.writeAsBytes(bytes, flush: true);
      files.add(XFile(temp.path, mimeType: audio.mimeType));
    }
    if (files.isEmpty) return true;
    await SharePlus.instance.share(ShareParams(files: files));
    try {
      await scratch.delete(recursive: true);
    } catch (_) {}
    return true;
  }

  /// True when [pick] duplicates an audio already in the vault.
  ///
  /// Content-hash first (the real "same file" test), then name-and-size as
  /// the fallback for a record written before fingerprints existed.
  static bool _isDuplicate(
    List<VaultAudio> existing,
    PickedAudio pick,
    String hash,
  ) {
    final name = pick.name.toLowerCase();
    for (final audio in existing) {
      if (audio.isTrashed) continue;
      if (audio.contentHash != null && audio.contentHash == hash) {
        return true;
      }
      if (audio.fileName.toLowerCase() == name &&
          audio.fileSize == pick.bytes.length) {
        return true;
      }
    }
    return false;
  }

  /// [name], or `name (2)`/`(3)` when a visible audio already wears it.
  static String _uniqueName(List<VaultAudio> existing, String name) {
    final taken = <String>{
      for (final audio in existing)
        if (!audio.isTrashed) audio.fileName.toLowerCase(),
    };
    if (!taken.contains(name.toLowerCase())) return name;
    final suffix = _extensionSuffix(name);
    final stem = suffix.isEmpty
        ? name
        : name.substring(0, name.length - suffix.length);
    var index = 2;
    while (taken.contains('$stem ($index)$suffix'.toLowerCase())) {
      index++;
    }
    return '$stem ($index)$suffix';
  }

  /// The user-facing name minus any path the picker may have included.
  static String _sanitizeName(String name) {
    final parts = name.split(RegExp(r'[/\\]'));
    final last = parts.isEmpty ? name : parts.last.trim();
    return last.isEmpty ? name.trim() : last;
  }

  /// The `.ext` part of [name] (including the dot), or `''`.
  static String _extensionSuffix(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot);
  }

  /// Best-effort MIME type from the extension, for the share/export step.
  static String _mimeTypeOf(String name) {
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'mp3' => 'audio/mpeg',
      'wav' => 'audio/wav',
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'flac' => 'audio/flac',
      'ogg' => 'audio/ogg',
      'opus' => 'audio/opus',
      'amr' => 'audio/amr',
      '3gp' => 'audio/3gpp',
      'wma' => 'audio/x-ms-wma',
      'aiff' || 'aif' => 'audio/aiff',
      _ => 'application/octet-stream',
    };
  }

  static Future<String> _sha256Hex(Uint8List bytes) async {
    final hash = await Sha256().hash(bytes);
    final buffer = StringBuffer();
    for (final byte in hash.bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

final vaultAudiosProvider =
    AsyncNotifierProvider<VaultAudiosNotifier, VaultAudiosState>(
      VaultAudiosNotifier.new,
    );
