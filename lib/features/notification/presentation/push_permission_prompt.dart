import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/push_messaging_service.dart';
import 'push_providers.dart';

class PushPermissionPrompt extends ConsumerStatefulWidget {
  const PushPermissionPrompt(
      {super.key, required this.child, required this.navigatorKey});
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;
  @override
  ConsumerState<PushPermissionPrompt> createState() =>
      _PushPermissionPromptState();
}

class _PushPermissionPromptState extends ConsumerState<PushPermissionPrompt> {
  bool _shown = false;
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserProvider.select((u) => u?.id));
    final permission = ref.watch(pushPermissionProvider);
    if (userId != null &&
        permission != PushPermission.unavailable &&
        permission != PushPermission.authorized &&
        !_shown &&
        !_scheduled) {
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (mounted) unawaited(_explain());
      });
    }
    return widget.child;
  }

  Future<void> _explain() async {
    final preferences = ref.read(pushPreferencesProvider);
    if (_shown ||
        preferences.explanationSeen ||
        ref.read(currentUserProvider) == null) {
      return;
    }
    final navigationContext = widget.navigatorKey.currentContext;
    if (navigationContext == null) return;
    _shown = true;
    try {
      await preferences.markExplanationSeen();
      if (!mounted || !navigationContext.mounted) return;
      final enable = await showModalBottomSheet<bool>(
        context: navigationContext,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('push_explanation_title'.tr(),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text('push_explanation_body'.tr()),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text('push_enable'.tr())),
                    TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text('push_later'.tr())),
                  ],
                ))),
      );
      if (enable == true && mounted) await requestPushPermission(ref);
    } catch (_) {
      debugPrint('[push] explanation failed');
    }
  }
}

class PushPermissionBanner extends ConsumerWidget {
  const PushPermissionBanner({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(pushPermissionProvider);
    if (permission == PushPermission.authorized ||
        permission == PushPermission.unavailable) {
      return const SizedBox.shrink();
    }
    final busy = ref.watch(pushPermissionBusyProvider);
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('push_permission_banner'.tr()),
        TextButton(
            onPressed: busy
                ? null
                : () async {
                    final busyNotifier =
                        ref.read(pushPermissionBusyProvider.notifier);
                    final controller =
                        ref.read(pushLifecycleControllerProvider);
                    busyNotifier.state = true;
                    try {
                      await controller.requestPermission(retry: true);
                    } finally {
                      busyNotifier.state = false;
                    }
                  },
            child: Text('push_enable'.tr())),
      ]),
    );
  }
}
