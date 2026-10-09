import 'vault_image_store.dart';
import 'vault_image_store_io.dart'
    if (dart.library.js_interop) 'vault_image_store_web.dart' as impl;

VaultImageStore createVaultImageStore() => impl.createVaultImageStore();