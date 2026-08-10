import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/figma_icon.dart';
import '../../../home/presentation/home_control_providers.dart';
import '../../../my_cage/presentation/supabase_module_providers.dart';
import '../../../../shared/domain/env_chart_data.dart';
import '../../domain/stats_metric.dart';
import '../stats_providers.dart';
import '../../../../shared/widgets/env_chart.dart';

/// Figma 24시 화면 상단 요약 바.
///
/// 좌우 2분할로 온도·습도를 대칭 배치하고, 각 아래에 최고/최저를 붙인다.
/// 최고/최저는 **바로 아래 차트와 같은 구간**([chartExtremesProvider])이다 —
/// 이 숫자는 그래프를 설명하는 값이라 창이 다르면 서로 어긋난다.
///
/// **스크럽 중에는 이 자리가 그 시점의 값으로 바뀐다**(Figma 변형 B). 두 표시가
/// 같은 자리를 쓰므로 [Stack]으로 겹쳐 높이를 고정한다 — 손을 댈 때마다 아래
/// 차트가 위아래로 튀면 읽을 수가 없다.
class StatsSummaryBar extends ConsumerWidget {
  const StatsSummaryBar({super.key});

  static const barKey = Key('stats_summary_bar');
  static const scrubKey = Key('stats_scrub_readout');
  static const clearKey = Key('stats_scrub_clear');

  /// 해제 버튼이 차지하는 폭. 스크럽 표시가 여기까지 밀고 들어오면 겹친다.
  static const double clearWidth = 32;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceId = ref.watch(currentDeviceIdProvider).valueOrNull;
    if (deviceId == null) return const SizedBox.shrink();

    final t = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;
    final ex = ref.watch(chartExtremesProvider).valueOrNull;
    final scrub = ref.watch(statsScrubProvider);
    final data = ref.watch(envChartDataProvider).valueOrNull;

    final showScrub = scrub != null && data != null;

    return Padding(
      key: barKey,
      padding: const EdgeInsets.symmetric(
          horizontal: EnvChart.outerPadding),
      child: Stack(
        children: [
          // 스크럽 중에도 자리는 지킨다 — 높이를 정하는 쪽이 이 위젯이다.
          Opacity(
            opacity: showScrub ? 0 : 1,
            child: Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: FigmaIcons.thermometer,
                    value: 'stats_axis_temp'.tr(
                      namedArgs: {'v': t?.tA?.toStringAsFixed(1) ?? '--'},
                    ),
                    extremes: 'stats_extremes_temp'.tr(namedArgs: {
                      'max': ex?.tempMax?.toStringAsFixed(1) ?? '--',
                      'min': ex?.tempMin?.toStringAsFixed(1) ?? '--',
                    }),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: FigmaIcons.waterDrop,
                    value: 'stats_axis_humid'.tr(
                      namedArgs: {'v': t?.hA?.toStringAsFixed(0) ?? '--'},
                    ),
                    extremes: 'stats_extremes_humid'.tr(namedArgs: {
                      'max': ex?.humidMax?.toStringAsFixed(0) ?? '--',
                      'min': ex?.humidMin?.toStringAsFixed(0) ?? '--',
                    }),
                  ),
                ),
              ],
            ),
          ),
          if (showScrub) ...[
            Positioned.fill(
              child: _ScrubReadout(
                key: scrubKey,
                data: data,
                x: scrub,
                metrics: ref.watch(statsMetricsProvider),
              ),
            ),
            // **나가는 문.** 스크럽 값이 요약 바를 덮으므로, 이 버튼이 없으면
            // 최고/최저로 돌아갈 방법이 사라진다.
            Positioned(
              key: clearKey,
              right: 0,
              top: 0,
              bottom: 0,
              child: _ClearScrubButton(
                onPressed: () =>
                    ref.read(statsScrubProvider.notifier).state = null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 스크러버가 가리키는 시점의 값 (Figma §3.1 "스크러버 툴팁").
///
/// **손가락을 따라 좌우로 움직인다** — 화면 가운데 고정해두면 어느 시점을
/// 읽고 있는지가 끊긴다. 플롯 좌표를 되짚어야 해서 [EnvChart.plotInset]을
/// 빌려온다.
class _ScrubReadout extends StatelessWidget {
  const _ScrubReadout({
    super.key,
    required this.data,
    required this.x,
    required this.metrics,
  });

  final EnvChartData data;
  final double x;
  final Set<StatsMetric> metrics;

  /// Figma `Frame 10` 폭.
  static const double _width = 159;

  /// 요약 바 여백과 플롯 시작점의 차이. 이만큼 안으로 들어가야 플롯 x와 맞는다.
  static const double _delta =
      EnvChart.plotInset - EnvChart.outerPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = data.timeAt(x);
    final isAm = at.hour < 12;
    final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;

    final temp =
        metrics.contains(StatsMetric.temperature) ? data.tempAt(x) : null;
    final humid =
        metrics.contains(StatsMetric.humidity) ? data.humidAt(x) : null;

    return LayoutBuilder(
      builder: (context, c) {
        final plotWidth = (c.maxWidth - _delta * 2).clamp(0.0, c.maxWidth);
        // 오른쪽 끝은 해제 버튼 자리를 비워둔다 — 겹치면 버튼을 못 누른다.
        final limit = (c.maxWidth - _width - StatsSummaryBar.clearWidth)
            .clamp(0.0, double.infinity);
        final left = (_delta + x * plotWidth - _width / 2).clamp(0.0, limit);

        return Stack(
          children: [
            Positioned(
              left: left,
              top: 0,
              bottom: 0,
              width: _width,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    (isAm ? 'stats_scrub_time_am' : 'stats_scrub_time_pm').tr(
                      namedArgs: {
                        'h': '$h12',
                        'm': at.minute.toString().padLeft(2, '0'),
                      },
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (temp != null)
                          _ScrubValue(
                            icon: FigmaIcons.thermometer,
                            text: 'stats_axis_temp'.tr(
                              namedArgs: {'v': temp.toStringAsFixed(0)},
                            ),
                          ),
                        if (temp != null && humid != null)
                          const SizedBox(width: AppStyles.spacing8),
                        if (humid != null)
                          _ScrubValue(
                            icon: FigmaIcons.waterDrop,
                            text: 'stats_axis_humid'.tr(
                              namedArgs: {'v': humid.toStringAsFixed(0)},
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScrubValue extends StatelessWidget {
  const _ScrubValue({required this.icon, required this.text});

  /// Figma SVG 파일명. 색은 파일이 갖고 있다.
  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FigmaIcon.metric(icon, size: _iconSize),
        const SizedBox(width: AppStyles.spacing4),
        Text(text, style: metricValueStyle(context)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.value,
    required this.extremes,
  });

  /// Figma SVG 파일명. 온도 `#ff3752`·습도 `#68a7f6`은 **파일이 가진 색**을
  /// 그대로 쓴다 — 디자인이 지정한 의미색이라 앱이 다시 칠하지 않는다.
  final String icon;
  final String value;
  final String extremes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FigmaIcon.metric(icon, size: _iconSize),
            const SizedBox(width: AppStyles.spacing4),
            // 좌우 2분할이라 한 칸이 화면의 절반뿐이다. 큰 글씨 설정이나
            // 자릿수가 늘면 바로 넘치므로, 잘라내는 대신 비율을 유지해 줄인다
            // — 숫자는 ellipsis로 자르면 값이 달라 보인다.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(value, style: metricValueStyle(context)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppStyles.spacing4),
        Text(
          extremes,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.bodySecondary(Theme.of(context).brightness),
              ),
        ),
      ],
    );
  }
}

/// 지표 값 글자(Figma: Pretendard SemiBold 20 `#1e1e1e`).
///
/// `AppStyles.subsectionTitle`은 `titleMedium`(16)에 기대는데 Figma는 20이다.
/// 숫자가 이 화면의 주인공이라 크기를 명시한다.
TextStyle? metricValueStyle(BuildContext context) =>
    Theme.of(context).textTheme.titleMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );

/// Figma 지표 아이콘 크기(24×24).
const double _iconSize = 24;

/// 스크럽 해제 버튼.
///
/// Figma에는 없다 — 디자인은 스크럽 **중인 한 장면**만 그렸고 거기서 어떻게
/// 빠져나오는지는 다루지 않았다. 값을 남기기로 한 이상 없으면 갇힌다.
class _ClearScrubButton extends StatelessWidget {
  const _ClearScrubButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'stats_scrub_clear'.tr(),
      child: InkResponse(
        onTap: onPressed,
        radius: 20,
        child: SizedBox(
          width: StatsSummaryBar.clearWidth,
          child: Center(
            child: Icon(
              Icons.close,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              semanticLabel: 'stats_scrub_clear'.tr(),
            ),
          ),
        ),
      ),
    );
  }
}
