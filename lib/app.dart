import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_theme_provider.dart';
import 'routing/app_router.dart';

/// Root widget: the MaterialApp wired to the Riverpod-provided router
/// (D-01, struction.md §7).
///
/// The theme is resolved through [appThemeProvider] / [appThemeModeProvider]
/// rather than constructed here. Dark is the only supported theme in v1.0
/// (D-09), so those providers do not consult the stored preference — see
/// **D-45** for why, and for where that seam lives when a light theme arrives.
class CalculatorApp extends ConsumerWidget {
  const CalculatorApp({super.key});

  /// Ceiling on the system font scale factor (**D-54**).
  ///
  /// `prd.md` NFR-004 asks for Dynamic Type support, and 1.3x is where the
  /// calculator's two fixed-height line boxes and the keypad's cell grid stop
  /// fitting the shortest supported phone (desing.md §9, ~442dp wide, at
  /// 568dp tall). Text still visibly grows for a user who has asked for larger
  /// type; past this the display and the rows would have to stop reserving
  /// their measured heights, which is Phase 9's layout question rather than
  /// this phase's.
  static const double maxTextScaleFactor = 1.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Calculator',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(appThemeProvider),
      darkTheme: ref.watch(appThemeProvider),
      themeMode: ref.watch(appThemeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
      // The clamp goes here rather than in a `MediaQuery` wrapped around the
      // `MaterialApp`: there is no `MediaQuery` above it to extend, and the
      // router builds every route below this point, so one insertion reaches
      // all six screens. A floor of 1.0 keeps the system from ever *shrinking*
      // the mockup-matched type scale (desing.md §3).
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: maxTextScaleFactor,
        child: child!,
      ),
    );
  }
}
