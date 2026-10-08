import '../domain/vault_image.dart';

/// One gallery snapshot: images, albums, and the persisted sort.
class VaultImagesState {
  const VaultImagesState({
    required this.images,
    required this.albums,
    required this.sort,
  });

  final List<VaultImage> images;
  final List<VaultAlbum> albums;
  final VaultImageSort sort;

  List<VaultImage> get visible =>
      <VaultImage>[for (final image in images) if (!image.isTrashed) image];

  List<VaultImage> get trash =>
      <VaultImage>[for (final image in images) if (image.isTrashed) image];

  List<VaultImage> get favorites => <VaultImage>[
    for (final image in visible)
      if (image.isFavorite) image,
  ];

  List<VaultImage> sorted(List<VaultImage> input) {
    final list = List<VaultImage>.from(input);
    switch (sort) {
      case VaultImageSort.newestFirst:
        list.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
      case VaultImageSort.oldestFirst:
        list.sort((a, b) => a.dateAdded.compareTo(b.dateAdded));
      case VaultImageSort.nameAz:
        list.sort(
          (a, b) =>
              a.fileName.toLowerCase().compareTo(b.fileName.toLowerCase()),
        );
      case VaultImageSort.nameZa:
        list.sort(
          (a, b) =>
              b.fileName.toLowerCase().compareTo(a.fileName.toLowerCase()),
        );
      case VaultImageSort.sizeLargest:
        list.sort((a, b) => b.fileSize.compareTo(a.fileSize));
      case VaultImageSort.sizeSmallest:
        list.sort((a, b) => a.fileSize.compareTo(b.fileSize));
    }
    return list;
  }

  List<VaultImage> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return sorted(visible);
    final albumNames = <String, String>{
      for (final album in albums) album.id: album.name.toLowerCase(),
    };
    return sorted(<VaultImage>[
      for (final image in visible)
        if (image.fileName.toLowerCase().contains(q) ||
            image.dateAdded.toIso8601String().toLowerCase().contains(q) ||
            image.albumIds.any((id) => (albumNames[id] ?? '').contains(q)))
          image,
    ]);
  }

  List<VaultImage> inAlbum(String albumId) {
    if (albumId == 'all') return sorted(visible);
    if (albumId == 'favorites') return sorted(favorites);
    if (albumId == 'recent') {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      return sorted(<VaultImage>[
        for (final image in visible)
          if (image.dateAdded.isAfter(cutoff)) image,
      ]);
    }
    return sorted(<VaultImage>[
      for (final image in visible)
        if (image.albumIds.contains(albumId)) image,
    ]);
  }
}

/// Outcome of an import run, for progress + result messaging.
class VaultImportResult {
  const VaultImportResult({
    required this.imported,
    required this.failed,
  });

  final int imported;
  final int failed;
}
