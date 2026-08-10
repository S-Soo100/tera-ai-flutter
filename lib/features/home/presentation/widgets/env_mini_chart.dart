import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/env_chart.dart';
import '../home_control_providers.dart';

/// 최근 24시간 온·습도 차트 (홈).
///
/// **통계 탭과 같은 그래프**([EnvChart])를 쓴다. 예전에는 sparkline로 따로
/// 그렸는데, 눈금이 없어 "몇 도인지"를 못 읽었고 통계 탭으로 넘어가면 그림이
/// 달라져 "방금 본 그래프"가 아니게 됐다. 창도 같은 [chartWindowProvider]를 쓴다.
///
/// 홈만의 차이 둘:
/// - **밤 띠**(`22:00~06:00`)를 깐다. 기획안 §3.1 ②의 활동 집계 창이자 이 앱의
///   시그니처다 — 야행성 개체를 다루니 "우리 애가 사는 시간"이 어디인지 한눈에
///   보여야 한다. Figma 통계 화면에는 없다.
/// - **스크러버를 켜지 않는다.** 여기는 훑고 통계로 넘어가는 자리라 차트 전체가
///   `/stats` 진입점이다. 탭을 스크럽이 가져가면 그 동선이 막힌다.
class EnvMiniChart extends ConsumerWidget {
  const EnvMiniChart({super.key});

  static const chartKey = Key('env_mini_chart');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(envChartDataProvider).valueOrNull;
    final markers = ref.watch(actuatorMarkersProvider).valueOrNull ?? const [];
    final window = ref.watch(chartWindowProvider);
    final theme = Theme.of(context);
    final hasData = data != null && data.hasData;

    return InkWell(
      key: chartKey,
      onTap: () => context.go('/stats'),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: EnvChart.outerPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('home_chart_title'.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                if (hasData) const Flexible(child: _NightLegend()),
              ],
            ),
            const SizedBox(height: AppStyles.spacing8),
            if (!hasData)
              // 맨 텍스트 한 줄을 차트 높이 한가운데 띄우면 화면이 고장난 것처럼
              // 보인다(실기기에서 화면 1/4이 빈칸이었다).
              EmptyState(
                title: 'home_chart_empty_title'.tr(),
                description: 'home_chart_empty_desc'.tr(),
              )
            else ...[
              // 좌우 여백은 바깥 Padding이 이미 [EnvChart.outerPadding]으로
              // 주고 있다 — 차트는 자기 여백을 스스로 넣지 않는다.
              EnvChart(
                data: data,
                window: window,
                markers: markers,
                nightBand: true,
              ),
              const SizedBox(height: AppStyles.spacing4),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'home_chart_goto_stats'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.primary),
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        size: 16, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 밤 띠 범례. 띠가 무엇인지 한 번은 말해줘야 한다 — 색만 깔아두면
/// "왜 저기만 어둡지?"가 된다.
class _NightLegend extends StatelessWidget {
  const _NightLegend();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppTheme.nightBand(theme.brightness),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppStyles.spacing4),
        Flexible(
          child: Text(
            'home_chart_night'.tr(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
