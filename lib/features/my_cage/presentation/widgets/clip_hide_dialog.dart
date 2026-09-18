import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/glass_palette.dart';
import '../clip_visibility_providers.dart';

Future<void> showClipHideDialog(BuildContext context,
        {required String ownerId, required String clipId}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _ClipHideDialog(ownerId: ownerId, clipId: clipId));

class _ClipHideDialog extends ConsumerWidget {
  const _ClipHideDialog({required this.ownerId, required this.clipId});
  final String ownerId, clipId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(clipVisibilityAccountProvider, (_, account) {
      if (account != ownerId) {
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      }
    });
    if (ref.watch(clipVisibilityAccountProvider) != ownerId) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(clipVisibilityProvider(ownerId));
    final busy = state.hidingIds.contains(clipId);
    return PopScope(
        canPop: !busy,
        child: AlertDialog(
          scrollable: true,
          backgroundColor: context.glass.wallpaper,
          surfaceTintColor: context.glass.wallpaper,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('clip_hide_confirm'.tr()),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('clip_hide_description'.tr()),
                if (state.saveError != null && state.failedClipId == clipId)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text('clip_hide_failed'.tr(),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
              ]),
          actions: [
            TextButton(
                onPressed: busy ? null : () => Navigator.of(context).pop(),
                child: Text('clip_hide_cancel'.tr())),
            FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final success = await ref
                            .read(clipVisibilityProvider(ownerId).notifier)
                            .hide(clipId);
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                child: Text('clip_hide_action'.tr())),
          ],
        ));
  }
}
