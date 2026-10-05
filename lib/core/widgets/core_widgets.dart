/// Public surface of the shared component library (desing.md §7,
/// struction.md §11).
///
/// Screens import this one file rather than each widget directly, so the
/// component set is discoverable from a single place and a rename moves one
/// import instead of six.
library;

export 'app_brand_icon.dart';
export 'app_dialog.dart';
export 'app_icon.dart';
export 'app_icon_button.dart';
export 'app_icon_tile.dart';
export 'app_page_header.dart';
export 'app_toggle.dart';
export 'app_trash_icon.dart';
export 'calculator_button.dart';
export 'empty_state.dart';
export 'history_card.dart';
export 'history_day_label.dart';
export 'secondary_page_header.dart';
export 'secondary_page_scaffold.dart';
export 'section_header.dart';
export 'selection_header.dart';
export 'settings_row.dart';
export 'toggle_row.dart';