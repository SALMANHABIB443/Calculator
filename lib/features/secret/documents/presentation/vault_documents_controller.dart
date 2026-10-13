import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/uuid.dart';
import '../data/vault_document_downloader.dart';
import '../data/vault_document_picker.dart';
import '../data/vault_document_repository.dart';
import '../domain/vault_document.dart';
import 'vault_documents_providers.dart';
import 'vault_documents_state.dart';

/// A rename was rejected: empty, or a name another document already wears.
///
/// Carries a message the screen can drop straight into a snackbar, for the same
/// reason the image gallery's `AlbumNameException` does.
class VaultDocumentNameException implements Exception {
  const VaultDocumentNameException(this.message);

  final String message;

  @override
  String toString() => 'VaultDocumentNameException: $message';
}

/// A document's bytes were expected but the vault has none.
class VaultDocumentMissingException implements Exception {
  const VaultDocumentMissingException(this.fileName);

  final String fileName;

  @override
  String toString() =>
      'VaultDocumentMissingException: no stored bytes for $fileName';
}

/// Reads, imports, renames, trashes, restores, and sorts vault documents
/// (FEAT-SEC-009).
///
/// Mirrors `VaultImagesNotifier`: the repository is awaited per call, every
/// mutation re-saves the whole metadata list and then `invalidateSelf()` so the
/// list rebuilds from storage rather than from a stale copy. All mutations run
/// through [_serialize], so two overlapping read-modify-writes over the one
/// preferences key cannot drop each other's change.
class VaultDocumentsNotifier extends AsyncNotifier<VaultDocumentsState> {
  /// How long a trashed document is kept before it is deleted for good.
  static const Duration trashRetention = Duration(days: 30);

  Future<void> _mutations = Future<void>.value();

  @override
  Future<VaultDocumentsState> build() async {
    final repository = await ref.watch(vaultDocumentRepositoryProvider.future);
    var documents = await repository.loadDocuments();
    final sort = await repository.loadSort();

    if (kIsWeb && await ref.read(vaultDocumentStoreProvider).isEmpty) {
      // A browser refresh drops the in-memory blob store but keeps the
      // localStorage metadata, and the new session key cannot decrypt the old
      // blobs. Drop the rows that no longer have readable bytes; the screen
      // would otherwise list entries that can never open.
      if (documents.isNotEmpty) {
        documents = const <VaultDocument>[];
        await repository.saveDocuments(documents);
      }
    }

    await _purgeExpiredTrash(documents, repository);
    return VaultDocumentsState(documents: documents, sort: sort);
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
    return previous
        .then((_) => action())
        .whenComplete(() {
          if (!gate.isCompleted) gate.complete();
        });
  }

  Future<VaultDocumentRepository> get _repository =>
      ref.read(vaultDocumentRepositoryProvider.future);

  Future<void> _purgeExpiredTrash(
    List<VaultDocument> documents,
    VaultDocumentRepository repository,
  ) async {
    final store = ref.read(vaultDocumentStoreProvider);
    final now = DateTime.now();
    var changed = false;
    final kept = <VaultDocument>[];
    for (final document in documents) {
      final trashedAt = document.trashedAt;
      if (trashedAt != null && now.difference(trashedAt) > trashRetention) {
        try {
          await store.deletePermanently(document.vaultFileName);
        } catch (_) {
          // A file that is already gone is not a reason to keep the row.
        }
        changed = true;
      } else {
        kept.add(document);
      }
    }
    if (changed) await repository.saveDocuments(kept);
  }

  /// The document's decrypted bytes, for the viewer.
  ///
  /// Throws [VaultDocumentMissingException] when the blob is gone or cannot be
  /// decrypted, so the viewer can show an honest "unavailable" state rather
  /// than a blank page.
  Future<Uint8List> readDocument(VaultDocument document) async {
    final bytes = await ref
        .read(vaultDocumentStoreProvider)
        .readBytes(document.vaultFileName, trashed: document.isTrashed);
    if (bytes == null) {
      throw VaultDocumentMissingException(document.fileName);
    }
    return bytes;
  }

  /// Picks files and imports them into the vault.
  ///
  /// Pass [selection] to import a set the user already chose (the "add the
  /// duplicates anyway" path) instead of reopening the picker. When
  /// [allowDuplicates] is false, a file whose contents, or name and size, match
  /// a document already in the vault is reported in
  /// [VaultImportResult.duplicates] and not stored. A per-file read/encrypt
  /// failure is counted, never thrown, so one unreadable file cannot abort the
  /// rest of a multi-select.
  Future<VaultImportResult> importDocuments({
    List<PickedDocument>? selection,
    bool allowDuplicates = false,
  }) {
    return _serialize(() async {
      List<PickedDocument> picked;
      if (selection != null) {
        picked = selection;
      } else {
        picked = await ref.read(vaultDocumentPickerProvider).pickDocuments();
        if (picked.isEmpty) {
          return const VaultImportResult(cancelled: true);
        }
      }

      final repository = await _repository;
      final store = ref.read(vaultDocumentStoreProvider);
      // Copied into a mutable list *before* anything is appended: the
      // repository is free to hand back an unmodifiable view (the in-memory
      // fallback does), and mutating what a store returned is how a repository
      // change would silently break the import path.
      final existing = <VaultDocument>[
        ...await repository.loadDocuments(),
      ];

      var imported = 0;
      var failed = 0;
      final duplicates = <PickedDocument>[];

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
          final name = _uniqueName(existing, pick.name);
          final vaultName = '${uuidV4()}${_extensionSuffix(name)}';
          await store.importBytes(bytes, vaultName);
          final now = DateTime.now();
          existing.add(
            VaultDocument(
              id: uuidV4(),
              fileName: name,
              vaultFileName: vaultName,
              mimeType: pick.mimeType ?? 'application/octet-stream',
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
        await repository.saveDocuments(existing);
        ref.invalidateSelf();
        await future;
      }
      return VaultImportResult(
        imported: imported,
        duplicates: duplicates,
        failed: failed,
      );
    });
  }

  /// Renames [id], keeping the original extension when the new name omits one.
  Future<void> renameDocument(String id, String newName) {
    return _serialize(() async {
      final trimmed = newName.trim();
      if (trimmed.isEmpty) {
        throw const VaultDocumentNameException('Enter a name.');
      }
      if (trimmed.contains('/') || trimmed.contains('\\')) {
        throw const VaultDocumentNameException(
          'A name cannot contain "/" or "\\".',
        );
      }
      final repository = await _repository;
      final documents = await repository.loadDocuments();
      VaultDocument? target;
      for (final document in documents) {
        if (document.id == id) {
          target = document;
          break;
        }
      }
      if (target == null) return;

      final withExtension = VaultDocumentType.extensionLabel(trimmed) == 'FILE'
          ? '$trimmed${_extensionSuffix(target.fileName)}'
          : trimmed;
      final taken = documents.any(
        (d) =>
            d.id != id &&
            !d.isTrashed &&
            d.fileName.toLowerCase() == withExtension.toLowerCase(),
      );
      if (taken) {
        throw VaultDocumentNameException(
          'A document named "$withExtension" already exists.',
        );
      }
      await repository.saveDocuments(<VaultDocument>[
        for (final document in documents)
          if (document.id == id)
            document.copyWith(fileName: withExtension)
          else
            document,
      ]);
      ref.invalidateSelf();
      await future;
    });
  }

  Future<void> moveToTrash(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
      final repository = await _repository;
      final store = ref.read(vaultDocumentStoreProvider);
      final documents = await repository.loadDocuments();
      final now = DateTime.now();
      final next = <VaultDocument>[];
      for (final document in documents) {
        if (!ids.contains(document.id)) {
          next.add(document);
          continue;
        }
        try {
          await store.moveToTrash(document.vaultFileName);
        } catch (_) {
          // Keep the row; a failed move must not lose the metadata.
        }
        next.add(document.copyWith(trashedAt: now));
      }
      await repository.saveDocuments(next);
      ref.invalidateSelf();
      await future;
    });
  }

  Future<void> restoreFromTrash(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
      final repository = await _repository;
      final store = ref.read(vaultDocumentStoreProvider);
      final documents = await repository.loadDocuments();
      final next = <VaultDocument>[];
      for (final document in documents) {
        if (!ids.contains(document.id)) {
          next.add(document);
          continue;
        }
        try {
          await store.restoreFromTrash(document.vaultFileName);
        } catch (_) {}
        next.add(document.copyWith(clearTrash: true));
      }
      await repository.saveDocuments(next);
      ref.invalidateSelf();
      await future;
    });
  }

  Future<void> deletePermanently(Set<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return _serialize(() async {
      final repository = await _repository;
      final store = ref.read(vaultDocumentStoreProvider);
      final documents = await repository.loadDocuments();
      final next = <VaultDocument>[];
      for (final document in documents) {
        if (!ids.contains(document.id)) {
          next.add(document);
          continue;
        }
        try {
          await store.deletePermanently(document.vaultFileName);
        } catch (_) {}
      }
      await repository.saveDocuments(next);
      ref.invalidateSelf();
      await future;
    });
  }

  Future<void> setSort(VaultDocumentSort sort) {
    return _serialize(() async {
      final repository = await _repository;
      await repository.saveSort(sort);
      ref.invalidateSelf();
      await future;
    });
  }

  /// Shares [documents] as decrypted temporary files (FEAT-SEC-009).
  ///
  /// The plaintext copies live in a private cache directory only for the
  /// duration of the share sheet and are deleted afterwards, best-effort — the
  /// plaintext never lands anywhere the user or another app can browse to.
  ///
  /// On the web there is no share sheet and no private cache directory, so
  /// the same action becomes a browser download: the decrypted bytes become
  /// a Blob the page clicks once. The caller's wording ("Share" versus
  /// "Download") stays the screen's job. A genuine failure (an unreadable
  /// document, a refused share) throws, so the caller can tell "not supported
  /// here" apart from "went wrong".
  Future<bool> shareDocuments(List<VaultDocument> documents) async {
    if (documents.isEmpty) return true;
    if (kIsWeb) {
      for (final document in documents) {
        final bytes = await readDocument(document);
        await downloadDocument(document.fileName, bytes, document.mimeType);
      }
      return true;
    }
    final scratch = Directory(
      '${(await getTemporaryDirectory()).path}/vault-share',
    );
    if (!await scratch.exists()) await scratch.create(recursive: true);
    final files = <XFile>[];
    for (final document in documents) {
      final bytes = await readDocument(document);
      final temp = File('${scratch.path}/${document.fileName}');
      await temp.writeAsBytes(bytes, flush: true);
      files.add(XFile(temp.path, mimeType: document.mimeType));
    }
    if (files.isEmpty) return true;
    await SharePlus.instance.share(ShareParams(files: files));
    try {
      await scratch.delete(recursive: true);
    } catch (_) {}
    return true;
  }

  /// True when [pick] duplicates a document already in the vault.
  ///
  /// Content-hash first (the real "same file" test), then name-and-size as the
  /// fallback for a record written before fingerprints existed.
  static bool _isDuplicate(
    List<VaultDocument> existing,
    PickedDocument pick,
    String hash,
  ) {
    final name = pick.name.toLowerCase();
    for (final document in existing) {
      if (document.isTrashed) continue;
      if (document.contentHash != null && document.contentHash == hash) {
        return true;
      }
      if (document.fileName.toLowerCase() == name &&
          document.fileSize == pick.bytes.length) {
        return true;
      }
    }
    return false;
  }

  /// [name], or ``name (2)``/`(3)` when a visible document already wears it.
  ///
  /// Only reached on a forced import; the suffix keeps two rows tellable apart
  /// instead of listing the same filename twice.
  static String _uniqueName(List<VaultDocument> existing, String name) {
    final taken = <String>{
      for (final document in existing)
        if (!document.isTrashed) document.fileName.toLowerCase(),
    };
    if (!taken.contains(name.toLowerCase())) return name;
    final suffix = _extensionSuffix(name);
    final stem = suffix.isEmpty ? name : name.substring(0, name.length - suffix.length);
    var index = 2;
    while (taken.contains('$stem ($index)$suffix'.toLowerCase())) {
      index++;
    }
    return '$stem ($index)$suffix';
  }

  /// The `.ext` part of [name] (including the dot), or `''`.
  static String _extensionSuffix(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot);
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

final vaultDocumentsProvider =
    AsyncNotifierProvider<VaultDocumentsNotifier, VaultDocumentsState>(
      VaultDocumentsNotifier.new,
    );
