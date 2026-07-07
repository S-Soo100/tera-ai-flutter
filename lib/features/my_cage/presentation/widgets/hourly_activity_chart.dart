import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// 하루(24시간, 1시간 버킷) 활동량을 막대로 보여주는 공용 그래프.
/// 홈 '활동량 분석 요약'과 크레캠 '간단 활동량'이 함께 쓴다.
///
/// - [hourlySeconds]: 길이 24. index 0 = [dayStartHour]시 ~ +1h
///   (bucketMotionSecondsByHour 반환값).
/// - 막대 높이는 최댓값 기준 정규화, 색은 활동 강도(진할수록 많음), **피크 시각**은
///   강조색. 무활동(0) 시각은 흐린 스텁으로 '적은 활동'과 구분한다.
/// - 전부 0이면 "활동 없음" 빈 상태를 같은 높이로 표시(레이아웃 안정).
/// - [activeHours]: 아직 도래하지 않은 시각(진행 중인 '오늘')을 무활동과 구분하기
///   위한 경과 시각 수. 지정 시 index >= activeHours 버킷은 '미래'로 아주 흐리게
///   표시한다. null(기본, 완결된 하루)이면 24칸 모두 실제 데이터.
class HourlyActivityChart extends StatelessWidget {
  const HourlyActivityChart({
    super.key,
    required this.hourlySeconds,
    this.dayStartHour = 7,
    this.height = 72,
    this.activeHours,
  });

  final List<int> hourlySeconds;
  final int dayStartHour;
  final double height;
  final int? activeHours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxVal =
        hourlySeconds.isEmpty ? 0 : hourlySeconds.reduce(math.max);

    if (maxVal <= 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'activity_chart_empty'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    final primary = theme.colorScheme.primary;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxH = constraints.maxHeight;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(hourlySeconds.length, (i) {
                  final v = hourlySeconds[i];
                  final isFuture = activeHours != null && i >= activeHours!;
                  final ratio = v / maxVal; // 0~1
                  final isPeak = !isFuture && v == maxVal;
                  final double h;
                  final Color color;
                  if (isFuture) {
                    // 아직 도래 안 한 시각 → 무활동(0.4)보다 더 흐린 2px '예정' 스텁.
                    h = 2.0;
                    color =
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.15);
                  } else if (v <= 0) {
                    // 0 → 흐린 스텁(3px)으로 무활동 표시.
                    h = 3.0;
                    color =
                        theme.colorScheme.outlineVariant.withValues(alpha: 0.4);
                  } else {
                    // >0 → 최소 6px 보장, 강도 비례 색, 피크는 강조색.
                    h = math.max(6.0, ratio * maxH);
                    color = isPeak
                        ? primary
                        : primary.withValues(alpha: 0.30 + 0.55 * ratio);
                  }
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Container(
                        height: h,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        _AxisLabels(dayStartHour: dayStartHour),
      ],
    );
  }
}

/// 하단 시각 눈금 — 하루 시작 기준 6시간 간격(07/13/19/01/07).
class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.dayStartHour});

  final int dayStartHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      fontSize: 10,
    );
    String hh(int offset) =>
        ((dayStartHour + offset) % 24).toString().padLeft(2, '0');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(hh(0), style: style),
        Text(hh(6), style: style),
        Text(hh(12), style: style),
        Text(hh(18), style: style),
        Text(hh(24), style: style),
      ],
    );
  }
}
