import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'analytics_boundary.dart';
import 'analytics_consent.dart';

class AnalyticsConsentTile extends ConsumerWidget {
  const AnalyticsConsentTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consent = ref.watch(analyticsConsentProvider);
    final enabled = ref.watch(analyticsRuntimeConfigProvider).canCollect;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile.adaptive(
        key: const Key('analytics_consent_switch'),
        title: Text('analytics_consent_title'.tr()),
        subtitle: Text('analytics_consent_description'.tr()),
        value: consent.granted,
        onChanged: consent.accountId == null || consent.saving
            ? null
            : (value) =>
                ref.read(analyticsConsentProvider.notifier).setGranted(value),
      ),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            consent.saveFailed
                ? 'analytics_consent_save_failed'.tr()
                : !enabled
                    ? 'analytics_consent_preparing'.tr()
                    : 'analytics_consent_withdrawal'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
          )),
    ]);
  }
}
