import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/vault_document.dart';
import 'vault_document_repository.dart';

/// [VaultDocumentRepository] over `shared_preferences` (D-02, FEAT-SEC-009).
///
/// One key, one JSON list, capped like the history and image repositories. Only
/// *metadata* lives here — names, sizes, dates, a content digest, and the trash
/// timestamp. The document contents are encrypted blobs in the vault directory,
/// so a leaked preferences file exposes a file index, never a file.
class SharedPreferencesVaultDocumentRepository
    implements VaultDocumentRepository {
  const SharedPreferencesVaultDocumentRepository(this._preferences);

  final SharedPreferences _preferences;

  static const String documentsKey = 'vaultDocuments';
  static const String sortKey = 'vaultDocumentSort';

  @override
  Future<List<VaultDocument>> loadDocuments() async {
    try {
      final stored = _preferences.getString(documentsKey);
      if (stored == null) return <VaultDocument>[];
      final decoded = jsonDecode(stored);
      if (decoded is! List) return <VaultDocument>[];
      final documents = <VaultDocument>[];
      for (final record in decoded) {
        if (record is! Map<String, dynamic>) continue;
        final document = VaultDocument.fromJson(record);
        if (document != null) documents.add(document);
      }
      return documents;
    } on FormatException {
      return <VaultDocument>[];
    } on TypeError {
      return <VaultDocument>[];
    }
  }

  @override
  Future<void> saveDocuments(List<VaultDocument> documents) async {
    await _preferences.setString(
      documentsKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final document in documents) document.toJson(),
      ]),
    );
  }

  @override
  Future<VaultDocumentSort> loadSort() async {
    try {
      return VaultDocumentSort.fromStorageKey(_preferences.getString(sortKey));
    } on TypeError {
      return VaultDocumentSort.newestFirst;
    }
  }

  @override
  Future<void> saveSort(VaultDocumentSort sort) async {
    await _preferences.setString(sortKey, sort.storageKey);
  }
}

/// In-memory fake for tests and as the app's fallback when the plugin is
/// unavailable: same contract, no platform needed.
class InMemoryVaultDocumentRepository implements VaultDocumentRepository {
  List<VaultDocument> documents;
  VaultDocumentSort sort;

  InMemoryVaultDocumentRepository({
    List<VaultDocument>? documents,
    this.sort = VaultDocumentSort.newestFirst,
  }) : documents = documents ?? <VaultDocument>[];

  @override
  Future<List<VaultDocument>> loadDocuments() async =>
      List<VaultDocument>.unmodifiable(documents);

  @override
  Future<void> saveDocuments(List<VaultDocument> value) async {
    documents = List<VaultDocument>.from(value);
  }

  @override
  Future<VaultDocumentSort> loadSort() async => sort;

  @override
  Future<void> saveSort(VaultDocumentSort value) async {
    sort = value;
  }
}
