import '../data/vault_document_picker.dart';
import '../domain/vault_document.dart';

/// The persisted document snapshot: every metadata row plus the stored sort
/// (FEAT-SEC-009).
///
/// Search text and the type filter are deliberately *not* here. They are
/// transient UI state ([VaultDocumentView]) because this snapshot is rebuilt
/// from disk after every mutation — a delete that also reset the user's search
/// would read as the search box clearing itself.
class VaultDocumentsState {
  const VaultDocumentsState({required this.documents, required this.sort});

  final List<VaultDocument> documents;
  final VaultDocumentSort sort;

  /// Everything not in the recycle bin.
  List<VaultDocument> get visible => <VaultDocument>[
    for (final document in documents)
      if (!document.isTrashed) document,
  ];

  /// Everything in the recycle bin.
  List<VaultDocument> get trash => <VaultDocument>[
    for (final document in documents)
      if (document.isTrashed) document,
  ];

  /// The count a chip shows, over the *visible* documents.
  int countOf(VaultDocumentFilter filter) {
    var count = 0;
    for (final document in visible) {
      if (filter.matches(document)) count++;
    }
    return count;
  }

  /// Total plaintext size of the visible documents, in bytes.
  int get totalBytes {
    var total = 0;
    for (final document in visible) {
      total += document.fileSize;
    }
    return total;
  }

  /// Total plaintext size of the recycle bin, in bytes.
  int get trashBytes {
    var total = 0;
    for (final document in trash) {
      total += document.fileSize;
    }
    return total;
  }

  /// The visible documents that pass [view]'s type filter and query, sorted.
  ///
  /// Case-insensitive substring match on the human filename, which is what a
  /// user typing "rep" expects to find for `Report.pdf`.
  List<VaultDocument> resolve(VaultDocumentView view) {
    final needle = view.query.trim().toLowerCase();
    final list = <VaultDocument>[
      for (final document in visible)
        if (view.typeFilter.matches(document) &&
            (needle.isEmpty || document.fileName.toLowerCase().contains(needle)))
          document,
    ];
    list.sort(_compare);
    return list;
  }

  int _compare(VaultDocument a, VaultDocument b) => switch (sort) {
    VaultDocumentSort.newestFirst => b.dateAdded.compareTo(a.dateAdded),
    VaultDocumentSort.oldestFirst => a.dateAdded.compareTo(b.dateAdded),
    VaultDocumentSort.nameAz => a.fileName.toLowerCase().compareTo(
      b.fileName.toLowerCase(),
    ),
    VaultDocumentSort.sizeLargest => b.fileSize.compareTo(a.fileSize),
  };
}

/// The transient, in-memory view over the snapshot: search text + type chip.
class VaultDocumentView {
  const VaultDocumentView({
    this.query = '',
    this.typeFilter = VaultDocumentFilter.all,
  });

  final String query;
  final VaultDocumentFilter typeFilter;

  bool get hasQuery => query.trim().isNotEmpty;

  /// True when the user has narrowed the list at all.
  bool get isFiltered =>
      hasQuery || typeFilter != VaultDocumentFilter.all;

  VaultDocumentView copyWith({
    String? query,
    VaultDocumentFilter? typeFilter,
  }) {
    return VaultDocumentView(
      query: query ?? this.query,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }
}

/// What one import round actually did, so the screen can report it honestly
/// rather than guessing from a count that includes skipped files.
class VaultImportResult {
  const VaultImportResult({
    this.imported = 0,
    this.duplicates = const <PickedDocument>[],
    this.failed = 0,
    this.cancelled = false,
  });

  /// Files encrypted and added.
  final int imported;

  /// Files refused because a document with the same contents (or name and size)
  /// is already in the vault. Carried whole so the user can be offered the
  /// choice to add them anyway without picking again.
  final List<PickedDocument> duplicates;

  /// Files whose bytes could not be read or written.
  final int failed;

  /// The user dismissed the picker.
  final bool cancelled;

  bool get hasWork => imported > 0 || duplicates.isNotEmpty || failed > 0;

  bool get isEmpty => !hasWork && !cancelled;
}
