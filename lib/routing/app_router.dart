import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/component_catalog.dart';
import '../features/about/presentation/about_screen.dart';
import '../features/calculator/presentation/calculator_screen.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/legal/presentation/legal_screens.dart';
import '../features/secret/presentation/change_pin_screen.dart';
import '../features/secret/presentation/secret_screens.dart';
import '../features/settings/presentation/settings_screen.dart';
import 'app_routes.dart';

/// App-wide router (D-01, struction.md §7), created per [ProviderScope].
///
/// The Calculator is the root route; History, Settings, About, Privacy, and
/// Terms are pushed onto the stack so the system back gesture pops them
/// (prd.md §7). About, Privacy, and Terms are reached from Settings, which is
/// the only route the hamburger opens (D-20).
///
/// The [ComponentCatalogScreen] is appended **only in debug builds**. It is a
/// design-system tool (phases.md §Phase 3), not part of the product, and no
/// link to it exists anywhere in the UI, so a release build contains neither
/// the route nor the screen.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.calculator,
    routes: [
      GoRoute(
        path: AppRoutes.calculator,
        builder: (context, state) => const CalculatorScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: AppRoutes.terms,
        builder: (context, state) => const TermsOfServiceScreen(),
      ),
      // Secret Mode (D-82, D-84). Four routes for what is deliberately an
      // almost-empty area; they are ordinary routes because the five-second hold
      // has to push one, and pushing needs a registered path. Nothing links here
      // but the gesture.
      GoRoute(
        path: AppRoutes.secretUnlock,
        builder: (context, state) => const SecretUnlockScreen(),
      ),
      GoRoute(
        path: AppRoutes.secret,
        builder: (context, state) => const SecretScreen(),
      ),
      GoRoute(
        path: AppRoutes.secretSettings,
        builder: (context, state) => const SecretSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.secretChangePin,
        builder: (context, state) => const ChangePinScreen(),
      ),
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.catalog,
          builder: (context, state) => const ComponentCatalogScreen(),
        ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});