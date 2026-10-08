/// Public surface of the Secret Mode feature (struction.md §14, D-82…D-85).
///
/// Added in Phase 11. Exported as one surface for the same reason every other
/// feature is: the module is discoverable from a single file, and the four
/// screens, the repository pair, the code type, and the shared PIN field are
/// what a caller outside the feature could conceivably need.
///
/// **D-114 added the eleventh screen** — [VaultPlaceScreen], the browsing page the
/// eleven Vault rows open — and its [vaultPlaces] registry with it. The registry
/// is exported rather than kept private because `app_router.dart` hands the screen
/// the `:place` segment as a plain string, and a caller that wants to build a link
/// needs to know which ids exist without reaching into a private list.
///
/// **D-115 added [SecretMenu]**, the panel behind the Vault's overflow button, and
/// moved [SecretSettingsScreen] into a file of its own now that the panel is what
/// leads to it. The two are exported for the same reason the rest is: a caller
/// outside the feature can name them without knowing where they live.
library;

export 'data/secret_repository.dart';
export 'data/shared_preferences_secret_repository.dart';
export 'domain/secret_code.dart';
export 'presentation/change_pin_screen.dart';
export 'presentation/secret_controller.dart';
export 'presentation/secret_lockout_controller.dart';
export 'presentation/secret_menu.dart';
export 'presentation/secret_pin_field.dart';
export 'presentation/secret_screens.dart';
export 'presentation/secret_settings_screen.dart';
export 'presentation/vault_place.dart';