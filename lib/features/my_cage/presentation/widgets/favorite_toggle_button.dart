import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../bookmark_controller.dart';
import '../clip_memo_providers.dart';
import 'clip_memo_editor.dart';

/// Shared bookmark entry point. Adding always offers an optional local memo.
class FavoriteToggleButton extends ConsumerWidget {
  const FavoriteToggleButton({super.key, required this.clipId, this.color});
  final String clipId;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(clipMemoAccountProvider);
    final state = owner == null
        ? null
        : ref.watch(
            bookmarkControllerProvider((ownerId: owner, clipId: clipId)));
    if (owner != null) {
      ref.listen(bookmarkControllerProvider((ownerId: owner, clipId: clipId)),
          (previous, next) {
        if (next.error != null && previous?.error != next.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('clip_save_failed'.tr()),
            action: SnackBarAction(
                label: 'retry'.tr(),
                onPressed: () {
                  if (!context.mounted ||
                      ref.read(clipMemoAccountProvider) != owner) {
                    return;
                  }
                  ref
                      .read(bookmarkControllerProvider(
                          (ownerId: owner, clipId: clipId)).notifier)
                      .retry();
                }),
          ));
        }
      });
    }
    final favorite = state?.desired ?? false;
    return IconButton(
      icon: FigmaIcon.tinted(
          favorite ? FigmaIcons.bookmarkCheck : FigmaIcons.bookmark,
          color: color ?? context.glass.textPrimary,
          size: 36),
      tooltip: (favorite ? 'clip_favorite_remove' : 'clip_favorite_add').tr(),
      onPressed:
          owner == null ? null : () => toggleClipBookmark(context, ref, clipId),
    );
  }
}
