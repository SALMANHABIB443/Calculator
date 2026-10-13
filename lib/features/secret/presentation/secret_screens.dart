import '../../../../core/design/app_palette.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/core_widgets.dart';
import '../../../routing/app_routes.dart';
import '../data/device_storage_repository.dart';
import '../documents/domain/vault_document.dart';
import '../documents/presentation/vault_document_viewer.dart';
import '../documents/presentation/vault_documents_controller.dart';
import '../images/domain/vault_image.dart';
import '../images/presentation/vault_image_viewer.dart';
import '../images/presentation/vault_images_controller.dart';
import 'secret_controller.dart';
import 'secret_home_button.dart';
import 'secret_lockout_controller.dart';
import 'secret_menu.dart';
import 'secret_pin_field.dart';
import 'vault_place.dart';

/// The way out of the PIN screen: one back arrow in the **top-left** corner,
/// going home (D-87).
///
/// **Reverses where D-86 put it on this screen**, not whether it exists. D-86
/// argued — correctly — that a user who held the button by accident and cannot
/// guess the code had no way out, and that argument still holds. What it got
/// wrong for *this* screen is the shape of the answer: a 56 px white circle in
/// the bottom-right corner is a Material FAB, and a FAB reads as "the primary
/// action of this screen". On the PIN screen it was not primary and never could
/// be — the only actions there are four dots and a keypad, and the way out is
/// neither. So the same affordance that looked like an exit on the blank secret
/// screen (which has no primary action at all) looked like a competing
/// destination on a screen whose one real task is typing four digits.
///
/// **Top-left and a back arrow** because that is where every other screen in
/// this app puts "leave", and where a user's thumb already goes to leave. It is
/// the shared [AppIconButton] on the app's own 24 px margin — the same component
/// and the same inset as the overflow button on the unlocked secret screen and
/// the trash on History — so it looks like an ordinary control rather than
/// something the Secret Mode screens invented.
///
/// **D-84's "no back arrow" clause is now amended for this screen only.** It
/// still holds on `SecretScreen`, which is not this screen; and it still holds
/// for *content* everywhere here — no title, no logo, no copy, no illustration.
/// What is withdrawn is the argument that a second exit "tells the user this
/// page is somewhere they arrived at". A corner arrow is the cheapest exit in
/// the app and the most forgettable, and reachability for a trapped user is
/// worth more than deniability about a page that shows nothing.
class _SecretBackButton extends StatelessWidget {
  const _SecretBackButton();

  /// The handle tests reach this button by, and the name every finder's key
  /// matches.
  ///
  /// Distinct from [SecretHomeButton.buttonKey] on purpose: the two buttons now
  /// live on different screens, and a shared key would let a test asserting
  /// "the PIN screen has no home button" pass for the wrong reason.
  static const Key buttonKey = Key('secret-back');

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: AppIconButton(
        key: buttonKey,
        icon: Icons.arrow_back,
        tooltip: 'Back to calculator',
        // `go`, not `pop`: the system gesture on this screen pops to History,
        // which is the trap D-86 was written about — a user holding down on the
        // 0 result would slide back onto the calculator but a user mid-secret
        // would slide back into the app with the hidden area still under them.
        // `go` leaves nothing of Secret Mode on the stack either way.
        onPressed: () => context.go(AppRoutes.calculator),
      ),
    );
  }
}

/// The black PIN prompt (FEAT-SEC-002, AC-018/AC-019).
///
/// **No header, no title, and no hint** — all three are deliberate. A screen that
/// names itself confirms it is real, and this is a hidden feature; the dots and
/// the keypad are the entire interface. The one exit is in the **top-left**: a
/// back arrow, sharing the app's margin and its back-button component, and
/// nothing more (D-87).
///
/// **D-88 adds the one piece of feedback this screen had none of.** Under D-85 a
/// wrong code cleared the dots and shook them and said nothing, because naming
/// the failure on a screen that is itself a secret was judged worse than silence.
/// That judgement still holds for *naming the feature*, and it still holds here —
/// nothing on this screen says what it is. But silence cannot support a lockout,
/// and a lockout cannot support itself: a screen that stops accepting input
/// without saying why is indistinguishable from a broken one. So the feedback
/// added is strictly about **the user's own last entry** — "Wrong PIN", and the
/// countdown — and says nothing about the feature, the area, or the code (D-86,
/// D-88).
///
/// **A `ConsumerStatefulWidget` where it used to be a `ConsumerWidget`**, for one
/// reason: [SecretLockoutNotifier.restore] has to run when the screen mounts, so
/// a lock left over from a previous run of the app is picked up rather than being
/// silently dropped. The build itself watches the lockout, so the countdown and
/// the enabled state follow the controller rather than being copied into local
/// state that could fall out of step with it.
class SecretUnlockScreen extends ConsumerStatefulWidget {
  const SecretUnlockScreen({super.key});

  @override
  ConsumerState<SecretUnlockScreen> createState() => _SecretUnlockScreenState();
}

class _SecretUnlockScreenState extends ConsumerState<SecretUnlockScreen> {
  @override
  void initState() {
    super.initState();
    // Fire and forget: [restore] catches its own failures and the screen is
    // usable before it resolves, so there is nothing here to await and no
    // loading state to put in front of the keypad.
    //
    // Safe without `await` in `initState` — it reads `ref` only after its first
    // `await`, and Riverpod permits that, so the context is not used across the
    // frame this call returns from.
    Future<void>.microtask(
      () => ref.read(secretLockoutProvider.notifier).restore(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watched, so the keypad enables and disables and the countdown repaints as
    // the lock runs. The *state* is watched rather than the notifier's `isLocked`
    // because that state changes on every tick, and the tick is what schedules
    // the repaint — reading a plain bool would rebuild once and then sit still.
    ref.watch(secretLockoutProvider);
    final lockoutNotifier = ref.read(secretLockoutProvider.notifier);

    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.headerTopGap,
            AppSpacing.screenHorizontal,
            // No `bottomSafe` here: [SecretPinField] owns the gap under the pad
            // itself, measured from the physical bottom edge (D-89). Adding the
            // screen's own 24 px on top would push the keypad back up off the
            // floor it was just brought down to.
            0,
          ),
          child: Stack(
            children: <Widget>[
              SecretPinField(
                // **Neither string names the code** (§6.8).
                prompt: 'Enter your PIN',
                // The unlock screen is the one place a wrong code is genuinely
                // wrong, so it is the one place the error state was first
                // turned on. **Change PIN turned its own on later (D-113)**,
                // which had been left off here on the reasoning that a user
                // mistyping a code they just chose should not be shown red.
                showErrors: true,
                // The controller owns the wording because it owns the countdown:
                // the seconds in the message and the seconds in the lock are the
                // same fact, and deriving one of them here would let the two
                // disagree.
                lockoutMessage: lockoutNotifier.isLocked
                    ? lockoutNotifier.lockoutMessage
                    : null,
                inputEnabled: !lockoutNotifier.isLocked,
                // The one place a correct code acts: replace this screen with
                // the secret screen rather than pushing on top of it. Leaving a
                // PIN prompt beneath the secret screen would put a back gesture
                // that returns here in front of the user (struction.md §7,
                // D-84).
                onSubmit: (entered) async {
                  final accepted = await ref
                      .read(secretControllerProvider.notifier)
                      .verify(entered);

                  if (accepted) {
                    // Cleared *before* navigating, not after: the destination is
                    // a different screen and a rebuild between the two would
                    // show the user a keypad with three attempts left that they
                    // have already spent.
                    lockoutNotifier.registerSuccess();
                    if (!context.mounted) return false;
                    context.go(AppRoutes.secret);
                    return true;
                  }

                  // Only a code that was actually judged wrong reaches here —
                  // [SecretPinField] submits exactly once, on the fourth digit,
                  // and only ever passes a well-formed code. An incomplete entry
                  // cannot be counted, which is what "three wrong PINs" means.
                  lockoutNotifier.registerFailure();
                  return false;
                },
              ),
              // The one exit on this screen, and the reason it is a top-left back
              // arrow rather than the bottom-right FAB D-86 chose: a user who
              // held the button by accident and cannot guess the code has to be
              // able to leave, and an arrow is the app's ordinary way out — so it
              // reads as furniture and never competes with the keypad, which is
              // the one thing this screen exists for (D-87).
              //
              // No padding of its own: the [Padding] around this [Stack] already
              // puts the button on the app's 24 px header margin, the same inset
              // every other screen's back button rides (D-74).
              const _SecretBackButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// One cell of the Categories grid, resolved from its [VaultPlace].
///
/// **The record holds a place rather than a label and a glyph** because both of
/// those now live in [vaultPlaces] (`vault_place.dart`), and the reason that
/// list is the single source is the reason this cell cannot drift from the page
/// it leads to: a grid cell labelled "Videos" over a film icon must push a page
/// that says "Videos" under the same icon, and holding the place — rather than a
/// copy of two of its fields plus a slug — makes that structural instead of a
/// convention somebody has to remember.
typedef _SecretCategory = ({Key key, VaultPlace place});

/// The six cells of the Categories grid, in reading order.
///
/// **Built from [vaultCategoryIds] rather than written out**, which reverses the
/// decision the previous version of this file recorded. It spelled all six
/// `{key, label, icon}` records by hand on the grounds that a hand-written key
/// cannot drift from the test that matches it — and that argument is still true
/// of the `Key`s, so they are still spelled out, one per id, below. What it did
/// not account for is what the FEAT-SEC-007 pass added: every cell now carries a
/// slug that has to match an entry in [vaultPlaces] *and* an icon that has to
/// match that entry's. Three hand-written fields that must agree with a fourth
/// place is worse than one hand-written field that resolves the other three.
///
/// So the id is the single literal per cell, and the key is still derived from
/// it rather than invented — a test matching `Key('secret-category-videos')` and
/// a cell written `'videos'` still cannot disagree, because both come from the
/// same word, and both are asserted against [vaultCategoryIds] in
/// `vault_place_pages_test.dart`.
///
/// A `List` getter rather than a `const` list because resolving an id is a
/// function call. The grid is six entries and is rebuilt on layout, not on every
/// frame, so the lookup is not on a path that shows up in a profile.
List<_SecretCategory> get _secretCategories => <_SecretCategory>[
  for (final id in vaultCategoryIds)
    (
      key: Key('secret-category-$id'),
      place: vaultPlaceById(id)!,
    ),
];

/// One cell of the Categories grid: the shared [AppIconTile] above its label.
///
/// **Icon over label, not beside it.** Three columns across a 442 px canvas leave
/// roughly 112 px a cell, and "Installation files" sitting beside a 44 px tile
/// would be ellipsised down to "Installa…" — and that label is the one a user
/// cannot guess the meaning of from its first four letters. Stacking hands the
/// label the full cell width and lets it take two lines instead.
///
/// [AppIconTile] rather than a bare glyph for the reason D-91 gives: it is the
/// app's own icon container, so these six cells match the leading tiles on every
/// settings row instead of looking like a second, smaller style invented here.
class _SecretCategoryTile extends StatelessWidget {
  const _SecretCategoryTile({required this.category, super.key});

  /// Which place of [_secretCategories] this cell is.
  final _SecretCategory category;

  @override
  Widget build(BuildContext context) {
    final place = category.place;

    // D-59 applied to a grid: one stop per category, not two. The tile and the
    // label are both dropped from the semantics tree, exactly as [SettingsRow]
    // drops its own. The one node that survives is labelled with the place's own
    // title, which is also what the page it pushes will call itself.
    return Semantics(
      container: true,
      button: true,
      label: place.title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(AppRoutes.secretBrowseTo(place.id)),
          borderRadius: BorderRadius.circular(AppIconTile.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ExcludeSemantics(child: AppIconTile(icon: place.icon)),
                const SizedBox(height: AppSpacing.sm),
                ExcludeSemantics(
                  child: Text(
                    place.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.type.rowSubtitle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The rounded card holding the 3 × 2 Categories grid.
///
/// **Private here rather than a new core card widget.** [SettingsGroup] stacks
/// rows vertically and cannot hold a grid — but the card the grid sits in must not
/// be a *lookalike*, and re-deriving the fill, border, radius, and shadow in a
/// second place is how those four values start to disagree. Reusing
/// [SettingsGroup.decoration] keeps every card on this screen the same recipe.
class _SecretCategoryCard extends StatelessWidget {
  const _SecretCategoryCard();

  /// Columns, and therefore the `_secretCategories` index of each cell.
  static const int columns = 3;

  @override
  Widget build(BuildContext context) {
    // Read once into a local: [vaultCategoryIds] resolves six ids through
    // [vaultPlaceById] every time it is called, and this build reads the list
    // once per row in the loop condition plus twice per cell in the cell itself.
    // The list is six entries, so this is a nanosecond either way — it is stated
    // because a getter called inside a loop bound is the shape that later grows
    // into a lookup that runs per frame.
    final categories = _secretCategories;

    return Padding(
      // The 24 px [SettingsGroup] puts on its own rows, restated so this card's
      // edges line up with the cards above and below it by construction rather
      // than by arithmetic.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: DecoratedBox(
        decoration: SettingsGroup.decoration(context),
        // The card's radius, not the tile's — [SettingsGroup] clips its own rows
        // exactly this way, and a ripple escaping past the corner is how a card
        // starts to look like a rounded rectangle with a notch in it.
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              children: <Widget>[
                for (
                  var row = 0;
                  row * columns < categories.length;
                  row++
                ) ...[
                  if (row > 0) const SizedBox(height: AppSpacing.md),
                  Row(
                    // Start, not centre: the cells are of unequal height once a
                    // label wraps to two lines, and a centre alignment would
                    // leave the row's icons at different heights.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: _SecretCategoryTile(
                            key: categories[row * columns + column].key,
                            category: categories[row * columns + column],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The unlocked secret screen: the hidden area's file manager (FEAT-SEC-003).
///
/// **Reverses D-84's "blank"**, which held that this page showed one button and
/// nothing else so a screenshot of it would give nothing away. The reason it is
/// reversed is that the page could not be *used* as anything: a file manager that
/// lists nothing, opens nothing, and stores nothing is not a private area, it is a
/// wall — and a user who has already proved they know the PIN is exactly the user
/// least served by one.
///
/// **What this costs, on the record.** D-84's argument was not wrong about the
/// copy: every string below names a category a phone already knows (Images,
/// Downloads) and none of them names the feature, the area, or the code, so §6.8
/// still holds and a screenshot still does not hand over the PIN. What a
/// screenshot now shows is that a file manager exists — which was already true the
/// moment [SecretHomeButton] shipped, and was accepted for the same reason.
///
/// **Titled "Vault", in the top-left.** The bar was titleless because it carried
/// nothing but two actions, and a [Spacer] put both boxes on the right margin
/// with nothing invented in the gap — which is still what happens to the right
/// side now that the left has a word in it.
///
/// **This title withdraws §6.8's naming rule for this screen, on purpose.** The
/// rule (desing.md §6.8, D-84) was that nothing here names the feature, the
/// area, or the code, on the grounds that a screen which names itself is a screen
/// a screenshot spoils. "Vault" is exactly such a name, so the honest reading is
/// that the screen now tells a screenshot reader what it is.
///
/// What is *not* withdrawn: the rule was never about the code. `0000`, "PIN",
/// "default", and "Secret" are still forbidden, and the §6.8 test still enforces
/// those four — a screenshot of this page hands over the *name* of a private
/// storage area and never the four digits that open it. The cost is recorded
/// rather than argued away: someone who wanted the area to be deniable now has a
/// title on it, and that is a weaker guarantee than the one D-84 described.
///
/// [AppPageHeader.title] takes the slack, so the actions still land on the right
/// margin by construction rather than by a `Spacer` that a title would have
/// replaced.
///
/// **Every row on this screen now leads somewhere** (FEAT-SEC-007, D-114). This
/// used to read "nothing on this screen does anything", which was true when all
/// eleven were wired to [_noop]; it was never a general licence to leave them
/// dead, and the eleven [VaultPlaceScreen]s it describes are why it is gone
/// rather than narrowed. What survives of the original reasoning is narrower and
/// still enforced: the *pages* those rows lead to have no behaviour either, so
/// nothing here is pretending to store, search, or delete a file — a row that
/// opens a page which honestly says "No images yet" is a first draft a user can
/// walk around in, where a row that opened nothing was a control that lied.
///
/// [_noop] survives for the Search button alone, and it is now the only control
/// on the screen that is enabled-looking and inert. That asymmetry is
/// deliberate: search has no destination and no honest empty page to open,
/// whereas every other control here names a category a phone already has. The
/// overflow opens [SecretMenu] (D-115), which holds one row and leads to the
/// hidden area's own settings (FEAT-SEC-004).
class SecretScreen extends ConsumerStatefulWidget {
  const SecretScreen({super.key});

  @override
  ConsumerState<SecretScreen> createState() => _SecretScreenState();
}

class _SecretScreenState extends ConsumerState<SecretScreen> {

  // The five non-grid rows resolve their [VaultPlace] from [vaultPlaces] rather
  // than repeating its title and icon, for the same reason the Categories grid
  // does (`_secretCategories` above): the row and the page it opens must agree
  // about what they are called, and holding the place makes that structural.
  //
  // **Resolved once, statically, and not in `build`.** They are `late final`
  // rather than locals because the whole `ListView` was `const` while these rows
  // were hand-written, and the alternative — five `vaultPlaceById(...)!` calls
  // inline in a widget list — cannot be const at all. Late finals keep the tree
  // const-constructible wherever it still has no closures, and the `!` is
  // unreachable in practice: each id below is asserted against `vaultPlaces` by
  // `vault_place_pages_test.dart`, so a rename that broke one fails that suite
  // rather than throwing on the user's screen.
  static final VaultPlace _recent = vaultPlaceById('recent')!;
  static final VaultPlace _internalStorage = vaultPlaceById('internal-storage')!;
  static final VaultPlace _sdCard = vaultPlaceById('sd-card')!;
  static final VaultPlace _recycleBin = vaultPlaceById('recycle-bin')!;
  static final VaultPlace _analyseStorage = vaultPlaceById('analyse-storage')!;

  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  void _closeSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
  }

  List<VaultImage> _searchImages(WidgetRef ref) {
    final gallery = ref.read(vaultImagesProvider).valueOrNull;
    if (gallery == null) return [];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return gallery.visible;
    return gallery.visible.where((image) {
      return image.fileName.toLowerCase().contains(q) ||
          image.dateAdded.toIso8601String().toLowerCase().contains(q) ||
          image.albumIds.any((id) {
            final album = gallery.albums.where((a) => a.id == id);
            return album.isNotEmpty && album.first.name.toLowerCase().contains(q);
          });
    }).toList();
  }

  List<VaultDocument> _searchDocuments(WidgetRef ref) {
    final state = ref.read(vaultDocumentsProvider).valueOrNull;
    if (state == null) return [];
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return state.visible;
    return state.visible.where((doc) {
      return doc.fileName.toLowerCase().contains(q) ||
          doc.dateAdded.toIso8601String().toLowerCase().contains(q);
    }).toList();
  }

  /// Opens [place]'s page.
  ///
  /// **A named method rather than the same `context.push` closure five times**,
  /// so the push — and the route helper it names — appears once. It is also what
  /// lets every row's `onTap` share a single shape, which is what makes a
  /// reviewer able to confirm by eye that no row pushes somewhere unintended.
  static void _browse(BuildContext context, VaultPlace place) {
    context.push(AppRoutes.secretBrowseTo(place.id));
  }

  /// The Internal storage row's subtitle, read from [vaultStorageProvider].
  ///
  /// `'…'` while the channel answers and `'Unavailable'` if it never does —
  /// the two states a real read has, neither of which is a made-up number.
  /// The figures themselves come from [formatStorageSubtitle], so the row and
  /// the SD row cannot drift into two formats.
  static String _internalSubtitle(WidgetRef ref) => ref
      .watch(vaultStorageProvider)
      .when(
        data: (storage) => formatStorageSubtitle(storage.internal),
        loading: () => '…',
        error: (_, _) => 'Unavailable',
      );

  /// The SD card row's subtitle.
  ///
  /// `'Not inserted'` for an absent card — the same words the row carried when
  /// the value was hardcoded, because that string was already true and is now
  /// true because the platform said so rather than because a constant did.
  static String _sdSubtitle(WidgetRef ref) => ref
      .watch(vaultStorageProvider)
      .when(
        data: (storage) =>
            storage.sdCard == null
                ? 'Not inserted'
                : formatStorageSubtitle(storage.sdCard),
        loading: () => '…',
        error: (_, _) => 'Unavailable',
      );

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    return Scaffold(
      backgroundColor: context.appColors.background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                if (_searching) _searchHeader(context) else _defaultHeader(context, ref),
                Expanded(
                  child: _searching
                      ? _searchResults(context, ref)
                      : _defaultBody(context, ref),
                ),
              ],
            ),
            // The second control D-84 ruled out, kept for the same reason as on
            // the PIN screen: a user in a hidden area needs one obvious way to
            // return to the app they came from (D-86). Now a sibling of the
            // scrolling column rather than of a [Stack] holding one button, so it
            // floats over the cards — which is why the list above pads for it.
            if (!_searching) const SecretHomeButton(),
          ],
        ),
      ),
    );
  }

  Widget _defaultHeader(BuildContext context, WidgetRef ref) {
    return AppPageHeader(
      title: 'Vault',
      actions: <Widget>[
        AppIconButton(
          key: const Key('secret-search'),
          icon: Icons.search,
          tooltip: 'Search',
          onPressed: _toggleSearch,
        ),
        const SizedBox(width: AppSpacing.md),
        AppIconButton(
          key: const Key('secret-overflow'),
          icon: Icons.more_vert,
          tooltip: 'Menu',
          onPressed: () => SecretMenu.show(context),
        ),
      ],
    );
  }

  Widget _searchHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.headerTopGap,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.headerHeight),
        child: Row(
          children: [
            AppIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Close search',
              onPressed: _closeSearch,
              bordered: false,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextField(
                key: const Key('secret-vault-search'),
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search files...',
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.15),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: 'Clear search',
                          onPressed: () => setState(() {
                            _query = '';
                            _searchController.clear();
                          }),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchResults(BuildContext context, WidgetRef ref) {
    final images = _searchImages(ref);
    final documents = _searchDocuments(ref);
    final total = images.length + documents.length;

    if (_query.trim().isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        title: 'Search your vault',
        message: 'Type to search photos and documents',
      );
    }

    if (total == 0) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No results found',
        message: 'Try a different search term',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.xl,
      ),
      children: [
        if (images.isNotEmpty) ...[
          SectionHeader('Photos (${images.length})'),
          SettingsGroup(
            children: [
              for (final image in images)
                SettingsRow(
                  icon: Icons.image_outlined,
                  title: image.fileName,
                  subtitle: _formatDate(image.dateAdded),
                  onTap: () => _openImage(context, ref, image),
                ),
            ],
          ),
        ],
        if (documents.isNotEmpty) ...[
          SectionHeader('Documents (${documents.length})'),
          SettingsGroup(
            children: [
              for (final doc in documents)
                SettingsRow(
                  icon: Icons.description_outlined,
                  title: doc.fileName,
                  subtitle: _formatDate(doc.dateAdded),
                  onTap: () => _openDocument(context, ref, doc),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _openImage(BuildContext context, WidgetRef ref, VaultImage image) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultImageViewer(images: [image], initialIndex: 0),
      ),
    );
  }

  void _openDocument(BuildContext context, WidgetRef ref, VaultDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VaultDocumentViewerScreen(document: doc),
      ),
    );
  }

  Widget _defaultBody(BuildContext context, WidgetRef ref) {
    // Scrollable because the content stopped fitting: a 360 × 640
    // screen runs past the bottom, and so does this one at D-54's 1.3×
    // text scale. A page that cannot scroll is a page whose last card
    // cannot be reached.
    return ListView(
      key: const Key('secret-home-list'),
      padding: const EdgeInsets.only(
        // Clears the floating home button instead of sitting under
        // it: the 56 px circle plus the 24 px inset it is padded by
        // plus the 12 px that keeps the last card off the button's
        // own optical edge. Written from the two tokens that size
        // it, so moving either moves this.
        bottom:
            AppSizes.secretHomeButton +
            AppSecretSpacing.homeButtonInset +
            AppSpacing.md,
      ),
      children: <Widget>[
        SizedBox(height: AppSpacing.lg),
        // **No [SectionHeader] above this one**, unlike the two
        // groups below it. "Recent files" is the only row on the
        // page, so a label over it would be a heading announcing a
        // list of one; it is the page's own first action instead,
        // and the [AppSpacing.lg] above it matches History's.
        SettingsGroup(
          children: <Widget>[
            SettingsRow(
              key: const Key('secret-recent-files'),
              iconWidget: vaultPlaceGlyph(_recent),
              title: _recent.title,
              onTap: () => _browse(context, _recent),
            ),
          ],
        ),
        const SectionHeader('Categories'),
        const _SecretCategoryCard(),
        const SectionHeader('Storage'),
        SettingsGroup(
          children: <Widget>[
            SettingsRow(
              key: const Key('secret-storage-internal'),
              // `smartphone`, not the `phone_iphone` the Vibration
              // row uses — same glyph in two places reads as a bug
              // rather than as a theme.
              iconWidget: vaultPlaceGlyph(_internalStorage),
              title: _internalStorage.title,
              subtitle: _internalSubtitle(ref),
              onTap: () => _browse(context, _internalStorage),
            ),
            SettingsRow(
              key: const Key('secret-storage-sd'),
              iconWidget: vaultPlaceGlyph(_sdCard),
              title: _sdCard.title,
              subtitle: _sdSubtitle(ref),
              onTap: () => _browse(context, _sdCard),
            ),
          ],
        ),
        // A [SizedBox] rather than a [SectionHeader], because these
        // two rows are actions and not a group — 24 px is the gap
        // [SectionHeader.topPadding] leaves between two groups, so
        // the rhythm matches without inventing a heading for them.
        const SizedBox(height: AppSpacing.xl),
        SettingsGroup(
          children: <Widget>[
            SettingsRow(
              key: const Key('secret-recycle-bin'),
              iconWidget: vaultPlaceGlyph(_recycleBin),
              title: _recycleBin.title,
              onTap: () => _browse(context, _recycleBin),
            ),
            SettingsRow(
              key: const Key('secret-analyse-storage'),
              iconWidget: vaultPlaceGlyph(_analyseStorage),
              title: _analyseStorage.title,
              onTap: () => _browse(context, _analyseStorage),
            ),
          ],
        ),
      ],
    );
  }
}


