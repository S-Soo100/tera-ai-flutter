import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/domain/actuator_marker.dart';
import '../../../shared/domain/chart_window.dart';
import '../../../shared/domain/env_chart_data.dart';
import '../../../shared/domain/env_extremes.dart';
import '../../../shared/widgets/env_chart.dart';
import '../../../shared/widgets/env_summary_bar.dart';
import '../../my_cage/domain/telemetry_bucket.dart';
import 'chart_lab_fixtures.dart';

/// 온습도 그래프 디자인 검토용 화면.
///
/// **실데이터로는 볼 수 없는 상태를 만들어 본다.** 실기기에서는 지금 사육장이
/// 내놓는 한 가지 모양만 보이고, 마커가 없거나 밴드가 5분치인 날은 그 부분을
/// 아예 확인할 수 없다(실제로 그래서 마커를 실기기에서 못 봤다).
///
/// 값을 넣는 자리는 여기 하나뿐이고, 그림은 **실제 위젯**([EnvChart],
/// [EnvSummaryBar])을 그대로 쓴다 — 검토용으로 따로 그린 그림은 진짜 화면과
/// 어긋나서 아무것도 보증하지 못한다.
class ChartLabScreen extends StatefulWidget {
  const ChartLabScreen({super.key});

  static const screenKey = Key('chart_lab_screen');

  @override
  State<ChartLabScreen> createState() => _ChartLabScreenState();
}

class _ChartLabScreenState extends State<ChartLabScreen> {
  ChartShape _shape = ChartShape.daily;

  /// 창 끝까지 남은 시간(분). 회색 밴드 폭을 정한다.
  ///
  /// **0~6시간이 실제로 가능한 전부다.** 창이 6시간마다 전진하므로 밴드는
  /// 0~25% 사이에서만 움직인다 — 그보다 넓은 상태를 보여주면 있지도 않은
  /// 화면을 놓고 디자인하게 된다.
  double _minutesLeft = 200;

  bool _nightBand = false;
  bool _markers = true;
  bool _scrubbable = true;
  bool _showTemp = true;
  bool _showHumid = true;
  double? _scrubX;

  /// 창 끝을 고정해 화면을 다시 열어도 같은 그림이 나오게 한다.
  static final _end = DateTime(2026, 8, 10, 22);

  ChartWindow get _window =>
      ChartWindow.of(_end.subtract(Duration(minutes: _minutesLeft.round())));

  @override
  Widget build(BuildContext context) {
    final w = _window;
    final buckets = buildLabBuckets(shape: _shape, window: w);
    final data = EnvChartData.from(buckets, from: w.start, to: w.end);
    final extremes = EnvExtremes.from(buckets);
    final markers = _markers ? buildLabMarkers(w) : const <ActuatorMarker>[];

    final scrubX = _scrubbable ? _scrubX : null;
    final showScrub = scrubX != null && data.hasData;

    return Scaffold(
      key: ChartLabScreen.screenKey,
      appBar: AppBar(title: Text('dev_chart_lab_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppStyles.spacing32),
        children: [
          const SizedBox(height: AppStyles.spacing8),
          EnvSummaryBar(
            temperature: data.hasData ? _latest(buckets, temp: true) : null,
            humidity: data.hasData ? _latest(buckets, temp: false) : null,
            extremes: extremes,
            scrubX: showScrub ? scrubX : null,
            scrubAt: showScrub ? data.timeAt(scrubX) : null,
            scrubTemperature:
                showScrub && _showTemp ? data.tempAt(scrubX) : null,
            scrubHumidity:
                showScrub && _showHumid ? data.humidAt(scrubX) : null,
            onClearScrub: () => setState(() => _scrubX = null),
          ),
          const SizedBox(height: AppStyles.spacing16),
          if (data.hasData)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: EnvChart.outerPadding),
              child: EnvChart(
                data: data,
                window: w,
                markers: markers,
                nightBand: _nightBand,
                showTemperature: _showTemp,
                showHumidity: _showHumid,
                scrubX: scrubX,
                onScrubChanged:
                    _scrubbable ? (x) => setState(() => _scrubX = x) : null,
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: EnvChart.outerPadding),
              child: Text(
                'dev_chart_lab_no_data'.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          const SizedBox(height: AppStyles.spacing24),
          const Divider(),
          _Controls(
            shape: _shape,
            onShape: (v) => setState(() => _shape = v),
            minutesLeft: _minutesLeft,
            onMinutesLeft: (v) => setState(() => _minutesLeft = v),
            bandPercent: (1 - w.elapsed) * 100,
            nightBand: _nightBand,
            onNightBand: (v) => setState(() => _nightBand = v),
            markers: _markers,
            onMarkers: (v) => setState(() => _markers = v),
            scrubbable: _scrubbable,
            onScrubbable: (v) => setState(() {
              _scrubbable = v;
              if (!v) _scrubX = null;
            }),
            showTemp: _showTemp,
            onShowTemp: (v) => setState(() {
              // 둘 다 끄면 빈 격자만 남는다 — 마지막 하나는 못 끈다.
              if (v || _showHumid) _showTemp = v;
            }),
            showHumid: _showHumid,
            onShowHumid: (v) => setState(() {
              if (v || _showTemp) _showHumid = v;
            }),
          ),
        ],
      ),
    );
  }

  /// 요약 바의 "현재값"은 마지막 실측으로 대신한다.
  double? _latest(List<TelemetryBucket> buckets, {required bool temp}) {
    for (final b in buckets.reversed) {
      final v = temp ? b.tAvg : b.hAvg;
      if (v != null && v > 0) return v;
    }
    return null;
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.shape,
    required this.onShape,
    required this.minutesLeft,
    required this.onMinutesLeft,
    required this.bandPercent,
    required this.nightBand,
    required this.onNightBand,
    required this.markers,
    required this.onMarkers,
    required this.scrubbable,
    required this.onScrubbable,
    required this.showTemp,
    required this.onShowTemp,
    required this.showHumid,
    required this.onShowHumid,
  });

  final ChartShape shape;
  final ValueChanged<ChartShape> onShape;
  final double minutesLeft;
  final ValueChanged<double> onMinutesLeft;
  final double bandPercent;
  final bool nightBand;
  final ValueChanged<bool> onNightBand;
  final bool markers;
  final ValueChanged<bool> onMarkers;
  final bool scrubbable;
  final ValueChanged<bool> onScrubbable;
  final bool showTemp;
  final ValueChanged<bool> onShowTemp;
  final bool showHumid;
  final ValueChanged<bool> onShowHumid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppStyles.spacing8),
          Text('dev_chart_lab_shape'.tr(),
              style: AppStyles.subsectionTitle(context)),
          const SizedBox(height: AppStyles.spacing8),
          Wrap(
            spacing: AppStyles.spacing8,
            runSpacing: AppStyles.spacing8,
            children: [
              for (final s in ChartShape.values)
                ChoiceChip(
                  label: Text(s.labelKey.tr()),
                  selected: shape == s,
                  onSelected: (_) => onShape(s),
                ),
            ],
          ),
          const SizedBox(height: AppStyles.spacing16),
          Text(
            'dev_chart_lab_band'.tr(
              namedArgs: {'p': bandPercent.toStringAsFixed(0)},
            ),
            style: AppStyles.subsectionTitle(context),
          ),
          Text(
            'dev_chart_lab_band_desc'.tr(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Slider(
            value: minutesLeft,
            min: 1,
            max: 360,
            divisions: 72,
            label: 'dev_chart_lab_band'
                .tr(namedArgs: {'p': bandPercent.toStringAsFixed(0)}),
            onChanged: onMinutesLeft,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('dev_chart_lab_night'.tr()),
            subtitle: Text('dev_chart_lab_night_desc'.tr()),
            value: nightBand,
            onChanged: onNightBand,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('dev_chart_lab_markers'.tr()),
            value: markers,
            onChanged: onMarkers,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('dev_chart_lab_scrub'.tr()),
            subtitle: Text('dev_chart_lab_scrub_desc'.tr()),
            value: scrubbable,
            onChanged: onScrubbable,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('stats_metric_temp'.tr()),
            value: showTemp,
            onChanged: onShowTemp,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('stats_metric_humid'.tr()),
            value: showHumid,
            onChanged: onShowHumid,
          ),
          const SizedBox(height: AppStyles.spacing8),
          Text(
            'dev_chart_lab_theme_hint'.tr(),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
