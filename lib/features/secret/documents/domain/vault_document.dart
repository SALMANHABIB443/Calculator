/// The private document vault's value types (FEAT-SEC-009).
///
/// A document is a row of *metadata* — a name, a size, two dates, and a
/// fingerprint — plus an encrypted blob under the app-private vault directory.
/// Nothing here holds bytes or a path: [vaultFileName] is the blob's name
/// inside the vault, never an absolute path, so a stored record cannot leak the
/// device layout through a log line or a share sheet.
library;

/// One private document inside the vault (FEAT-SEC-009).
class VaultDocument {
  const VaultDocument({
    required this.id,
    required this.fileName,
    required this.vaultFileName,
    required this.mimeType,
    required this.fileSize,
    required this.dateAdded,
    required this.dateModified,
    this.contentHash,
    this.trashedAt,
  });

  final String id;

  /// The name the user sees and chose, extension included, e.g. `Report.pdf`.
  ///
  /// Kept verbatim (minus path separators) so the extension the user picked is
  /// the extension that decides which viewer opens.
  final String fileName;

  /// The encrypted blob's name inside the app-private vault directory.
  final String vaultFileName;

  final String mimeType;

  /// The *plaintext* size in bytes — the size the user's file had before it was
  /// encrypted, which is the number a file manager should show.
  final int fileSize;

  final DateTime dateAdded;
  final DateTime dateModified;

  /// Hex SHA-256 of the plaintext contents, or `null` for a record written
  /// before fingerprints existed. Used only to refuse a duplicate import; it is
  /// a digest, not the content, so it is safe to keep beside the other metadata.
  final String? contentHash;

  final DateTime? trashedAt;

  bool get isTrashed => trashedAt != null;

  /// The viewer family this document belongs to, from its extension.
  VaultDocumentType get type => VaultDocumentType.fromFileName(fileName);

  /// The uppercase extension shown beside the name, or `FILE` when there is
  /// none — never a bare dot.
  String get extensionLabel => VaultDocumentType.extensionLabel(fileName);

  VaultDocument copyWith({
    String? fileName,
    DateTime? trashedAt,
    bool clearTrash = false,
  }) {
    return VaultDocument(
      id: id,
      fileName: fileName ?? this.fileName,
      vaultFileName: vaultFileName,
      mimeType: mimeType,
      fileSize: fileSize,
      dateAdded: dateAdded,
      dateModified: dateModified,
      contentHash: contentHash,
      trashedAt: clearTrash ? null : (trashedAt ?? this.trashedAt),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'fileName': fileName,
    'vaultFileName': vaultFileName,
    'mimeType': mimeType,
    'fileSize': fileSize,
    'dateAdded': dateAdded.toIso8601String(),
    'dateModified': dateModified.toIso8601String(),
    if (contentHash != null) 'contentHash': contentHash,
    if (trashedAt != null) 'trashedAt': trashedAt!.toIso8601String(),
  };

  /// Rebuilds a record, or returns `null` when the JSON is not one this version
  /// can trust. A `null` costs one row, never the list.
  static VaultDocument? fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id'];
      final fileName = json['fileName'];
      final vaultFileName = json['vaultFileName'];
      final mimeType = json['mimeType'];
      final fileSize = json['fileSize'];
      final dateAdded = json['dateAdded'];
      final dateModified = json['dateModified'];
      if (id is! String ||
          fileName is! String ||
          vaultFileName is! String ||
          mimeType is! String ||
          fileSize is! int ||
          dateAdded is! String ||
          dateModified is! String) {
        return null;
      }
      final rawHash = json['contentHash'];
      final rawTrash = json['trashedAt'];
      return VaultDocument(
        id: id,
        fileName: fileName,
        vaultFileName: vaultFileName,
        mimeType: mimeType,
        fileSize: fileSize,
        dateAdded: DateTime.tryParse(dateAdded) ?? DateTime.now(),
        dateModified: DateTime.tryParse(dateModified) ?? DateTime.now(),
        contentHash: rawHash is String ? rawHash : null,
        trashedAt: rawTrash is String ? DateTime.tryParse(rawTrash) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The three viewer families the filter row offers, plus everything else.
///
/// Membership is decided by extension rather than by MIME type: the MIME type a
/// picker reports for `.docx` is unreliable across providers, while the
/// extension is exactly what the user named the file.
enum VaultDocumentType {
  pdf('pdf'),
  word('word'),
  text('text'),
  other('other');

  const VaultDocumentType(this.storageKey);

  /// The stable string written to storage; never the label.
  final String storageKey;

  /// The short label used in chips and section titles.
  String get label => switch (this) {
    VaultDocumentType.pdf => 'PDF',
    VaultDocumentType.word => 'Word',
    VaultDocumentType.text => 'Text',
    VaultDocumentType.other => 'Other',
  };

  /// Extensions (dot-less, lowercase) that belong to each family.
  static const Map<VaultDocumentType, Set<String>> extensions =
      <VaultDocumentType, Set<String>>{
        VaultDocumentType.pdf: <String>{'pdf'},
        VaultDocumentType.word: <String>{'doc', 'docx'},
        VaultDocumentType.text: <String>{
          'txt',
          'text',
          'md',
          'markdown',
          'log',
        },
      };

  static VaultDocumentType fromFileName(String name) {
    final extension = _extensionOf(name);
    for (final entry in extensions.entries) {
      if (entry.value.contains(extension)) return entry.key;
    }
    return VaultDocumentType.other;
  }

  /// `PDF`, `DOCX`, or `FILE` when the name carries no extension.
  static String extensionLabel(String name) {
    final extension = _extensionOf(name);
    return extension.isEmpty ? 'FILE' : extension.toUpperCase();
  }

  /// The dot-less lowercase extension, or `''` when there is none.
  ///
  /// A leading-dot name (`'.gitignore'`) has no extension: the dot is the whole
  /// name, not a separator.
  static String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    final extension = name.substring(dot + 1).toLowerCase();
    return extension.length > 12 ? '' : extension;
  }
}

/// Ordering the user picked; persisted in `shared_preferences`.
enum VaultDocumentSort {
  newestFirst,
  oldestFirst,
  nameAz,
  sizeLargest;

  String get storageKey => name;

  String get label => switch (this) {
    VaultDocumentSort.newestFirst => 'Newest first',
    VaultDocumentSort.oldestFirst => 'Oldest first',
    VaultDocumentSort.nameAz => 'Name A–Z',
    VaultDocumentSort.sizeLargest => 'Largest first',
  };

  static VaultDocumentSort fromStorageKey(String? key) {
    for (final sort in VaultDocumentSort.values) {
      if (sort.storageKey == key) return sort;
    }
    return VaultDocumentSort.newestFirst;
  }
}

/// The filter row's chips: All, PDF, Word, Text.
enum VaultDocumentFilter {
  all('All'),
  pdf('PDF'),
  word('Word'),
  text('Text');

  const VaultDocumentFilter(this.label);

  final String label;

  /// The type a document must be to pass this filter, or `null` for All.
  VaultDocumentType? get type => switch (this) {
    VaultDocumentFilter.all => null,
    VaultDocumentFilter.pdf => VaultDocumentType.pdf,
    VaultDocumentFilter.word => VaultDocumentType.word,
    VaultDocumentFilter.text => VaultDocumentType.text,
  };

  bool matches(VaultDocument document) =>
      type == null || document.type == type;
}
