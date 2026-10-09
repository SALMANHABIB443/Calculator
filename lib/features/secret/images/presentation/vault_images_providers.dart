import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/storage/preferences_provider.dart';
import '../data/shared_preferences_vault_image_repository.dart';
import '../data/vault_image_repository.dart';
import '../data/vault_image_store.dart';
import '../data/vault_image_store_factory.dart';

/// Where vault metadata comes from: `shared_preferences`, in-memory fallback.
final vaultImageRepositoryProvider =
    FutureProvider<VaultImageRepository>((ref) async {
      try {
        final preferences = await ref.watch(preferencesProvider);
        return SharedPreferencesVaultImageRepository(preferences);
      } catch (_) {
        return InMemoryVaultImageRepository();
      }
    });

final vaultImageStoreProvider = Provider<VaultImageStore>(
  (ref) => createVaultImageStore(),
);

/// Opens the Android system image picker (no manifest permission needed).
final vaultImagePickerProvider = Provider<ImagePicker>(
  (ref) => ImagePicker(),
);
