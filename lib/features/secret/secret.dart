/// Public surface of the Secret Mode feature (struction.md §14, D-82…D-85).
///
/// Added in Phase 11. Exported as one surface for the same reason every other
/// feature is: the module is discoverable from a single file, and the four
/// screens, the repository pair, the code type, and the shared PIN field are
/// what a caller outside the feature could conceivably need.
library;

export 'data/secret_repository.dart';
export 'data/shared_preferences_secret_repository.dart';
export 'domain/secret_code.dart';
export 'presentation/change_pin_screen.dart';
export 'presentation/secret_controller.dart';
export 'presentation/secret_lockout_controller.dart';
export 'presentation/secret_pin_field.dart';
export 'presentation/secret_screens.dart';