import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';
import '../../core/theme/app_theme.dart';
import '../domain/chart_window.dart';
import '../domain/env_extremes.dart';
import 'env_chart.dart';
import 'figma_icon.dart';

/// 온습도 차트 위에 붙는 요약 (Figma §3.1 상단 리드아웃).
///
/// 좌우 2분할로 온도·습도를 대칭 배치하고, 각 아래에 **차트와 같은 구간의**
/// 최고/최저를 붙인다. 이 숫자는 바로 아래 그래프를 설명하는 값이라, 다른 창을
/// 쓰면 서로 어긋난다.
///
/// **홈·통계가 같은 위젯을 쓴다.** provider를 직접 읽지 않고 값만 받는다 —
/// 공용 위젯이 특정 화면의 provider에 묶이면 다른 화면에서 못 쓰고, `shared`가
/// feature를 참조해 순환이 생긴다.
///
/// [scrubX]와 [scrubAt]이 함께 주어지면 그 자리가 **스크럽 값으로 바뀐다**
/// (Figma 변형 B). 스크럽을 안 쓰는 화면(홈)은 그냥 비워두면 된다.
class EnvSummaryBar extends StatelessWidget {
  const EnvSummaryBar({
    super.key,
    required this.temperature,
    required this.humidity,
    this.extremes,
    this.scrubX,
    this.scrubAt,
    this.scrubTemperature,
    this.scrubHumidity,
    this.scrubFormat = ChartTickFormat.hour,
    this.onClearScrub,
    this.extremesTempKey = 'stats_extremes_temp',
    this.extremesHumidKey = 'stats_extremes_humid',
  });

  /// 현재값. null이면 `--`.
  final double? temperature;
  final double? humidity;

  /// 차트 구간의 최고/최저. null이면 `--`.
  final EnvExtremes? extremes;

  /// 스크러버 위치(0~1). [scrubAt]과 **함께** 있어야 스크럽 표시가 뜬다.
  final double? scrubX;

  /// 스크러버가 가리키는 시각.
  final DateTime? scrubAt;

  /// 그 시각의 값. 꺼진 지표는 null로 넘기면 표시에서 빠진다.
  final double? scrubTemperature;
  final double? scrubHumidity;

  /// 스크럽 시각을 어떻게 읽을지. 차트 X축([ChartWindow.format])과 **같은
  /// 값**을 물린다 — 주간(포인트 = 1일)에서 시:분을 띄우면 전부 "오전 7:00"
  /// 이라 어느 날인지 알 수 없다. 날짜(`8/6`)로 읽어야 한다.
  final ChartTickFormat scrubFormat;

  /// 스크럽 해제. null이면 해제 버튼을 안 그린다.
  final VoidCallback? onClearScrub;

  /// 최고/최저 라벨의 l10n 키({max}/{min} 자리). 기본은 기간 표기가 없는
  /// 일간용이다 — 주간 화면은 "7일 최고…"처럼 **기간을 명시한 키**를 물린다.
  /// 현재값 옆에 "7일"이 붙으면 극값은 기간 값, 큰 숫자는 실시간임이 갈린다.
  final String extremesTempKey;
  final String extremesHumidKey;

  static const barKey = Key('env_summary_bar');
  static const scrubKey = Key('env_summary_scrub');
  static const clearKey = Key('env_summary_scrub_clear');

  /// 해제 버튼이 차지하는 폭. 스크럽 표시가 여기까지 밀고 들어오면 겹친다.
  static const double clearWidth = 32;

  @override
  Widget build(BuildContext context) {
    final showScrub = scrubX != null && scrubAt != null;

    return Padding(
      key: barKey,
      padding: const EdgeInsets.symmetric(horizontal: EnvChart.outerPadding),
      child: Stack(
        children: [
          // 스크럽 중에도 자리는 지킨다 — 높이를 정하는 쪽이 이 위젯이다.
          // 손을 댈 때마다 아래 차트가 위아래로 튀면 읽을 수가 없다.
          Opacity(
            opacity: showScrub ? 0 : 1,
            child: Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: FigmaIcons.thermometer,
                    value: 'stats_axis_temp'.tr(
                      namedArgs: {'v': temperature?.toStringAsFixed(1) ?? '--'},
                    ),
                    extremes: extremesTempKey.tr(namedArgs: {
                      'max': extremes?.tempMax?.toStringAsFixed(1) ?? '--',
                      'min': extremes?.tempMin?.toStringAsFixed(1) ?? '--',
                    }),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    icon: FigmaIcons.waterDrop,
                    value: 'stats_axis_humid'.tr(
                      namedArgs: {'v': humidity?.toStringAsFixed(0) ?? '--'},
                    ),
                    extremes: extremesHumidKey.tr(namedArgs: {
                      'max': extremes?.humidMax?.toStringAsFixed(0) ?? '--',
                      'min': extremes?.humidMin?.toStringAsFixed(0) ?? '--',
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
                x: scrubX!,
                at: scrubAt!,
                temperature: scrubTemperature,
                humidity: scrubHumidity,
                format: scrubFormat,
                reserveRight: onClearScrub == null ? 0 : clearWidth,
              ),
            ),
            // **나가는 문.** 스크럽 값이 요약을 덮으므로, 이 버튼이 없으면
            // 최고/최저로 돌아갈 방법이 사라진다.
            if (onClearScrub case final clear?)
              Positioned(
                key: clearKey,
                right: 0,
                top: 0,
                bottom: 0,
                child: _ClearScrubButton(onPressed: clear),
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
/// 읽고 있는지가 끊긴다. 플롯 좌표를 되짚어야 해서 [EnvChart.plotInset]을 빌린다.
class _ScrubReadout extends StatelessWidget {
  const _ScrubReadout({
    super.key,
    required this.x,
    required this.at,
    required this.temperature,
    required this.humidity,
    required this.format,
    required this.reserveRight,
  });

  final double x;
  final DateTime at;
  final double? temperature;
  final double? humidity;

  /// 시각([ChartTickFormat.hour]) 또는 날짜([ChartTickFormat.date])로 읽는다.
  final ChartTickFormat format;

  /// 오른쪽에 비워둘 폭(해제 버튼 자리).
  final double reserveRight;

  /// Figma `Frame 10` 폭.
  static const double _width = 159;

  /// 요약 여백과 플롯 시작점의 차이. 이만큼 안으로 들어가야 플롯 x와 맞는다.
  static const double _delta = EnvChart.plotInset - EnvChart.outerPadding;

  /// 스크럽 시각 문구. 주간은 날짜, 일간은 오전/오후 시:분.
  String get _timeLabel {
    switch (format) {
      case ChartTickFormat.date:
        return 'stats_scrub_date'
            .tr(namedArgs: {'m': '${at.month}', 'd': '${at.day}'});
      case ChartTickFormat.hour:
        final isAm = at.hour < 12;
        final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
        return (isAm ? 'stats_scrub_time_am' : 'stats_scrub_time_pm').tr(
          namedArgs: {
            'h': '$h12',
            'm': at.minute.toString().padLeft(2, '0'),
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        final plotWidth = (c.maxWidth - _delta * 2).clamp(0.0, c.maxWidth);
        final limit =
            (c.maxWidth - _width - reserveRight).clamp(0.0, double.infinity);
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
                children: [
                  Text(
                    _timeLabel,
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
                        if (temperature case final v?)
                          _ScrubValue(
                            icon: FigmaIcons.thermometer,
                            text: 'stats_axis_temp'
                                .tr(namedArgs: {'v': v.toStringAsFixed(0)}),
                          ),
                        if (temperature != null && humidity != null)
                          const SizedBox(width: AppStyles.spacing8),
                        if (humidity case final v?)
                          _ScrubValue(
                            icon: FigmaIcons.waterDrop,
                            text: 'stats_axis_humid'
                                .tr(namedArgs: {'v': v.toStringAsFixed(0)}),
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
        const SizedBox.shrink(),
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
                color: AppTheme.bodySecondary,
              ),
        ),
      ],
    );
  }
}

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
          width: EnvSummaryBar.clearWidth,
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
