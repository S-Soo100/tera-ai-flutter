import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../shared/widgets/glass_segmented_control.dart';
import '../../domain/device_mode.dart';
import '../home_set_providers.dart';

/// PRD §3.3 Sub-Tabs Bar — `[사육장 제어] | [타임라인]` 2구분 세그먼트.
///
/// 모드에 따라 한쪽이 비활성화되고, 세트가 바뀌면 그 모드의 기본 탭으로
/// 되돌아간다(비활성 탭이 선택된 채 남으면 빈 화면이 보인다).
///
/// 표면은 공용 [GlassSegmentedControl] — 여기서 세운 문법(유리 트랙 안
/// 불투명 흰 알약)을 공용판으로 뽑았으므로 렌더링은 그쪽에 위임하고,
/// 이 위젯은 모드 게이트·선택 보정 로직만 갖는다.
class HomeSubTabsBar extends ConsumerWidget {
  const HomeSubTabsBar({super.key});

  static const controlKey = Key('home_subtab_control');
  static const timelineKey = Key('home_subtab_timeline');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(currentDeviceModeProvider);
    final mode = modeAsync.valueOrNull ?? DeviceMode.none;
    final selected = ref.watch(homeSubTabProvider);

    // 선택된 탭이 현재 모드에서 비활성이면 기본 탭으로 교정한다.
    // build 중 provider를 쓰면 안 되므로 프레임 뒤로 미룬다.
    //
    // **로딩 중에는 교정하지 않는다.** 모드가 아직 안 왔을 때의 폴백은
    // DeviceMode.none인데, none은 두 탭이 다 비활성이라 무조건 교정이 돌아
    // 타임라인으로 넘어간다. 그 뒤 진짜 모드(integrated)가 도착해도 타임라인은
    // 유효한 탭이라 되돌아오지 않아, 통합 세트가 항상 타임라인으로 열린다.
    final needsFix = modeAsync.hasValue &&
        ((selected == HomeSubTab.control && !mode.controlEnabled) ||
            (selected == HomeSubTab.timeline && !mode.timelineEnabled));
    if (needsFix) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(homeSubTabProvider.notifier).state = mode.defaultTab;
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      child: GlassSegmentedControl<HomeSubTab>(
        segments: [
          GlassSegment(
            value: HomeSubTab.control,
            label: 'home_subtab_control'.tr(),
            enabled: mode.controlEnabled,
            itemKey: controlKey,
          ),
          GlassSegment(
            value: HomeSubTab.timeline,
            label: 'home_subtab_timeline'.tr(),
            enabled: mode.timelineEnabled,
            itemKey: timelineKey,
          ),
        ],
        selected: selected,
        onChanged: (v) => ref.read(homeSubTabProvider.notifier).state = v,
      ),
    );
  }
}
