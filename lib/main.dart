import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF000000),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: CalculatorApp()));
}
