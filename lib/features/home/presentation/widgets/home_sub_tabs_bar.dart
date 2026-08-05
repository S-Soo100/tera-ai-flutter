import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../domain/device_mode.dart';
import '../home_set_providers.dart';

/// PRD §3.3 Sub-Tabs Bar — `[사육장 제어] | [타임라인]` 2구분 세그먼트.
///
/// 모드에 따라 한쪽이 비활성화되고, 세트가 바뀌면 그 모드의 기본 탭으로
/// 되돌아간다(비활성 탭이 선택된 채 남으면 빈 화면이 보인다).
class HomeSubTabsBar extends ConsumerWidget {
  const HomeSubTabsBar({super.key});

  static const controlKey = Key('home_subtab_control');
  static const timelineKey = Key('home_subtab_timeline');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode =
        ref.watch(currentDeviceModeProvider).valueOrNull ?? DeviceMode.none;
    final selected = ref.watch(homeSubTabProvider);

    // 선택된 탭이 현재 모드에서 비활성이면 기본 탭으로 교정한다.
    // build 중 provider를 쓰면 안 되므로 프레임 뒤로 미룬다.
    final needsFix = (selected == HomeSubTab.control && !mode.controlEnabled) ||
        (selected == HomeSubTab.timeline && !mode.timelineEnabled);
    if (needsFix) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(homeSubTabProvider.notifier).state = mode.defaultTab;
      });
    }

    return Row(
      children: [
        Expanded(
          child: _SegmentTab(
            key: controlKey,
            label: 'home_subtab_control'.tr(),
            enabled: mode.controlEnabled,
            selected: selected == HomeSubTab.control,
            onTap: () => ref.read(homeSubTabProvider.notifier).state =
                HomeSubTab.control,
          ),
        ),
        Expanded(
          child: _SegmentTab(
            key: timelineKey,
            label: 'home_subtab_timeline'.tr(),
            enabled: mode.timelineEnabled,
            selected: selected == HomeSubTab.timeline,
            onTap: () => ref.read(homeSubTabProvider.notifier).state =
                HomeSubTab.timeline,
          ),
        ),
      ],
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    super.key,
    required this.label,
    required this.enabled,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppStyles.spacing12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: selected && enabled ? scheme.primary : Colors.transparent,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: enabled
                    ? (selected ? scheme.primary : null)
                    : Theme.of(context).disabledColor,
              ),
        ),
      ),
    );
  }
}
