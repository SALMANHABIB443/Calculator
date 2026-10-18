/// The private audio vault's value types.
///
/// An audio is a row of *metadata* — a name, a size, two dates, an optional
/// duration, and a fingerprint — plus an encrypted blob under the app-private
/// vault directory. Nothing here holds bytes or a path: [vaultFileName] is the
/// blob's name inside the vault, never an absolute path, so a stored record
/// cannot leak the device layout through a log line or a share sheet.
library;

/// One private audio inside the vault.
class VaultAudio {
  const VaultAudio({
    required this.id,
    required this.fileName,
    required this.vaultFileName,
    required this.mimeType,
    required this.fileSize,
    required this.dateAdded,
    required this.dateModified,
    this.durationMs,
    this.categoryOverride,
    this.isFavorite = false,
    this.contentHash,
    this.trashedAt,
  });

  final String id;

  /// The name the user sees and chose, extension included, e.g. `Song.mp3`.
  ///
  /// Kept verbatim (minus path separators) so the extension the user picked is
  /// the extension that decides the type and the MIME guess.
  final String fileName;

  /// The encrypted blob's name inside the app-private vault directory.
  final String vaultFileName;

  final String mimeType;

  /// The *plaintext* size in bytes — the size the user's file had before it was
  /// encrypted, which is the number a file manager should show.
  final int fileSize;

  final DateTime dateAdded;
  final DateTime dateModified;

  /// Playback length in milliseconds, or `null` until it is measured.
  final int? durationMs;

  /// The user's pinned category, which wins over the filename guess.
  final VaultAudioType? categoryOverride;

  final bool isFavorite;

  /// Hex SHA-256 of the plaintext contents, or `null` for a record written
  /// before fingerprints existed. Used only to refuse a duplicate import; it is
  /// a digest, not the content, so it is safe to keep beside the metadata.
  final String? contentHash;

  final DateTime? trashedAt;

  bool get isTrashed => trashedAt != null;

  /// The category this audio counts as: the override when the user pinned one,
  /// otherwise the filename guess.
  VaultAudioType get effectiveType =>
      categoryOverride ?? VaultAudioType.fromFileName(fileName);

  /// The uppercase extension shown beside the name, or `FILE` when there is
  /// none — never a bare dot.
  String get extensionLabel => VaultAudioType.extensionLabel(fileName);

  VaultAudio copyWith({
    String? fileName,
    int? durationMs,
    VaultAudioType? categoryOverride,
    bool clearCategoryOverride = false,
    bool? isFavorite,
    DateTime? trashedAt,
    bool clearTrash = false,
  }) {
    return VaultAudio(
      id: id,
      fileName: fileName ?? this.fileName,
      vaultFileName: vaultFileName,
      mimeType: mimeType,
      fileSize: fileSize,
      dateAdded: dateAdded,
      dateModified: dateModified,
      durationMs: durationMs ?? this.durationMs,
      categoryOverride: clearCategoryOverride
          ? null
          : (categoryOverride ?? this.categoryOverride),
      isFavorite: isFavorite ?? this.isFavorite,
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
    if (durationMs != null) 'durationMs': durationMs,
    if (categoryOverride != null)
      'categoryOverride': categoryOverride!.storageKey,
    if (isFavorite) 'isFavorite': true,
    if (contentHash != null) 'contentHash': contentHash,
    if (trashedAt != null) 'trashedAt': trashedAt!.toIso8601String(),
  };

  /// Rebuilds a record, or returns `null` when the JSON is not one this version
  /// can trust. A `null` costs one row, never the list.
  static VaultAudio? fromJson(Map<String, dynamic> json) {
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
      final rawDuration = json['durationMs'];
      final rawOverride = json['categoryOverride'];
      final rawFavorite = json['isFavorite'];
      final rawHash = json['contentHash'];
      final rawTrash = json['trashedAt'];
      return VaultAudio(
        id: id,
        fileName: fileName,
        vaultFileName: vaultFileName,
        mimeType: mimeType,
        fileSize: fileSize,
        dateAdded: DateTime.tryParse(dateAdded) ?? DateTime.now(),
        dateModified: DateTime.tryParse(dateModified) ?? DateTime.now(),
        durationMs: rawDuration is int ? rawDuration : null,
        categoryOverride: rawOverride is String
            ? VaultAudioType.fromStorageKey(rawOverride)
            : null,
        isFavorite: rawFavorite is bool ? rawFavorite : false,
        contentHash: rawHash is String ? rawHash : null,
        trashedAt: rawTrash is String ? DateTime.tryParse(rawTrash) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

/// The category families the filter row offers, plus everything else.
///
/// `m4a` and `wav` deliberately live in both the music and recording sets:
/// both families really use those containers, so the extension alone cannot
/// decide. [fromFileName] resolves the overlap by defaulting those extensions
/// to music and letting filename keywords claim an item as a recording
/// (`rec`, `voice`, `memo`, `recording`, `call`) or a podcast (`podcast`,
/// `episode`, `ep` + digits). A keyword guess is only ever a default — the
/// user's [VaultAudio.categoryOverride] wins through `effectiveType`.
///
/// Membership is decided by extension rather than by MIME type: the MIME type a
/// picker reports is unreliable across providers, while the extension is
/// exactly what the user named the file.
enum VaultAudioType {
  music('music'),
  recording('recording'),
  podcast('podcast'),
  other('other');

  const VaultAudioType(this.storageKey);

  /// The stable string written to storage; never the label.
  final String storageKey;

  /// The short label used in chips and section titles.
  String get label => switch (this) {
    VaultAudioType.music => 'Music',
    VaultAudioType.recording => 'Recordings',
    VaultAudioType.podcast => 'Podcasts',
    VaultAudioType.other => 'Other',
  };

  /// Extensions (dot-less, lowercase) that belong to each family.
  static const Map<VaultAudioType, Set<String>> extensions =
      <VaultAudioType, Set<String>>{
        VaultAudioType.music: <String>{
          'mp3',
          'wav',
          'flac',
          'aac',
          'ogg',
          'm4a',
          'opus',
          'wma',
          'aiff',
          'aif',
        },
        VaultAudioType.recording: <String>{'m4a', 'amr', '3gp', 'wav'},
      };

  /// Every extension any family claims; anything else is [other].
  static const Set<String> knownExtensions = <String>{
    'mp3',
    'wav',
    'flac',
    'aac',
    'ogg',
    'm4a',
    'opus',
    'wma',
    'aiff',
    'aif',
    'amr',
    '3gp',
  };

  static final RegExp _episodePattern = RegExp(r'ep\d+');

  static VaultAudioType fromFileName(String name) {
    final extension = _extensionOf(name);
    if (extension.isEmpty || !knownExtensions.contains(extension)) {
      return VaultAudioType.other;
    }
    final lower = name.toLowerCase();
    if (lower.contains('podcast') ||
        lower.contains('episode') ||
        _episodePattern.hasMatch(lower)) {
      return VaultAudioType.podcast;
    }
    if (lower.contains('rec') ||
        lower.contains('voice') ||
        lower.contains('memo') ||
        lower.contains('recording') ||
        lower.contains('call')) {
      return VaultAudioType.recording;
    }
    return VaultAudioType.music;
  }

  static VaultAudioType? fromStorageKey(String? key) {
    for (final type in VaultAudioType.values) {
      if (type.storageKey == key) return type;
    }
    return null;
  }

  /// `MP3`, `M4A`, or `FILE` when the name carries no extension.
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
enum VaultAudioSort {
  newestFirst,
  oldestFirst,
  nameAz,
  sizeLargest;

  String get storageKey => name;

  String get label => switch (this) {
    VaultAudioSort.newestFirst => 'Newest first',
    VaultAudioSort.oldestFirst => 'Oldest first',
    VaultAudioSort.nameAz => 'Name A–Z',
    VaultAudioSort.sizeLargest => 'Largest first',
  };

  static VaultAudioSort fromStorageKey(String? key) {
    for (final sort in VaultAudioSort.values) {
      if (sort.storageKey == key) return sort;
    }
    return VaultAudioSort.newestFirst;
  }
}

/// The filter row's chips: All, Music, Recordings, Podcasts.
enum VaultAudioFilter {
  all('All'),
  music('Music'),
  recording('Recordings'),
  podcast('Podcasts');

  const VaultAudioFilter(this.label);

  final String label;

  /// The type an audio must be to pass this filter, or `null` for All.
  VaultAudioType? get type => switch (this) {
    VaultAudioFilter.all => null,
    VaultAudioFilter.music => VaultAudioType.music,
    VaultAudioFilter.recording => VaultAudioType.recording,
    VaultAudioFilter.podcast => VaultAudioType.podcast,
  };

  bool matches(VaultAudio audio) => type == null || audio.effectiveType == type;
}
