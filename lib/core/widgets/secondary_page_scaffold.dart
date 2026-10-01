import 'package:flutter/material.dart';

import '../design/app_colors.dart';

/// The shared chrome for a screen that is pushed on top of another one (D-74).
///
/// It wraps the two things every secondary screen does the same way: the black
/// page background, and a `SafeArea` whose only child is a column holding the
/// header above an `Expanded` body. The screens differ in their header and their
/// body; nothing else about the frame is theirs to choose, so it is stated once
/// here rather than five times across History, Settings, About, and the two
/// legal documents.
///
/// The header sits *inside* the `SafeArea` rather than above it — the opposite
/// of what an `AppBar` does — because the header's own boxes are what ride the
/// 24 px margin, and an `AppBar` would have inset them by its reserved leading
/// slot before the screen ever saw them (D-70). Putting the header in the body's
/// column is also what makes `Expanded` mean something: the body is handed the
/// height that is left, so an empty state centres in the page below the header
/// instead of in the whole screen.
class SecondaryPageScaffold extends StatelessWidget {
  const SecondaryPageScaffold({
    required this.header,
    required this.body,
    super.key,
  });

  /// The bar across the top, normally a [SecondaryPageHeader].
  final Widget header;

  /// The page below the bar. Given a bounded height, so it may centre itself in
  /// what is left.
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            header,
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
