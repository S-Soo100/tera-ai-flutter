import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/actuator_marker.dart';
import '../../domain/chart_time_axis.dart';
import '../../domain/env_chart_series.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/night_band.dart';
import '../home_control_providers.dart';

/// 최근 24시간 온·습도 차트.
///
/// **밤 띠가 이 화면의 시그니처다.** `22:00~06:00`(기획안 §3.1 ②, 활동 집계 창)을
/// 배경에 깔아, 사용자가 "그래프의 어디가 우리 애가 사는 시간인지"를 읽지 않고
/// 알아보게 한다. 야행성 개체를 다루는 이 앱에서만 의미를 갖는 표시다.
///
/// 카드에 담지 않고 폭 전체를 쓴다 — 온·습도 두 선의 **관계**가 읽혀야 통계 탭으로
/// 넘어갈 이유가 생기는데, 좁고 낮은 카드 안에서는 형태가 뭉개진다.
///
/// 라인은 `telemetry_30m`, 마커는 `commands`. **0값은 센서 오프라인 센티넬이라
/// 반드시 필터**한다 — 안 걸면 Y축이 0까지 늘어나 곡선이 납작해진다.
class EnvMiniChart extends ConsumerWidget {
  const EnvMiniChart({super.key});

  static const chartKey = Key('env_mini_chart');

  /// 플롯 높이. 64px에서는 두 선이 겹쳐 형태가 안 읽혔다.
  static const double _plotHeight = 132;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buckets = ref.watch(chartBucketsProvider).valueOrNull ?? const [];
    final markers = ref.watch(actuatorMarkersProvider).valueOrNull ?? const [];

    // 마커·밤 띠·시간축은 차트 요청 구간이 아니라 **실제 데이터 구간**을 써야
    // 선과 같은 자리를 가리킨다 — Sparkline이 가진 데이터를 폭 100%로 늘려
    // 그리기 때문이다.
    final series = EnvChartSeries.from(buckets);
    final theme = Theme.of(context);

    return InkWell(
      key: chartKey,
      onTap: () => context.go('/stats'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
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
                if (series.hasLine) const Flexible(child: _NightLegend()),
              ],
            ),
            const SizedBox(height: AppStyles.spacing8),
            if (!series.hasLine)
              // 맨 텍스트 한 줄을 132px 한가운데 띄우면 화면이 고장난 것처럼
              // 보인다(실기기에서 화면 1/4이 빈칸이었다).
              EmptyState(
                title: 'home_chart_empty_title'.tr(),
                description: 'home_chart_empty_desc'.tr(),
              )
            else
              SizedBox(
                height: _plotHeight,
                child: Stack(
                  children: [
                    // 맨 아래 — 데이터 선을 절대 가리지 않는다.
                    _NightBands(start: series.from!, end: series.to!),
                    Sparkline(
                      data: series.temps,
                      lineColor: AppTheme.chartTemperature,
                      lineWidth: 2,
                    ),
                    Sparkline(
                      data: series.humids,
                      lineColor: AppTheme.chartHumidity,
                      lineWidth: 2,
                    ),
                    _MarkerRow(
                      markers: markers,
                      start: series.from!,
                      end: series.to!,
                    ),
                  ],
                ),
              ),
            if (series.hasLine)
              _TimeAxisRow(start: series.from!, end: series.to!),
            const SizedBox(height: AppStyles.spacing4),
            if (series.hasLine)
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppTheme.nightBand(theme.brightness),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: theme.dividerColor),
          ),
        ),
        const SizedBox(width: AppStyles.spacing4),
        Flexible(
          child: Text('home_chart_night'.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// 22:00~06:00 구간 배경.
class _NightBands extends StatelessWidget {
  const _NightBands({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  static const bandsKey = Key('env_mini_chart_night_bands');

  @override
  Widget build(BuildContext context) {
    final bands = nightBands(from: start, to: end);
    if (bands.isEmpty) return const SizedBox.shrink();
    final color = AppTheme.nightBand(Theme.of(context).brightness);

    return LayoutBuilder(
      key: bandsKey,
      builder: (context, c) => Stack(
        children: [
          for (final b in bands)
            Positioned(
              left: b.start * c.maxWidth,
              width: (b.end - b.start) * c.maxWidth,
              top: 0,
              bottom: 0,
              child: ColoredBox(color: color),
            ),
        ],
      ),
    );
  }
}

/// X축 6시간 눈금 라벨.
class _TimeAxisRow extends StatelessWidget {
  const _TimeAxisRow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  static const axisKey = Key('env_mini_chart_time_axis');

  static const double _labelWidth = 52;

  @override
  Widget build(BuildContext context) {
    final ticks = chartTimeTicks(from: start, to: end);
    if (ticks.isEmpty) return const SizedBox(height: 14);

    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return SizedBox(
      key: axisKey,
      height: 14,
      child: LayoutBuilder(
        builder: (context, c) {
          return Stack(
            children: [
              for (final t in ticks)
                Positioned(
                  left: (t.position * c.maxWidth - _labelWidth / 2).clamp(
                    0.0,
                    (c.maxWidth - _labelWidth).clamp(0.0, double.infinity),
                  ),
                  child: SizedBox(
                    width: _labelWidth,
                    child: Text(
                      (t.isAm ? 'home_chart_time_am' : 'home_chart_time_pm')
                          .tr(namedArgs: {'h': '${t.hour12}'}),
                      textAlign: TextAlign.center,
                      style: style,
                      maxLines: 1,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.markers,
    required this.start,
    required this.end,
  });

  final List<ActuatorMarker> markers;
  final DateTime start;
  final DateTime end;

  static const _icon = {
    MarkerKind.mist: Icons.water_drop,
    MarkerKind.fan: Icons.mode_fan_off,
    MarkerKind.heater: Icons.local_fire_department,
    MarkerKind.led: Icons.lightbulb,
  };

  @override
  Widget build(BuildContext context) {
    // 마커는 "언제 돌았나"만 알려주면 된다. 기기마다 색을 주면 온·습도 선과
    // 색이 경쟁해 정작 읽어야 할 곡선이 묻힌다 — 무채색으로 억제한다.
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            for (final m in markers)
              if (m.positionIn(start: start, end: end) case final p?)
                Positioned(
                  left: (p * c.maxWidth).clamp(0.0, c.maxWidth - 10),
                  bottom: 0,
                  child: Icon(_icon[m.kind], size: 11, color: color),
                ),
          ],
        );
      },
    );
  }
}
