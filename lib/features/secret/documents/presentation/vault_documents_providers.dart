import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/preferences_provider.dart';
import '../data/shared_preferences_vault_document_repository.dart';
import '../data/vault_document_cipher.dart';
import '../data/vault_document_crypto_factory.dart';
import '../data/vault_document_picker.dart';
import '../data/vault_document_repository.dart';
import '../data/vault_document_store.dart';
import '../data/vault_document_store_factory.dart';
import 'vault_pdf_preview.dart';

/// The AES-256-GCM cipher, over the platform keystore key (FEAT-SEC-009).
///
/// A seam as much as a value: a widget test overrides this with a cipher over
/// a `FixedVaultKeySource`, so no test touches a real keystore.
final vaultDocumentCipherProvider = Provider<VaultDocumentCipher>(
  (ref) => createVaultDocumentCipher(),
);

/// Where encrypted document bytes live.
///
/// Depends on the cipher rather than building its own, so overriding the cipher
/// also changes what the store encrypts with.
final vaultDocumentStoreProvider = Provider<VaultDocumentStore>(
  (ref) => createVaultDocumentStore(ref.watch(vaultDocumentCipherProvider)),
);

/// Where document metadata comes from: `shared_preferences`, in-memory fallback.
final vaultDocumentRepositoryProvider =
    FutureProvider<VaultDocumentRepository>((ref) async {
      try {
        final preferences = await ref.watch(preferencesProvider);
        return SharedPreferencesVaultDocumentRepository(preferences);
      } catch (_) {
        return InMemoryVaultDocumentRepository();
      }
    });

/// Opens Android's Storage Access Framework picker (no manifest permission).
///
/// Overridden in tests with a fake that returns fixed bytes, so no native
/// dialog is ever raised.
final vaultDocumentPickerProvider = Provider<VaultDocumentPicker>(
  (ref) => const FilePickerDocumentPicker(),
);

/// The widget that renders a PDF's bytes.
///
/// A seam because `pdfx` opens a platform channel and throws on the test host
/// (and on Windows its pinch viewer throws outright), so a widget test must be
/// able to install a placeholder and still exercise the viewer's chrome and
/// back behaviour. [fileName] and [mimeType] are optional so an injected
/// builder can ignore them; the default one needs them for the Download the
/// fallback offers when there is no renderer.
typedef VaultPdfViewerBuilder =
    Widget Function(
      BuildContext context,
      Uint8List bytes, {
      String? fileName,
      String? mimeType,
    });

final vaultPdfViewerBuilderProvider = Provider<VaultPdfViewerBuilder>(
  (ref) => buildVaultPdfViewer,
);

/// The production PDF view, forwarded to the `pdfx`-backed widget.
///
/// Declared here as a plain function so the provider above can hold a
/// tear-off rather than a lambda, and so the `pdfx` import stays in one file.
Widget buildVaultPdfViewer(
  BuildContext context,
  Uint8List bytes, {
  String? fileName,
  String? mimeType,
}) => VaultPdfPreview(bytes: bytes, fileName: fileName, mimeType: mimeType);
