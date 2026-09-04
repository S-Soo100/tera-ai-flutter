import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/axis_bounds.dart';
import '../../../../shared/domain/num_format.dart';
import '../../../../shared/domain/week_range.dart';

/// 온습도 상세 **주간 범위 바 차트** 섹션 (Figma §A.6) — 온도·습도가 같은
/// 위젯을 두 번 쓴다(강조색·아이콘·표기만 다르다).
///
/// 헤더는 **주간 전체** 최고/최저. 강조 바([accent])는 Figma 원안대로
/// **주간 최고값이 나온 요일**에 상시 표시한다(온도=빨강, 습도=파랑 —
/// 2026-09-04 사용자 정정). 구 터치 선택(탭한 요일 강조·헤더 전환)은 폐기.
/// 데이터 없는 요일은 바를 그리지 않는다 — 요일 라벨만 남긴다(7칸 축은
/// [DayMinMax] 목록이 이미 보장).
class WeekRangeChart extends StatelessWidget {
  const WeekRangeChart({
    super.key,
    required this.rows,
    required this.accent,
    required this.icon,
    required this.headerFormat,
    required this.axisFormat,
  });

  /// 월~일 7칸 고정 ([weekTempRanges]/[weekHumidRanges] 반환 그대로).
  final List<DayMinMax> rows;

  final Color accent;
  final IconData icon;

  /// 헤더 수치 표기 — 예: `32.5°C` / `59%`.
  final String Function(double) headerFormat;

  /// 우측 Y축 눈금 표기 — 예: `18°` / `42%`.
  final String Function(double, int decimals) axisFormat;

  // ── 치수 (Figma 369×297 근사) ──
  static const double chartHeight = 252;
  static const double gridTop = 18; // 최고값 라벨이 앉는 여백
  static const double gridBottom = chartHeight - 22; // 최저값 라벨 여백
  static const double gridSpan = gridBottom - gridTop;
  static const double barWidth = 8;
  static const double yLabelWidth = 40;

  /// 주간 전체 (max, min). 유효 표본이 없으면 null.
  ({double max, double min})? get _headerValues {
    double? hi;
    double? lo;
    for (final r in rows) {
      if (r.max != null && (hi == null || r.max! > hi)) hi = r.max;
      if (r.min != null && (lo == null || r.min! < lo)) lo = r.min;
    }
    if (hi == null || lo == null) return null;
    return (max: hi, min: lo);
  }

  /// 주간 최고값이 나온 요일 인덱스(0=월). 동률이면 먼저 온 요일.
  /// 유효 표본이 없으면 null — 강조 없음.
  int? get _peakIndex {
    int? idx;
    double? peak;
    for (var i = 0; i < rows.length; i++) {
      final m = rows[i].max;
      if (m != null && (peak == null || m > peak)) {
        peak = m;
        idx = i;
      }
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    // 도메인이 7칸을 보장하지만([weekTempRanges]), 어긋난 목록으로 아래
    // 인덱싱이 터지는 것보다 안 그리는 편이 낫다.
    if (rows.length != 7) return const SizedBox.shrink();

    final glass = context.glass;
    final axis = AxisBounds.forValues([
      for (final r in rows) ...[
        if (r.min case final v?) v,
        if (r.max case final v?) v,
      ],
    ]);
    final peakIndex = _peakIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(glass),
        const SizedBox(height: 12),
        if (axis == null)
          SizedBox(
            height: chartHeight,
            child: Center(
              child: Text(
                'env_detail_no_data'.tr(),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: glass.textTertiary,
                ),
              ),
            ),
          )
        else
          _chart(glass, axis, peakIndex),
        const SizedBox(height: 4),
        _weekdayRow(glass, peakIndex),
      ],
    );
  }

  Widget _header(GlassPalette glass) {
    final v = _headerValues;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: glass.deviceGlyph),
        ),
        const SizedBox(width: 10),
        // Flexible + ellipsis — 값이 길어져도(소수·넓은 단위) 헤더 Row가
        // 옆으로 터지지 않게.
        Flexible(
          child: Text(
            v == null ? '--' : headerFormat(v.max),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 22 * -0.02,
              color: accent,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            v == null ? '--' : headerFormat(v.min),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 20 * -0.02,
              color: glass.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  /// 값 → 격자 구간 픽셀 y.
  double _y(AxisBounds axis, double v) =>
      gridTop + (1 - axis.normalize(v)) * gridSpan;

  Widget _chart(GlassPalette glass, AxisBounds axis, int? peakIndex) {
    final valueStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: glass.textSecondary,
    );

    return SizedBox(
      height: chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WeekGridPainter(color: glass.chartGridLine),
                    ),
                  ),
                  for (var i = 0; i < 7; i++)
                    _bar(glass, axis, i, c.maxWidth, valueStyle, peakIndex),
                ],
              ),
            ),
          ),
          _axisLabels(glass, axis),
        ],
      ),
    );
  }

  Widget _bar(
    GlassPalette glass,
    AxisBounds axis,
    int i,
    double width,
    TextStyle valueStyle,
    int? peakIndex,
  ) {
    final r = rows[i];
    final hi = r.max;
    final lo = r.min;
    if (hi == null || lo == null) return const SizedBox.shrink();

    final centerX = (i + 0.5) * (width / 7);
    final top = _y(axis, hi);
    final bottom = _y(axis, lo);
    // min == max인 날도 캡슐 하나는 보이게 최소 높이를 준다.
    final h = (bottom - top).clamp(barWidth, double.infinity);
    final color = peakIndex == i ? accent : glass.textSecondary;

    return Positioned(
      left: centerX - width / 14,
      top: 0,
      bottom: 0,
      width: width / 7,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: top - 16,
            child: Text(formatCompact(hi), style: valueStyle),
          ),
          Positioned(
            top: top,
            child: Container(
              width: barWidth,
              height: h,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(barWidth / 2),
              ),
            ),
          ),
          Positioned(
            top: top + h + 4,
            child: Text(formatCompact(lo), style: valueStyle),
          ),
        ],
      ),
    );
  }

  Widget _axisLabels(GlassPalette glass, AxisBounds axis) {
    final ticks = axis.ticks.reversed.toList(); // 위 → 아래
    return SizedBox(
      width: yLabelWidth,
      child: Stack(
        children: [
          for (var i = 0; i < ticks.length; i++)
            Positioned(
              top: gridTop + i * (gridSpan / AxisBounds.divisions) - 7,
              right: 0,
              child: Text(
                axisFormat(ticks[i], axis.decimals),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: glass.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _weekdayRow(GlassPalette glass, int? peakIndex) {
    return Padding(
      padding: const EdgeInsets.only(right: yLabelWidth),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Center(
                child: Text(
                  // DayMinMax.day는 자정 정규화 로컬 날짜 — weekday 1=월.
                  'home_weekday_${rows[i].day.weekday}'.tr(),
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight:
                        peakIndex == i ? FontWeight.w700 : FontWeight.w500,
                    color: peakIndex == i ? accent : glass.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 연한 가로 격자 — Y 눈금 위치마다 한 줄.
class _WeekGridPainter extends CustomPainter {
  const _WeekGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (var i = 0; i <= AxisBounds.divisions; i++) {
      final y = WeekRangeChart.gridTop +
          i * (WeekRangeChart.gridSpan / AxisBounds.divisions);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_WeekGridPainter old) => old.color != color;
}
