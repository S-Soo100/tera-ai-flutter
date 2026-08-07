import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_styles.dart';
import '../../home/presentation/home_control_providers.dart';
import 'stats_providers.dart';
import 'widgets/stats_env_chart.dart';
import 'widgets/stats_summary_bar.dart';

/// 통계 탭. PRD §3.4 "차트 터치 시 통계 탭으로 이동"의 목적지.
///
/// **현재 구현 범위는 Figma가 그려준 「온습도 그래프 - 24시」 하나뿐이다.**
/// 같은 Figma 섹션의 `주간` · `주간 온습도 분포` · `행동 분석`은 제목만 있고
/// 디자인이 없다(`docs/figma-final-design-transcript.md` §3). 피드백에도
/// "7일, 30일은 어떻게 봐야할지 감이 안 옴"이라 적혀 있어, 임의로 그리지 않고
/// 대기 상태를 화면에 정직하게 표시한다.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static const pendingKey = Key('stats_pending_sections');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text('tab_stats'.tr())),
      body: deviceId == null
          ? Center(child: Text('stats_no_device'.tr()))
          : ListView(
              padding: const EdgeInsets.only(bottom: AppStyles.spacing24),
              children: const [
                SizedBox(height: AppStyles.spacing8),
                _DailySection(),
                SizedBox(height: AppStyles.spacing24),
                _PendingSections(),
              ],
            ),
    );
  }
}

class _DailySection extends ConsumerWidget {
  const _DailySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(statsChartDataProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
          child: Text('stats_daily_title'.tr(),
              style: AppStyles.subsectionTitle(context)),
        ),
        const SizedBox(height: AppStyles.spacing8),
        const StatsSummaryBar(),
        const SizedBox(height: AppStyles.spacing12),
        async.when(
          loading: () => const _ChartSkeleton(),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppStyles.spacing16),
            child: Text('stats_load_failed'.tr()),
          ),
          data: (d) => !d.hasData
              ? Padding(
                  padding: const EdgeInsets.all(AppStyles.spacing16),
                  child: Text('stats_no_data'.tr()),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppStyles.spacing12),
                  child: StatsEnvChart(data: d),
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

/// 디자인 대기 중인 나머지 통계. 빈 화면으로 두면 "고장인가?"가 되므로,
/// 무엇이 왜 없는지 밝힌다.
class _PendingSections extends StatelessWidget {
  const _PendingSections();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: StatsScreen.pendingKey,
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppStyles.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('stats_pending_title'.tr(),
                  style: AppStyles.subsectionTitle(context)),
              const SizedBox(height: AppStyles.spacing8),
              Text(
                'stats_pending_body'.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
