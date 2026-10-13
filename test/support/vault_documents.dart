/// Shared fixtures for the private document vault's tests (FEAT-SEC-009).
///
/// The documents feature reads through three seams — a cipher, a byte store,
/// and a picker — and every one of them reaches a platform the test host does
/// not have. This file provides honest doubles for all three: a *real*
/// AES-256-GCM cipher over a fixed in-process key, an in-memory store that still
/// encrypts, and a picker that returns what a test hands it. Nothing here is a
/// no-op, because the whole point of these tests is that the bytes are actually
/// encrypted and actually round-trip.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:calculator/features/secret/documents/documents.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The fixed 32-byte key every harness cipher runs on.
///
/// Fixed rather than random so two harness ciphers read each other's blobs,
/// which is what lets a test build a second provider container over the same
/// store and prove the bytes survive a restart.
Uint8List harnessVaultKey() =>
    Uint8List.fromList(List<int>.generate(32, (index) => index));

/// A real AES-256-GCM cipher over a fixed, in-process key.
VaultDocumentCipher harnessVaultCipher() =>
    AesGcmVaultDocumentCipher(InMemoryVaultKeySource(harnessVaultKey()));

/// An in-memory [VaultDocumentStore]: the web store's contract without a
/// platform channel, and still encrypted through [cipher].
class InMemoryVaultDocumentStore extends VaultDocumentStore {
  InMemoryVaultDocumentStore(this._cipher);

  final VaultDocumentCipher _cipher;
  final Map<String, Uint8List> _live = <String, Uint8List>{};
  final Map<String, Uint8List> _trash = <String, Uint8List>{};

  Map<String, Uint8List> _bucket(bool trashed) => trashed ? _trash : _live;

  /// The ciphertext stored for a live document — for "not plaintext" checks.
  Uint8List? ciphertextOf(String vaultFileName) => _live[vaultFileName];

  /// The ciphertext currently in the recycle bin, for the same reason.
  Uint8List? trashedCiphertextOf(String vaultFileName) => _trash[vaultFileName];

  @override
  Future<Uint8List?> readBytes(
    String vaultFileName, {
    bool trashed = false,
  }) async {
    final stored = _bucket(trashed)[vaultFileName];
    return stored == null ? null : _cipher.decrypt(stored);
  }

  @override
  Future<void> importBytes(Uint8List bytes, String vaultFileName) async {
    _live[vaultFileName] = await _cipher.encrypt(bytes);
  }

  @override
  Future<void> moveToTrash(String vaultFileName) async {
    final bytes = _live.remove(vaultFileName);
    if (bytes != null) _trash[vaultFileName] = bytes;
  }

  @override
  Future<void> restoreFromTrash(String vaultFileName) async {
    final bytes = _trash.remove(vaultFileName);
    if (bytes != null) _live[vaultFileName] = bytes;
  }

  @override
  Future<void> deletePermanently(String vaultFileName) async {
    _live.remove(vaultFileName);
    _trash.remove(vaultFileName);
  }

  @override
  Future<bool> get isEmpty async => _live.isEmpty && _trash.isEmpty;
}

/// A picker that returns what a test hands it and never raises a native dialog.
///
/// An empty [picked] is how a cancellation is modelled, matching the contract
/// ([VaultDocumentPicker.pickDocuments] returns an empty list when dismissed).
class FakeVaultDocumentPicker implements VaultDocumentPicker {
  FakeVaultDocumentPicker([this.picked = const <PickedDocument>[]]);

  /// The files the next [pickDocuments] hands back.
  List<PickedDocument> picked;

  /// How many times a screen asked to pick.
  int calls = 0;

  @override
  Future<List<PickedDocument>> pickDocuments() async {
    calls++;
    return picked;
  }
}

/// A picked file whose bytes are the UTF-8 encoding of [contents].
PickedDocument pickedTextFile(String name, String contents) =>
    PickedDocument(name: name, bytes: Uint8List.fromList(utf8.encode(contents)));

/// A document record with sensible defaults, for seeding a repository.
VaultDocument seededDocument({
  required String id,
  required String fileName,
  int fileSize = 100,
  DateTime? dateAdded,
  String? contentHash,
  DateTime? trashedAt,
}) {
  final date = dateAdded ?? DateTime(2026, 1, 2);
  return VaultDocument(
    id: id,
    fileName: fileName,
    vaultFileName: '$id.bin',
    mimeType: 'application/octet-stream',
    fileSize: fileSize,
    dateAdded: date,
    dateModified: date,
    contentHash: contentHash,
    trashedAt: trashedAt,
  );
}

/// The overrides every documents test needs, over the doubles above.
///
/// The store and the cipher are built from the *same* key, and the store passed
/// in is the one the caller can interrogate afterwards, so an assertion about
/// what landed on "disk" is about the bytes the controller actually wrote.
List<Override> vaultDocumentOverrides({
  VaultDocumentRepository? repository,
  VaultDocumentPicker? picker,
  InMemoryVaultDocumentStore? store,
}) {
  final cipher = harnessVaultCipher();
  return <Override>[
    vaultDocumentCipherProvider.overrideWithValue(cipher),
    vaultDocumentStoreProvider.overrideWithValue(
      store ?? InMemoryVaultDocumentStore(cipher),
    ),
    vaultDocumentRepositoryProvider.overrideWith(
      (ref) async => repository ?? InMemoryVaultDocumentRepository(),
    ),
    vaultDocumentPickerProvider.overrideWithValue(
      picker ?? FakeVaultDocumentPicker(),
    ),
    // `pdfx` opens a platform channel and its Windows viewer throws outright,
    // so the viewer's real body is replaced with a marker a test can find. The
    // optional named parameters mirror the seam's typedef; a stub has no use
    // for fileName or mimeType.
    vaultPdfViewerBuilderProvider.overrideWithValue(
      (
        context,
        bytes, {
        String? fileName,
        String? mimeType,
      }) => const ColoredBox(
        color: Color(0xFF101011),
        child: Center(child: Text('pdf-stub')),
      ),
    ),
  ];
}
