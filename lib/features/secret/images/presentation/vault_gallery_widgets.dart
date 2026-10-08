import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/design/app_palette.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/widgets/core_widgets.dart';
import '../domain/vault_image.dart';

/// Selection header + tab rows for the image gallery.
class VaultGalleryHeader extends StatelessWidget {
  const VaultGalleryHeader({
    required this.selecting,
    required this.selectedCount,
    required this.title,
    required this.allSelected,
    required this.onCancel,
    required this.onSelectAll,
    required this.onSearch,
    required this.onMore,
    super.key,
  });

  final bool selecting;
  final int selectedCount;
  final String title;
  final bool allSelected;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final VoidCallback onSearch;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    if (selecting) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppSpacing.screenHorizontal,
          right: AppSpacing.screenHorizontal,
          top: AppSpacing.headerTopGap,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.headerHeight),
          child: Row(
            children: [
              AppIconButton(
                icon: Icons.close,
                tooltip: 'Cancel selection',
                onPressed: onCancel,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '$selectedCount selected',
                  style: context.type.selectionCount,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton(
                onPressed: onSelectAll,
                child: Text(allSelected ? 'None' : 'All'),
              ),
            ],
          ),
        ),
      );
    }
    // Custom compact header: back + title + search + more in one row.
    // SecondaryPageHeader reserves a full 48px trailing slot which overflows
    // at 800px test width with two action buttons, so the gallery owns its
    // own row with tighter action spacing.
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        top: AppSpacing.headerTopGap,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.headerHeight),
        child: Row(
          children: [
            AppIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                style: context.type.screenTitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIconButton(
              icon: Icons.search,
              tooltip: 'Search photos',
              onPressed: onSearch,
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIconButton(
              icon: Icons.more_vert,
              tooltip: 'More options',
              onPressed: onMore,
            ),
          ],
        ),
      ),
    );
  }
}

/// One grid cell with circular selection check + favorite heart.
class VaultGridTile extends StatelessWidget {
  const VaultGridTile({
    required this.image,
    required this.file,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
    super.key,
  });

  final VaultImage image;
  final File file;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.card / 2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: selecting && !selected ? 0.55 : 1,
              child: Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: 360,
                errorBuilder: (_, _, _) => Container(
                  color: colors.surface,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          if (image.isFavorite)
            const Positioned(
              right: 6,
              bottom: 6,
              child: Icon(Icons.favorite, size: 16, color: Colors.white),
            ),
          if (selecting)
            Positioned(
              top: 6,
              right: 6,
              child: AnimatedScale(
                scale: selected ? 1 : 0.85,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.selectionAccent : Colors.black54,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check,
                          size: 16,
                          color: colors.selectionCheck,
                        )
                      : null,
                ),
              ),
            ),
          if (selected)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.card / 2),
                  border: Border.all(color: colors.selectionAccent, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
