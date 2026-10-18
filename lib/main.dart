import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'features/secret/audio/player/vault_audio_handler.dart';

/// Entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // v1.0 targets portrait phones only; the orientation is locked in code
  // rather than merely declared in the manifest (D-09, prd.md AC-015).
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Dark-only UI: force the dark system appearance so the status-bar icons
  // and any system-drawn surfaces match the app background (desing.md §4).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // The container is built here rather than by `ProviderScope` so the audio
  // playback session (D-123) can be wired into Android's media session before
  // the first frame. `initVaultAudioService` is a no-op off Android.
  final container = ProviderContainer();
  await initVaultAudioService(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CalculatorApp(),
    ),
  );
}
