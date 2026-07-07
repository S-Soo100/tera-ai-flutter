import 'dart:math' as math;

import 'package:chart_sparkline/chart_sparkline.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_styles.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../domain/species_comfort.dart';
import '../../domain/telemetry_bucket.dart';
import '../../domain/telemetry_reading.dart';
import '../supabase_module_providers.dart';

/// 차트가 다루는 지표(온도/습도). 값 접근·목표범위·표기 자릿수를 캡슐화.
enum _Metric { temperature, humidity }

extension _MetricX on _Metric {
  bool get isTemp => this == _Metric.temperature;

  /// 30분 버킷의 평균값(온도=tAvg, 습도=hAvg).
  double? avg(TelemetryBucket b) =>
      isTemp ? b.tAvg : b.hAvg;

  /// 실시간 현재값(온도=tA, 습도=hA).
  double? current(TelemetryReading r) => isTemp ? r.tA : r.hA;

  double comfortLo(SpeciesComfort c) => isTemp ? c.tempMin : c.humidMin;
  double comfortHi(SpeciesComfort c) => isTemp ? c.tempMax : c.humidMax;

  int get fractionDigits => isTemp ? 1 : 0;

  /// classifyComfort margin — "조금 벗어남 vs 많이 벗어남" 경계(온도 1.5°C / 습도 10%RH).
  double get comfortMargin => isTemp ? 1.5 : 10;

  String get labelKey =>
      isTemp ? 'telemetry_chart_temp' : 'telemetry_chart_humidity';
  String get unitKey => isTemp
      ? 'telemetry_chart_temp_unit'
      : 'telemetry_chart_humidity_unit';

  /// 최고/최저 마커용 짧은 단위(°/%).
  String get shortUnit => isTemp ? '°' : '%';
  IconData get icon =>
      isTemp ? Icons.thermostat : Icons.water_drop_outlined;
}

/// 유효한 실측값인가 — null이 아니고 **양수**.
///
/// DHT22 등 온습도 센서는 사육장에서 0°C·0%를 낼 수 없다. telemetry_30m 의 0값은
/// 실측이 아니라 **센서 분리/오류 센티넬**(장비가 죽은 채 계속 업로드하면 0으로 집계됨).
/// 이를 실값으로 그리면 밴드 바닥이 0으로 끌려 곡선이 압착된다. 따라서 0 이하는
/// "누락"으로 보고 스파크라인에서 제외한다.
bool _validReading(double? v) => v != null && v > 0;

/// 사육장 온습도 추이 섹션 (telemetry_30m 기반, 30분 집계 장기 추이).
///
/// 통합 카드 셸의 세 번째 섹션으로 embedded 렌더링된다(패딩·타이포를 형제
/// 섹션과 맞춤). [currentDeviceProvider]로 device를 직접 watch하므로 파라미터
/// 불필요. device 없음/로딩 → 빈 위젯.
class TelemetryHistoryChart extends ConsumerWidget {
  const TelemetryHistoryChart({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final device = ref.watch(currentDeviceProvider).valueOrNull;
    if (device == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'telemetry_chart_title'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          const _RangeSelector(),
          const SizedBox(height: 16),
          _ChartArea(deviceId: device.id),
        ],
      ),
    );
  }
}

// ── 기간 세그먼트 셀렉터 (24시간/7일/30일) ────────────────────────────────────

class _RangeSelector extends ConsumerWidget {
  const _RangeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(telemetryRangeProvider);
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<TelemetryRange>(
        showSelectedIcon: false,
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        segments: TelemetryRange.values
            .map(
              (r) => ButtonSegment<TelemetryRange>(
                value: r,
                label: Text(r.labelKey.tr()),
              ),
            )
            .toList(),
        selected: {range},
        onSelectionChanged: (selection) {
          ref.read(telemetryRangeProvider.notifier).state = selection.first;
        },
      ),
    );
  }
}

// ── 차트 영역 (history + 안심존 + 실시간 현재값 소비) ─────────────────────────

class _ChartArea extends ConsumerWidget {
  const _ChartArea({required this.deviceId});

  final String deviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(telemetryHistoryProvider(deviceId));
    // 종 미설정/미지원이면 null → 초록 안심존 밴드 미표시(임의 목표값 금지).
    final comfort = ref.watch(currentSpeciesComfortProvider).valueOrNull;
    // 실시간 현재값(카드 헤더의 큰 숫자 + 이모지 판정용).
    final current = ref.watch(telemetryStreamProvider(deviceId)).valueOrNull;

    return historyAsync.when(
      loading: () => const _ChartSkeleton(),
      error: (_, __) => const _ChartError(),
      data: (buckets) {
        if (buckets.isEmpty) return const _ChartEmpty();
        return Column(
          children: [
            _SparkCard(
              metric: _Metric.temperature,
              buckets: buckets,
              comfort: comfort,
              current: current,
            ),
            const SizedBox(height: 16),
            _SparkCard(
              metric: _Metric.humidity,
              buckets: buckets,
              comfort: comfort,
              current: current,
            ),
            if (comfort == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'comfort_no_species'.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ── 지표 카드 (이모지 상태 + 큰 현재값 + 스파크라인 + 안심존 밴드) ────────────

/// 지표 1개(온도 또는 습도)를 "날씨앱처럼" 보여주는 카드.
///
/// 헤더: 아이콘 + 지표명 + (이모지 + 큰 현재값). 서브: 판정 문구 + 적정범위.
/// 본문: 매끈한 그라디언트 스파크라인 + 은은한 초록 안심존 밴드.
class _SparkCard extends StatelessWidget {
  const _SparkCard({
    required this.metric,
    required this.buckets,
    required this.comfort,
    required this.current,
  });

  final _Metric metric;
  final List<TelemetryBucket> buckets;
  final SpeciesComfort? comfort;
  final TelemetryReading? current;

  /// 주의(caution) 색 — 앱 공통 경고색(모듈 상태카드와 동일, 테마 토큰 미정의).
  static const _amber = Color(0xFFFF8F00);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final c = comfort;

    // ── 현재값 + 판정 ──
    final curVal = current != null ? metric.current(current!) : null;
    final hasValue = _validReading(curVal);
    final ComfortLevel? level = (c != null && hasValue)
        ? classifyComfort(
            curVal!,
            metric.comfortLo(c),
            metric.comfortHi(c),
            metric.comfortMargin,
          )
        : null;
    final verdict =
        level != null ? comfortVerdict(level, isTemp: metric.isTemp) : null;

    // verdict색: good→primary, caution→amber, danger→health.
    // 판정 불가(종 미설정 or 현재값 없음)면 중립색(온도 primary / 습도 secondary).
    final Color accent = level == null
        ? (metric.isTemp ? cs.primary : cs.secondary)
        : level.isGood
            ? cs.primary
            : level.isDanger
                ? AppStyles.healthColor
                : _amber;

    final unit = metric.unitKey.tr();
    final valueText = hasValue
        ? '${curVal!.toStringAsFixed(metric.fractionDigits)}$unit'
        : 'telemetry_value_none'.tr();
    final headerValue =
        verdict != null ? '${verdict.emoji} $valueText' : valueText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // 가장 밝은 표면 톤 + 얇은 테두리 — 흰 배경 위에서 무거워 보이지 않게.
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(metric.icon, size: 18, color: accent),
              const SizedBox(width: 4),
              Text(
                metric.labelKey.tr(),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                headerValue,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
            ],
          ),
          if (c != null) ...[
            const SizedBox(height: 2),
            Text(
              _subText(c, verdict),
              style: theme.textTheme.labelSmall?.copyWith(
                color: level == null ? cs.onSurfaceVariant : accent,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 74,
            // 폭 강제: Stack의 자식이 전부 Positioned이면 loose 폭 제약에서 0으로
            // 붕괴한다. width 고정으로 카드 폭 전체를 차지하게 한다.
            width: double.infinity,
            child: _Spark(
              metric: metric,
              buckets: buckets,
              comfort: c,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  /// 서브 문구: 판정 있으면 "딱 좋아요 · 적정 24~30°C", 없으면 "적정 24~30°C".
  String _subText(SpeciesComfort c, ({String emoji, String key})? verdict) {
    final unit = metric.unitKey.tr();
    final lo = '${metric.comfortLo(c).round()}';
    final hi = '${metric.comfortHi(c).round()}';
    if (verdict != null) {
      return 'comfort_card_verdict_range'.tr(namedArgs: {
        'verdict': verdict.key.tr(),
        'lo': lo,
        'hi': hi,
        'unit': unit,
      });
    }
    return 'comfort_card_range'.tr(namedArgs: {
      'lo': lo,
      'hi': hi,
      'unit': unit,
    });
  }
}

// ── 스파크라인 영역 (곡선 + 안심존 밴드) ─────────────────────────────────────

/// 64px 고정 영역에 그라디언트 스파크라인 + (안심존 있으면) 초록 밴드를 겹쳐 그린다.
///
/// 밴드는 [Sparkline]의 내부 y-매핑과 **동일한 공식**으로 픽셀 좌표를 계산해
/// Stack에 [Positioned]로 얹는다(min/max를 명시적으로 고정해 정렬을 보장).
class _Spark extends StatelessWidget {
  const _Spark({
    required this.metric,
    required this.buckets,
    required this.comfort,
    required this.color,
  });

  final _Metric metric;
  final List<TelemetryBucket> buckets;
  final SpeciesComfort? comfort;
  final Color color;

  /// Sparkline lineWidth(L). 밴드 정렬 공식의 L과 동일해야 한다.
  static const double _lineWidth = 2.5;

  /// 이 개수를 넘으면 청크 평균으로 다운샘플(매끈한 곡선 + 렌더 비용 절감).
  static const int _maxPoints = 56;
  static const int _targetPoints = 48;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // 1. 유효값만(null·0 이하 제외) 순서대로 추출.
    var values = <double>[
      for (final b in buckets)
        if (_validReading(metric.avg(b))) metric.avg(b)!,
    ];
    if (values.isEmpty) {
      return Center(
        child: Text(
          'telemetry_chart_empty'.tr(),
          style: theme.textTheme.labelSmall?.copyWith(color: cs.outline),
        ),
      );
    }

    // 2. 다운샘플(56개 초과 시 ~48개로).
    if (values.length > _maxPoints) {
      values = _downsample(values, _targetPoints);
    }

    // 3. min/max 프레이밍. 안심존이 있으면 밴드가 화면에 들어오도록 범위에 포함.
    final dataMin = values.reduce(math.min);
    final dataMax = values.reduce(math.max);
    final maxIdx = values.indexOf(dataMax);
    final minIdx = values.indexOf(dataMin);
    final c = comfort;
    final lo = c != null ? math.min(dataMin, metric.comfortLo(c)) : dataMin;
    final hi = c != null ? math.max(dataMax, metric.comfortHi(c)) : dataMax;
    var pad = (hi - lo) * 0.15;
    if (pad == 0) pad = 1; // 전 구간 동일값 → Y축 붕괴 방지.
    final sparkMin = lo - pad;
    final sparkMax = hi + pad;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final w = constraints.maxWidth;
        final n = values.length;
        // Sparkline 내부 매핑과 동일한 좌표 공식(min/max 고정이라 정확히 일치).
        double y(double v) =>
            (h - _lineWidth) *
                (1 - (v - sparkMin) / (sparkMax - sparkMin)) +
            _lineWidth / 2;
        double x(int i) => n <= 1
            ? w / 2
            : i * (w - _lineWidth) / (n - 1) + _lineWidth / 2;

        // 최고/최저 지점 마커(점 + 값) — 곡선 위 실제 좌표에 얹는다.
        List<Widget> extreme(int idx, double val, {required bool above}) {
          final cx = x(idx);
          final cy = y(val);
          return [
            Positioned(
              left: cx - 3,
              top: cy - 3,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: cs.surfaceContainerLowest, width: 1),
                ),
              ),
            ),
            Positioned(
              left: (cx - 20).clamp(0.0, math.max(0.0, w - 40)),
              top: above
                  ? (cy - 15).clamp(0.0, h - 13)
                  : (cy + 5).clamp(0.0, h - 13),
              width: 40,
              child: Text(
                '${val.round()}${metric.shortUnit}',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ];
        }

        return Stack(
          children: [
            if (c != null)
              Positioned(
                left: 0,
                right: 0,
                top: y(metric.comfortHi(c)),
                height: y(metric.comfortLo(c)) - y(metric.comfortHi(c)),
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            Positioned.fill(
              child: Sparkline(
                data: values,
                min: sparkMin,
                max: sparkMax,
                lineWidth: _lineWidth,
                lineColor: color,
                useCubicSmoothing: true,
                cubicSmoothingFactor: 0.2,
                fillMode: FillMode.below,
                fillGradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.25),
                    color.withValues(alpha: 0.02),
                  ],
                ),
                pointsMode: PointsMode.none,
                gridLinesEnable: false,
              ),
            ),
            ...extreme(maxIdx, dataMax, above: true),
            if (minIdx != maxIdx) ...extreme(minIdx, dataMin, above: false),
          ],
        );
      },
    );
  }

  /// [src]를 균등 청크로 나눠 각 청크 평균을 내 최대 [target]개로 축약한다.
  /// 곡선 형태(추이)는 보존하면서 포인트 수만 줄인다.
  List<double> _downsample(List<double> src, int target) {
    final out = <double>[];
    final chunk = src.length / target;
    for (var i = 0; i < target; i++) {
      final start = (i * chunk).floor();
      final end = math.min(src.length, ((i + 1) * chunk).floor());
      if (end <= start) continue;
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += src[j];
      }
      out.add(sum / (end - start));
    }
    return out;
  }
}

// ── 로딩 스켈레톤 (CPI 금지 → shimmer) ────────────────────────────────────────

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoading(width: double.infinity, height: 148, borderRadius: 16),
        SizedBox(height: 16),
        SkeletonLoading(width: double.infinity, height: 148, borderRadius: 16),
      ],
    );
  }
}

// ── 에러 ──────────────────────────────────────────────────────────────────────

class _ChartError extends StatelessWidget {
  const _ChartError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Text(
          'error_generic'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── 빈 상태 ────────────────────────────────────────────────────────────────────

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.show_chart_rounded,
              size: 30,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              'telemetry_chart_empty'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
