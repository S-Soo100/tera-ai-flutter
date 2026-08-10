import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/pending_section.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../home/presentation/home_control_providers.dart';
import '../../home/presentation/home_set_providers.dart';
import '../../profile/presentation/profile_providers.dart';
import 'stats_providers.dart';
import 'widgets/stats_env_chart.dart';
import 'widgets/stats_period_bar.dart';
import 'widgets/stats_summary_bar.dart';

/// 통계 탭. 기획안 §4.3.
///
/// **레이아웃은 기획안 순서대로 전부 세우고, 못 만든 칸은 자리표시자로 둔다.**
/// 기획안이 스스로 *"확정 스펙이 아니다"*(§6 D)라고 적은 화면이라 내용을
/// 지어내지 않는다. 다만 빈 화면으로 두면 "이 탭은 없는 기능"으로 읽히므로,
/// 각 칸이 **무엇을 보여줄 자리이고 왜 아직 없는지**를 밝힌다.
///
/// 지금 실물이 있는 것은 **일간 온습도 차트** 하나다(Figma가 그려준 유일한
/// 통계 화면). 나머지는 [PendingSection].
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static const pendingKey = Key('stats_pending_sections');
  static const mainChartKey = Key('stats_main_chart');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: deviceId == null
            ? Column(
                children: [
                  const _StatsHeader(),
                  Expanded(child: Center(child: Text('stats_no_device'.tr()))),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: AppStyles.spacing24),
                children: const [
                  _StatsHeader(),
                  StatsPeriodBar(),
                  SizedBox(height: AppStyles.spacing8),
                  StatsMetricFilter(),
                  SizedBox(height: AppStyles.spacing8),
                  _MainChartSection(),
                  SizedBox(height: AppStyles.spacing24),
                  _PendingSections(key: StatsScreen.pendingKey),
                ],
              ),
      ),
    );
  }
}

/// 통계도 홈과 같은 헤더를 쓴다 — **누구의 통계인지**가 먼저다.
///
/// 개체를 바꾸는 경로가 홈에만 있으면, 통계를 보다가 다른 개체가 궁금할 때
/// 홈으로 돌아갔다 와야 한다.
class _StatsHeader extends ConsumerWidget {
  const _StatsHeader();

  static const pickerArrowKey = Key('stats_header_dropdown_arrow');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];
    final current = ref.watch(currentSetProvider).valueOrNull;
    final profile = ref.watch(profileNotifierProvider).valueOrNull;

    return ScreenHeader(
      title: current == null
          ? 'tab_stats'.tr()
          : (current.pet?.name ?? current.enclosure.name),
      subtitle: current == null ? null : 'tab_stats'.tr(),
      onPick: sets.length > 1 ? () => _openPicker(context, ref, sets.length) : null,
      pickerArrowKey: pickerArrowKey,
      actions: [
        AccountAvatar(
          tooltip: 'home_account'.tr(),
          imageUrl: profile?.avatarUrl,
          displayName: profile?.displayName,
          onPressed: () => context.push('/profile'),
        ),
      ],
    );
  }

  Future<void> _openPicker(
      BuildContext context, WidgetRef ref, int count) async {
    final sets = ref.read(enclosureSetsProvider).valueOrNull ?? const [];
    final currentIndex = ref.read(selectedSetIndexProvider);
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (var i = 0; i < sets.length; i++)
              ListTile(
                selected: i == currentIndex,
                title: Text(sets[i].pet?.name ?? sets[i].enclosure.name),
                subtitle:
                    sets[i].pet == null ? null : Text(sets[i].enclosure.name),
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      ref.read(selectedSetIndexProvider.notifier).state = picked;
    }
  }
}

/// §4.3.3 메인 복합 차트.
///
/// 일간만 실물이다. 주간·월간은 같은 자리에 자리표시자가 들어간다 —
/// **차트가 있던 곳이 갑자기 비면 데이터가 없는 줄 안다.**
class _MainChartSection extends ConsumerWidget {
  const _MainChartSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statsPeriodProvider);

    if (!period.isReady) {
      return Padding(
        key: StatsScreen.mainChartKey,
        padding: const EdgeInsets.only(top: AppStyles.spacing8),
        child: PendingSection(
          title: 'stats_main_chart_title'.tr(),
          description: 'stats_period_pending_desc'
              .tr(namedArgs: {'period': period.labelKey.tr()}),
          reason: 'stats_reason_design'.tr(),
        ),
      );
    }

    final async = ref.watch(statsChartDataProvider);
    final metrics = ref.watch(statsMetricsProvider);

    return Column(
      key: StatsScreen.mainChartKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
          child: Text('stats_daily_title'.tr(),
              style: AppStyles.subsectionTitle(context)),
        ),
        const SizedBox(height: AppStyles.spacing8),
        const StatsSummaryBar(),
        // Figma: 요약 하단 → 플롯 상단 16
        const SizedBox(height: AppStyles.spacing16),
        async.when(
          loading: () => const _ChartSkeleton(),
          // **실패는 되돌릴 수 있게** 한다. 맨 문구만 두면 앱을 다시 켜는 것
          // 말고는 할 수 있는 게 없다.
          error: (e, _) => Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppStyles.spacing16),
            child: EmptyState(
              title: 'stats_load_failed'.tr(),
              actionLabel: 'error_retry'.tr(),
              onAction: () => ref.invalidate(statsChartDataProvider),
            ),
          ),
          // 데이터가 없는 것과 기능이 없는 것은 **다르게 보여야 한다** —
          // 같은 모양이면 사용자가 자기 기록이 사라진 줄 안다.
          data: (d) => !d.hasData
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacing16),
                  child: EmptyState(
                    title: 'stats_no_data'.tr(),
                    description: 'stats_no_data_desc'.tr(),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: StatsEnvChart.outerPadding),
                  child: StatsEnvChart(
                    data: d,
                    window: ref.watch(statsWindowProvider),
                    // 마커 조회 실패는 차트를 막지 않는다 — 곡선이 본체다.
                    markers: ref
                            .watch(statsActuatorMarkersProvider)
                            .valueOrNull ??
                        const [],
                    metrics: metrics,
                  ),
                ),
        ),
      ],
    );
  }
}

/// 로딩은 스켈레톤으로. 프로젝트 규칙상 CircularProgressIndicator는 쓰지 않는다.
class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHigh;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: Theme.of(context).colorScheme.surfaceContainerLow,
        child: Container(
          height: 194,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(AppStyles.cardRadius),
          ),
        ),
      ),
    );
  }
}

/// 기획안 §4.3.4~§4.3.8. 순서를 기획안대로 지킨다 — 나중에 실물을 끼울 때
/// 자리를 다시 정하지 않기 위함이다.
class _PendingSections extends StatelessWidget {
  const _PendingSections({super.key});

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: AppStyles.spacing12);
    return Column(
      children: [
        // §4.3.4 — 이 앱이 통계를 두는 진짜 이유. 숫자를 읽어주는 칸이다.
        PendingSection(
          title: 'stats_ai_title'.tr(),
          description: 'stats_ai_desc'.tr(),
          reason: 'stats_reason_data'.tr(),
        ),
        gap,
        // §4.3.5
        PendingSection(
          title: 'stats_behavior_title'.tr(),
          description: 'stats_behavior_desc'.tr(),
          reason: 'stats_reason_vision'.tr(),
        ),
        gap,
        // §4.3.6
        PendingSection(
          title: 'stats_distribution_title'.tr(),
          description: 'stats_distribution_desc'.tr(),
          reason: 'stats_reason_design'.tr(),
        ),
        gap,
        // §4.3.7
        PendingSection(
          title: 'stats_heatmap_title'.tr(),
          description: 'stats_heatmap_desc'.tr(),
          reason: 'stats_reason_vision'.tr(),
        ),
        gap,
        // §4.3.8
        PendingSection(
          title: 'stats_audit_title'.tr(),
          description: 'stats_audit_desc'.tr(),
          reason: 'stats_reason_hw'.tr(),
        ),
      ],
    );
  }
}
