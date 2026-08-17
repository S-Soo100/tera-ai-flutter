import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_tab_header.dart';
import '../../../shared/widgets/pending_section.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
import '../../home/presentation/home_control_providers.dart';
import '../../home/presentation/home_set_providers.dart';
import '../../profile/presentation/profile_providers.dart';
import 'stats_providers.dart';
import '../../../shared/widgets/env_chart.dart';
import '../domain/stats_metric.dart';
import '../domain/stats_period.dart';
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
///
/// A안 표면 규칙(월페이퍼·전역 다크·SafeArea)은 [GlassTabShell]이 맡는다 —
/// ListView가 `MediaQuery.padding.bottom`(플로팅 독 높이)을 직접 소비한다
/// (padding을 명시한 ListView는 자동 인셋이 꺼진다).
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static const pendingKey = Key('stats_pending_sections');
  static const mainChartKey = Key('stats_main_chart');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;

    return GlassTabShell(
      child: deviceId == null
          ? Column(
              children: [
                const _StatsHeader(),
                Expanded(child: Center(child: Text('stats_no_device'.tr()))),
              ],
            )
          : Builder(
              builder: (context) => ListView(
                padding: glassDockListPadding(context),
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
///
/// 표면은 홈 `HomeHeaderBar`와 같은 [GlassTabHeader] 문법 — 개체가 대형
/// 타이틀, 사육장은 유리 캡슐이 세트 드롭다운을 겸한다.
class _StatsHeader extends ConsumerWidget {
  const _StatsHeader();

  static const pickerArrowKey = Key('stats_header_dropdown_arrow');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sets = ref.watch(enclosureSetsProvider).valueOrNull ?? const [];
    final current = ref.watch(currentSetProvider).valueOrNull;
    final profile = ref.watch(profileNotifierProvider).valueOrNull;
    final multi = sets.length > 1;

    // 홈과 같은 캡슐 조건: 개체가 주인공이라 사육장이 보조로 필요하거나,
    // 세트가 여럿이라 선택기가 필요할 때.
    final showCapsule = current != null && (current.pet != null || multi);

    // 개체 없는 멀티 세트는 제목을 사육장명으로 폴백하지 않는다 — 캡슐과
    // 같은 문자열이 두 번 선다(홈 헤더와 같은 규칙).
    return GlassTabHeader(
      title: current == null
          ? 'tab_stats'.tr()
          : current.pet?.name ??
              (multi ? 'home_title_default'.tr() : current.enclosure.name),
      capsuleLabel: showCapsule ? current.enclosure.name : null,
      onPickCapsule:
          multi ? () => _openPicker(context, ref, sets.length) : null,
      capsuleArrowKey: pickerArrowKey,
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

    // 주간은 창·데이터·마커가 전부 다르다. 위젯은 하나로 두고 **물리는 것만**
    // 갈아끼운다 — 기간 → 소스 매핑은 stats_providers의 파생 3종 한 곳이다.
    final weekly = period == StatsPeriod.weekly;
    final async = ref.watch(statsChartDataProvider);
    final window = ref.watch(statsWindowProvider);
    final metrics = ref.watch(statsMetricsProvider);

    return Column(
      key: StatsScreen.mainChartKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
          child: Text(period.chartTitleKey.tr(),
              style: AppTheme.glassSectionLabel),
        ),
        const SizedBox(height: AppStyles.spacing8),
        // 요약은 홈 LiveEnvCard와 같은 유리 카드 — 안의 [StatsSummaryBar]
        // (스크러버 배선 포함)는 무변경, 감싸는 표면만 A안.
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
          child: GlassCard(
            padding: EdgeInsets.symmetric(vertical: AppStyles.spacing12),
            child: StatsSummaryBar(),
          ),
        ),
        // Figma: 요약 하단 → 플롯 상단 16
        const SizedBox(height: AppStyles.spacing16),
        async.when(
          loading: () => const _ChartSkeleton(),
          // **실패는 되돌릴 수 있게** 한다. 맨 문구만 두면 앱을 다시 켜는 것
          // 말고는 할 수 있는 게 없다.
          error: (e, _) => Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
            child: EmptyState(
              title: 'stats_load_failed'.tr(),
              actionLabel: 'error_retry'.tr(),
              onAction: () => invalidateStatsChartData(ref),
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
              // 유리 카드는 겉면만이다 — 차트 내부(격자·창·눈금·스크러버
              // 동작: 밤 띠 off·손 떼도 유지·✕ 해제)는 홈과 같은 [EnvChart]
              // 그대로. 홈 온습도 카드(GlassCard)와 같은 카드 문법이다.
              : Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacing16),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: EnvChart.outerPadding,
                      vertical: AppStyles.spacing16,
                    ),
                    // 스크럽 watch는 이 Consumer 안에만 둔다 — 부모 build에
                    // 두면 손가락을 끄는 매 프레임 섹션 전체(카드 2장)가
                    // 리빌드된다. 여기서는 차트 한 장만 다시 그린다.
                    child: Consumer(
                      builder: (context, ref, _) => EnvChart(
                        data: d,
                        window: window,
                        // 마커 조회 실패는 차트를 막지 않는다 — 곡선이 본체다.
                        //
                        // 주간에는 아예 그리지 않는다. 7일치면 수백 개가 14pt
                        // 칩으로 겹쳐 쌓여, 언제 무엇이 돌았는지 되레 못 읽는다.
                        markers: weekly
                            ? const []
                            : ref.watch(actuatorMarkersProvider).valueOrNull ??
                                const [],
                        showTemperature:
                            metrics.contains(StatsMetric.temperature),
                        showHumidity: metrics.contains(StatsMetric.humidity),
                        scrubX: ref.watch(statsScrubProvider),
                        onScrubChanged: (x) =>
                            ref.read(statsScrubProvider.notifier).state = x,
                      ),
                    ),
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
