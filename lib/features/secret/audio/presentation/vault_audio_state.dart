import '../data/vault_audio_picker.dart';
import '../domain/vault_audio.dart';

/// The persisted audio snapshot: every metadata row plus the stored sort.
///
/// Search text and the type filter live in [VaultAudioView], not here. This
/// snapshot is rebuilt from disk after every mutation — a delete that also
/// reset the user's search would read as the search box clearing itself.
class VaultAudiosState {
  const VaultAudiosState({required this.audios, required this.sort});

  final List<VaultAudio> audios;
  final VaultAudioSort sort;

  /// Everything not in the recycle bin.
  List<VaultAudio> get visible => <VaultAudio>[
    for (final audio in audios)
      if (!audio.isTrashed) audio,
  ];

  /// Everything in the recycle bin.
  List<VaultAudio> get trash => <VaultAudio>[
    for (final audio in audios)
      if (audio.isTrashed) audio,
  ];

  /// The visible audios the user starred.
  List<VaultAudio> get favorites => <VaultAudio>[
    for (final audio in visible)
      if (audio.isFavorite) audio,
  ];

  /// The count a chip shows, over the *visible* audios.
  int countOf(VaultAudioFilter filter) {
    var count = 0;
    for (final audio in visible) {
      if (filter.matches(audio)) count++;
    }
    return count;
  }

  /// Total plaintext size of the visible audios, in bytes.
  int get totalBytes {
    var total = 0;
    for (final audio in visible) {
      total += audio.fileSize;
    }
    return total;
  }

  /// Total plaintext size of the recycle bin, in bytes.
  int get trashBytes {
    var total = 0;
    for (final audio in trash) {
      total += audio.fileSize;
    }
    return total;
  }

  /// The visible audios that pass [view]'s type filter and query, sorted.
  ///
  /// Case-insensitive substring match on the human filename, which is what a
  /// user typing "mix" expects to find for `Mix_Tape.mp3`.
  List<VaultAudio> resolve(VaultAudioView view) {
    final needle = view.query.trim().toLowerCase();
    final list = <VaultAudio>[
      for (final audio in visible)
        if (view.typeFilter.matches(audio) &&
            (needle.isEmpty || audio.fileName.toLowerCase().contains(needle)))
          audio,
    ];
    list.sort(_compare);
    return list;
  }

  int _compare(VaultAudio a, VaultAudio b) => switch (sort) {
    VaultAudioSort.newestFirst => b.dateAdded.compareTo(a.dateAdded),
    VaultAudioSort.oldestFirst => a.dateAdded.compareTo(b.dateAdded),
    VaultAudioSort.nameAz => a.fileName.toLowerCase().compareTo(
      b.fileName.toLowerCase(),
    ),
    VaultAudioSort.sizeLargest => b.fileSize.compareTo(a.fileSize),
  };
}

/// The transient, in-memory view over the snapshot: search text + type chip.
class VaultAudioView {
  const VaultAudioView({
    this.query = '',
    this.typeFilter = VaultAudioFilter.all,
  });

  final String query;
  final VaultAudioFilter typeFilter;

  bool get hasQuery => query.trim().isNotEmpty;

  /// True when the user has narrowed the list at all.
  bool get isFiltered => hasQuery || typeFilter != VaultAudioFilter.all;

  VaultAudioView copyWith({String? query, VaultAudioFilter? typeFilter}) {
    return VaultAudioView(
      query: query ?? this.query,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }
}

/// What one import round actually did, so the screen can report it honestly
/// rather than guessing from a count that includes skipped files.
class VaultAudioImportResult {
  const VaultAudioImportResult({
    this.imported = 0,
    this.duplicates = const <PickedAudio>[],
    this.failed = 0,
    this.cancelled = false,
  });

  /// Files encrypted and added.
  final int imported;

  /// Files refused because an audio with the same contents (or name and size)
  /// is already in the vault. Carried whole so the user can be offered the
  /// choice to add them anyway without picking again.
  final List<PickedAudio> duplicates;

  /// Files whose bytes could not be read or written.
  final int failed;

  /// The user dismissed the picker.
  final bool cancelled;

  bool get hasWork => imported > 0 || duplicates.isNotEmpty || failed > 0;

  bool get isEmpty => !hasWork && !cancelled;
}
