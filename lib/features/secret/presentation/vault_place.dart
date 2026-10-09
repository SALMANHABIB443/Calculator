import '../../../core/design/app_palette.dart';
import '../../../core/widgets/core_widgets.dart';
import 'package:flutter/material.dart';

import '../images/presentation/vault_images_screen.dart';

/// One place inside the hidden area, and the wording its page is built from
/// (FEAT-SEC-007, D-114).
///
/// **A record rather than a class**, like `_SecretCategory` in
/// `secret_screens.dart`: a place is four values that are only ever read
/// together, and there is nowhere for a method to live that a class would be
/// worth the constructor for.
///
/// [id] is what the route carries — the segment of `/secret/browse/:place` — and
/// is spelled out in [vaultPlaces] rather than derived from [title], for the
/// reason the app argues everywhere else a key is hand-written (D-82's hold
/// duration, the settings repository's keys, the category tiles' `Key`s): *the
/// value a test asserts against must be the one that ships*. A slug derived from
/// "Internal storage" could silently become `internal-storage` in one place and
/// `internal_storage` in another, and the failure would be a page that pushes
/// and lands on the fallback.
///
/// **[icon] is nullable for the one place whose glyph is not a Material icon.**
/// The Recycle bin wears the design's own painted trash ([AppTrashIcon], D-73),
/// so it carries `null` here and lets [vaultPlaceGlyph] resolve the glyph. That
/// keeps [vaultPlaces] the *single* description of every place — the row and the
/// page it opens cannot disagree about the glyph any more than about the title.
typedef VaultPlace = ({
  String id,
  String title,
  IconData? icon,
  String emptyTitle,
});

/// The eleven places the Vault screen leads to, in the order it stacks them.
///
/// **One list rather than eleven screens.** Every one of these pages is the same
/// three parts — the shared header carrying the place's [VaultPlace.title], the
/// shared back button that header already owns, and an [EmptyState] — so the
/// only thing that differs between eleven screen classes would be the data
/// below. Stating the data once and building the page from it means a page
/// cannot disagree with the row that leads to it about what it is called.
///
/// **The icons are the ones the rows already use.** Reusing them is what makes
/// the grid on the Vault screen *derivable* from this list rather than a second
/// hand-written copy that drifts (see `_secretCategories` in `secret_screens.dart`
/// — it reads its tiles from here for that reason). A file manager whose tile
/// says "Videos" under a film icon and whose page says it under a different one
/// looks like two apps.
///
/// **Nothing here names the feature, the area, or the code** (§6.8). Every
/// [title] is phone vocabulary a user already has on their own device, and no
/// [emptyTitle] does either — the same rule the Vault screen's own rows follow,
/// and the reason `navigation_test`'s `§6.8` assertions keep holding on a screen
/// that now has eleven pages behind it.
const List<VaultPlace> vaultPlaces = <VaultPlace>[
  // **Recent files first**, because the row that leads here is the first thing
  // on the Vault screen and the page that mirrors that ordering is the one whose
  // heading a user is most likely to check against what they just tapped.
  (
    id: 'recent',
    title: 'Recent files',
    icon: Icons.history,
    emptyTitle: 'No recent files',
  ),
  // The six Categories grid, in reading order — three across, then three more.
  (
    id: 'images',
    title: 'Images',
    icon: Icons.image_outlined,
    emptyTitle: 'No images yet',
  ),
  (
    id: 'videos',
    title: 'Videos',
    icon: Icons.play_circle_outlined,
    emptyTitle: 'No videos yet',
  ),
  (
    id: 'audio',
    title: 'Audio files',
    icon: Icons.music_note_outlined,
    emptyTitle: 'No audio files yet',
  ),
  (
    id: 'documents',
    title: 'Documents',
    icon: Icons.description_outlined,
    emptyTitle: 'No documents yet',
  ),
  (
    id: 'downloads',
    title: 'Downloads',
    icon: Icons.download_outlined,
    emptyTitle: 'No downloads yet',
  ),
  (
    id: 'installation',
    title: 'Installation files',
    icon: Icons.android,
    emptyTitle: 'No installation files yet',
  ),
  // Storage. The two pages carry no figures, which is deliberate and is
  // recorded below. The *rows* that open them now do — real ones, from
  // `vaultStorageProvider` — so a figure on the Vault is a fact about the
  // phone, while its page stays a list waiting for files to be in it.
  (
    id: 'internal-storage',
    title: 'Internal storage',
    icon: Icons.smartphone,
    emptyTitle: 'Nothing stored yet',
  ),
  (
    id: 'sd-card',
    title: 'SD card',
    icon: Icons.sd_card_outlined,
    // Carries the same fact the Vault row's "Not inserted" subtitle does, in the
    // one place a user who has navigated here will look for it. A row that says
    // "Not inserted" beside a page that says nothing would look like the page
    // lost the information on the way in.
    emptyTitle: 'SD card not inserted',
  ),
  // The two bottom actions, which are not a group and so have no row icon to
  // borrow — `manage_search` is what the Analyse row wears. The Recycle bin has
  // **no Material glyph on purpose**: it paints the design's own trash
  // ([AppTrashIcon], D-73) so the whole app deletes with one glyph (D-119), and
  // [vaultPlaceGlyph] is what turns the `null` below into that widget.
  (
    id: 'recycle-bin',
    title: 'Recycle bin',
    icon: null,
    emptyTitle: 'Recycle bin is empty',
  ),
  (
    id: 'analyse-storage',
    title: 'Analyse storage',
    icon: Icons.manage_search,
    emptyTitle: 'Nothing to analyse',
  ),
];

/// The glyph a place's leading tile or empty state paints (D-119).
///
/// **One function rather than a `null`-check at each call site.** Material
/// places resolve straight from [VaultPlace.icon]; the Recycle bin—whose icon is
/// `null`—wears the design's painted trash ([AppTrashIcon], D-73). Both the row
/// and the page it opens go through here, so they cannot drift into showing two
/// different delete glyphs, and the size and colour stay each call site's to
/// decide the way an [AppIcon] / [AppTrashIcon] call always is.
Widget vaultPlaceGlyph(
  VaultPlace place, {
  AppIconSize size = AppIconSize.row,
  Color? color,
}) {
  final icon = place.icon;
  return icon == null
      ? AppTrashIcon(size: size, color: color)
      : AppIcon(icon, size: size, color: color);
}

/// The six [vaultPlaces] ids the Categories grid shows, in reading order.
///
/// **A list of ids rather than [VaultPlace]s**, so the grid cannot reorder
/// itself by editing the registry above and cannot show a category the
/// `/secret/browse/:place` route has no entry for: the tiles below resolve each
/// of these through [vaultPlaceById], so a typo here is a loud failure rather
/// than a tile that pushes to the fallback page.
///
/// Published as a `const` list for the same reason [vaultPlaces] is one — a test
/// asserts the grid against this exact ordering, so the order that ships has to
/// be the order it reads.
const List<String> vaultCategoryIds = <String>[
  'images',
  'videos',
  'audio',
  'documents',
  'downloads',
  'installation',
];

/// The place [id] names, or `null` when no entry does.
///
/// **Nullable on purpose, and the screen is the reason.** `/secret/browse/:place`
/// is a path, so anything that can build one can build a wrong one — a stale
/// bookmark, a hand-typed URL, a deep link from outside the app. Returning
/// `null` and letting [VaultPlaceScreen] fall back is what stops a bad segment
/// from throwing on a page the user can see, which on Android is a crash rather
/// than an error state.
///
/// It is also what keeps `navigation_graph_test`'s "every registered path
/// resolves to a screen" honest: that test pushes the *pattern*
/// `/secret/browse/:place` verbatim, because a path parameter has no concrete
/// value to substitute, so the literal segment `:place` arrives here and has to
/// render something rather than throw.
///
/// Linear rather than a map: eleven entries, looked up once per page build, and
/// a static `Map` of `const` records would need a lazy wrapper to stay const.
VaultPlace? vaultPlaceById(String id) {
  for (final place in vaultPlaces) {
    if (place.id == id) return place;
  }
  return null;
}

/// The page shown when no entry matches the route's `:place` segment (D-114).
///
/// **Generic on purpose.** "Files" names no category, so a wrong segment lands
/// on a page that claims nothing rather than on a page that confidently calls
/// itself one of the eleven. The alternative — reusing the first entry, or
/// throwing — was rejected for the same reason [vaultPlaceById] is nullable.
///
/// Private and never exported: no caller should navigate here deliberately.
const VaultPlace _unknownPlace = (
  id: '',
  title: 'Files',
  icon: Icons.folder_outlined,
  emptyTitle: 'Nothing here yet',
);

/// The hidden area's browsing page: one place's name above an empty list
/// (FEAT-SEC-007, D-114).
///
/// **The shared [SecondaryPageScaffold] rather than the hand-rolled frame the
/// other Secret Mode screens use.** This page has no argument with the app's
/// chrome — it is pushed on top of another screen, it wants a title and a way
/// back, and every other screen in the app that wanted exactly that reached for
/// these two components. [SecondaryPageHeader] already draws the back button,
/// already centres the title by geometry, and already pads its own boxes onto the
/// 24 px margin (D-74), so a bespoke header here would be a fourth implementation
/// of D-74's answer rather than a better one.
///
/// **Which is why there is no special-cased back arrow**, unlike
/// `_SecretBackButton` on the PIN screen. That one exists because the PIN screen
/// has *no* header to carry one and had to invent a place to put it. Here the
/// header is the app's, so its back button is the app's, and it pops — which is
/// what makes "one back button" true in the ordinary sense: it returns to
/// whichever screen was tapped to get here, rather than hard-coding a `go` to
/// `/secret` that would be wrong for a page reached from anywhere else.
///
/// **One screen for eleven places, and no state.** Nothing here changes between
/// places except the three strings and the glyph, all of which come from
/// [vaultPlaceById]; there is no data source yet, so there is no controller, no
/// provider, and nothing to invalidate. When storage arrives it arrives here,
/// behind this same constructor — the route and the page contract do not have to
/// change to gain a list.
class VaultPlaceScreen extends StatelessWidget {
  const VaultPlaceScreen({required this.placeId, super.key});

  /// The `:place` segment of the route, or `''` when the router supplied none.
  ///
  /// **A plain `String` rather than a `VaultPlace`.** The screen is constructed
  /// by `app_router.dart` from a path parameter, so taking the id keeps the
  /// router free of a lookup that could fail, and it means this widget is
  /// testable with a one-word constructor call.
  final String placeId;

  /// The handle a test reaches the page's body by, rather than by the type of
  /// whatever is inside it.
  ///
  /// Published as a constant for the reason the app does this elsewhere (D-82's
  /// hold duration, [vaultPlaces]): a finder should not have to spell out the
  /// empty state's own key to assert that a page rendered.
  static const Key bodyKey = Key('vault-place-body');

  @override
  Widget build(BuildContext context) {
    final place = vaultPlaceById(placeId) ?? _unknownPlace;

    // The Images place owns a full gallery; every other place keeps the
    // honest empty state until its own storage lands.
    if (placeId == 'images') return const VaultImagesScreen();

    return SecondaryPageScaffold(
      header: SecondaryPageHeader(title: place.title),
      body: EmptyState(
        key: bodyKey,
        iconWidget: vaultPlaceGlyph(
          place,
          // The illustration size, as History's empty list uses: this page is
          // nothing but its empty state, so the glyph is the content rather than
          // a decoration beside some.
          size: AppIconSize.illustration,
          color: context.appColors.textSecondary,
        ),
        title: place.emptyTitle,
        iconSize: AppIconSize.illustration,
      ),
    );
  }
}
