/// One private image inside the hidden area's vault (FEAT-SEC-008, D-116).
///
/// A value type with no behaviour beyond serialisation: the gallery reads it,
/// the viewer opens it, and the repository persists it. [vaultFileName] is the
/// file's name inside the app-private vault directory — never an absolute
/// path, so a stored record cannot leak the device layout through a log line
/// or a share sheet.
class VaultImage {
  const VaultImage({
    required this.id,
    required this.fileName,
    required this.vaultFileName,
    required this.mimeType,
    required this.fileSize,
    required this.dateAdded,
    required this.dateModified,
    this.width,
    this.height,
    this.isFavorite = false,
    this.albumIds = const <String>[],
    this.trashedAt,
  });

  final String id;
  final String fileName;
  final String vaultFileName;
  final String mimeType;
  final int fileSize;
  final DateTime dateAdded;
  final DateTime dateModified;
  final int? width;
  final int? height;
  final bool isFavorite;
  final List<String> albumIds;
  final DateTime? trashedAt;

  bool get isTrashed => trashedAt != null;

  VaultImage copyWith({
    bool? isFavorite,
    List<String>? albumIds,
    DateTime? trashedAt,
    bool clearTrash = false,
  }) {
    return VaultImage(
      id: id,
      fileName: fileName,
      vaultFileName: vaultFileName,
      mimeType: mimeType,
      fileSize: fileSize,
      dateAdded: dateAdded,
      dateModified: dateModified,
      width: width,
      height: height,
      isFavorite: isFavorite ?? this.isFavorite,
      albumIds: albumIds ?? this.albumIds,
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
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    'isFavorite': isFavorite,
    'albumIds': albumIds,
    if (trashedAt != null) 'trashedAt': trashedAt!.toIso8601String(),
  };

  static VaultImage? fromJson(Map<String, dynamic> json) {
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
      int? width;
      int? height;
      final rawWidth = json['width'];
      final rawHeight = json['height'];
      if (rawWidth is int) width = rawWidth;
      if (rawHeight is int) height = rawHeight;
      final rawAlbums = json['albumIds'];
      final albumIds = rawAlbums is List
          ? <String>[for (final e in rawAlbums) if (e is String) e]
          : <String>[];
      DateTime? trashedAt;
      final rawTrash = json['trashedAt'];
      if (rawTrash is String) trashedAt = DateTime.tryParse(rawTrash);
      return VaultImage(
        id: id,
        fileName: fileName,
        vaultFileName: vaultFileName,
        mimeType: mimeType,
        fileSize: fileSize,
        dateAdded: DateTime.tryParse(dateAdded) ?? DateTime.now(),
        dateModified: DateTime.tryParse(dateModified) ?? DateTime.now(),
        width: width,
        height: height,
        isFavorite: json['isFavorite'] == true,
        albumIds: albumIds,
        trashedAt: trashedAt,
      );
    } catch (_) {
      return null;
    }
  }
}

/// One user-created album: a named set of image ids (FEAT-SEC-008, D-116).
///
/// Deleting an album never deletes images — it only drops the grouping.
class VaultAlbum {
  const VaultAlbum({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  static VaultAlbum? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final createdAt = json['createdAt'];
    if (id is! String || name is! String || createdAt is! String) return null;
    final parsed = DateTime.tryParse(createdAt);
    if (parsed == null) return null;
    return VaultAlbum(id: id, name: name, createdAt: parsed);
  }
}

/// Gallery ordering the user picked; persisted in `shared_preferences`.
enum VaultImageSort {
  newestFirst,
  oldestFirst,
  nameAz,
  nameZa,
  sizeLargest,
  sizeSmallest;

  String get storageKey => name;

  String get label => switch (this) {
    VaultImageSort.newestFirst => 'Newest first',
    VaultImageSort.oldestFirst => 'Oldest first',
    VaultImageSort.nameAz => 'Name A–Z',
    VaultImageSort.nameZa => 'Name Z–A',
    VaultImageSort.sizeLargest => 'Largest first',
    VaultImageSort.sizeSmallest => 'Smallest first',
  };

  static VaultImageSort fromStorageKey(String? key) {
    for (final sort in VaultImageSort.values) {
      if (sort.storageKey == key) return sort;
    }
    return VaultImageSort.newestFirst;
  }
}
