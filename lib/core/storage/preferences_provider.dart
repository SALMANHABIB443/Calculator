/// The application's single `shared_preferences` acquisition point.
///
/// Both persisted features read and write through this provider, so the app
/// touches the plugin in exactly one place. It started life inside the history
/// feature, which meant the settings feature had to reach across into
/// `features/history/` to obtain its store — a dependency that inverts the
/// one-way rule D-39 established. `core` is the right owner: it imports a
/// plugin, not a feature, so this creates no `core → features` edge and
/// D-24's single such import stays single (D-44).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the storage instance comes from. A seam rather than a direct call so a
/// test can make acquisition fail, and so the app has exactly one place that
/// touches the plugin.
final preferencesProvider = Provider<Future<SharedPreferences>>(
  (ref) => SharedPreferences.getInstance(),
);