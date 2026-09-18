import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/axis_bounds.dart';
import '../../../../shared/domain/num_format.dart';
import '../../../../shared/domain/week_range.dart';
import '../../../../shared/domain/week_bar_role.dart';
import '../../../../shared/widgets/figma_icon.dart';

/// 온습도 상세 **주간 범위 바 차트** 섹션 (Figma 1081:5052) — 온도·습도가 같은
/// 위젯을 두 번 쓴다(강조색·아이콘·표기만 다르다).
///
/// 헤더는 **주간 전체** 최고/최저. 강조 바([accent])는 Figma 원안대로
/// **주간 최고값이 나온 요일**에 상시 표시하고, 그 막대의 위·아래 수치는
/// [valueColor]로 같이 강조한다(2026-09-16 원본 재확인). 요일 라벨은 강조하지
/// 않는다. 데이터 없는 요일은 바를 그리지 않는다 — 요일 라벨만 남긴다.
///
/// 치수(원본 369×256 실측): 가로 격자 8줄(32 간격, 맨 위는 최고값 라벨 여유선)
/// + 열 경계 세로선, Y 라벨은 눈금선에 아래 정렬(x+2), 요일은 열 왼쪽 +4,
/// 막대 10×r5, 막대 수치 14/500은 막대와 4 간격.
class WeekRangeChart extends StatelessWidget {
  const WeekRangeChart({
    super.key,
    required this.rows,
    required this.accent,
    this.valueColor,
    required this.iconAsset,
    required this.headerFormat,
    required this.axisFormat,
  });

  /// 월~일 7칸 고정 ([weekTempRanges]/[weekHumidRanges] 반환 그대로).
  final List<DayMinMax> rows;

  /// 최고값 막대 색 (온도 `tempAccent`, 습도 `humidAccent`).
  final Color accent;

  /// 헤더 최고값·최고 막대 수치 색. null이면 [accent].
  final Color? valueColor;

  /// 헤더 28pt 아이콘 — 원본 복합색 SVG를 그대로 그린다([FigmaIcon.metric]).
  final String iconAsset;

  /// 헤더 수치 표기 — 예: `32.5°C` / `59%`.
  final String Function(double) headerFormat;

  /// 우측 Y축 눈금 표기 — 예: `18°` / `42%`.
  final String Function(double, int decimals) axisFormat;

  // ── 치수 (Figma 1081:5052 실측) ──
  static const double chartHeight = 256;
  static const double rowStep = 32;
  static const int divisions = 6; // 눈금 7개
  static const double gridTop = rowStep; // y=0은 최고값 라벨 여유선
  static const double gridBottom = rowStep * (divisions + 1); // 224
  static const double gridSpan = gridBottom - gridTop; // 192
  static const double weekdayTop = 234;
  static const double barWidth = 10;
  static const double yLabelWidth = 28;
  static const double valueLabelHeight = 17;
  static const double valueLabelGap = 4;

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

  @override
  Widget build(BuildContext context) {
    // 도메인이 7칸을 보장하지만([weekTempRanges]), 어긋난 목록으로 아래
    // 인덱싱이 터지는 것보다 안 그리는 편이 낫다.
    if (rows.length != 7) return const SizedBox.shrink();

    final glass = context.glass;
    final axis = AxisBounds.forValues(
      [
        for (final r in rows) ...[
          if (r.min case final v?) v,
          if (r.max case final v?) v,
        ],
      ],
      divisions: divisions,
    );
    final roles = classifyWeekBars(rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(glass),
        const SizedBox(height: 8),
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
          _chart(glass, axis, roles),
      ],
    );
  }

  Widget _header(GlassPalette glass) {
    final v = _headerValues;
    return Row(
      children: [
        FigmaIcon.metric(iconAsset, size: 28),
        const SizedBox(width: 8),
        // Flexible + ellipsis — 값이 길어져도(소수·넓은 단위) 헤더 Row가
        // 옆으로 터지지 않게.
        Flexible(
          child: Text(
            v == null ? '--' : headerFormat(v.max),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 28,
              height: 33 / 28,
              fontWeight: FontWeight.w600,
              letterSpacing: 28 * -0.02,
              color: valueColor ?? accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            v == null ? '--' : headerFormat(v.min),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 28,
              height: 33 / 28,
              fontWeight: FontWeight.w600,
              letterSpacing: 28 * -0.02,
              color: glass.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  static TextStyle _axisStyle(GlassPalette glass) => TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 12,
        height: 14.3203125 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.24,
        color: glass.deviceOff, // Figma #B4AEAE — 일간 차트 축과 같은 역할색
      );

  /// 값 → 격자 구간 픽셀 y.
  double _y(AxisBounds axis, double v) =>
      gridTop + (1 - axis.normalize(v)) * gridSpan;

  Widget _chart(GlassPalette glass, AxisBounds axis, List<WeekBarRole> roles) {
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
                    _bar(glass, axis, i, c.maxWidth, roles),
                  for (var i = 0; i < 7; i++)
                    Positioned(
                      left: i * (c.maxWidth / 7) + 4,
                      top: weekdayTop,
                      child: Text(
                        // DayMinMax.day는 자정 정규화 로컬 날짜 — weekday 1=월.
                        'home_weekday_${rows[i].day.weekday}'.tr(),
                        style: _axisStyle(glass),
                      ),
                    ),
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
    List<WeekBarRole> roles,
  ) {
    final r = rows[i];
    final hi = r.max;
    final lo = r.min;
    if (hi == null || lo == null) return const SizedBox.shrink();

    final columnWidth = width / 7;
    final top = _y(axis, hi);
    final bottom = _y(axis, lo);
    // min == max인 날도 캡슐 하나는 보이게 최소 높이를 준다.
    final h = (bottom - top).clamp(barWidth, double.infinity);
    final isMax = roles[i] == WeekBarRole.maximum;
    final color = switch (roles[i]) {
      WeekBarRole.maximum => accent,
      WeekBarRole.minimum => glass.envBarMinimum,
      _ => glass.envBarNeutral,
    };
    final valueStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 14,
      height: valueLabelHeight / 14,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.28,
      color: isMax ? (valueColor ?? accent) : glass.bodySecondary,
    );

    return Positioned(
      left: i * columnWidth,
      top: 0,
      bottom: 0,
      width: columnWidth,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: top - valueLabelGap - valueLabelHeight,
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
            top: top + h + valueLabelGap,
            child: Text(formatCompact(lo), style: valueStyle),
          ),
        ],
      ),
    );
  }

  Widget _axisLabels(GlassPalette glass, AxisBounds axis) {
    final ticks = axis.ticks.reversed.toList(); // 위 → 아래
    final style = _axisStyle(glass);
    return SizedBox(
      width: yLabelWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < ticks.length; i++)
            Positioned(
              // 라벨 아래선이 눈금선에 닿는다(원본 y277+32k, 글상자 14).
              top: gridTop + i * rowStep - 14.3203125,
              left: 2,
              child: Text(axisFormat(ticks[i], axis.decimals), style: style),
            ),
        ],
      ),
    );
  }
}

/// 연한 격자 — 가로선은 여유선 포함 8줄, 세로선은 열 경계(양 끝 포함).
///
/// 원본은 세로선 두 열만 점선으로 그렸다(1081:5052의 목·금 경계). 나머지는
/// 실선이라 규칙을 실선으로 통일한다.
class _WeekGridPainter extends CustomPainter {
  const _WeekGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (var i = 0; i <= WeekRangeChart.divisions + 1; i++) {
      final y = i * WeekRangeChart.rowStep;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
    final columnWidth = size.width / 7;
    for (var i = 0; i <= 7; i++) {
      final x = (i * columnWidth).clamp(0.5, size.width - 0.5);
      canvas.drawLine(Offset(x, 0), Offset(x, WeekRangeChart.gridBottom), p);
    }
  }

  @override
  bool shouldRepaint(_WeekGridPainter old) => old.color != color;
}
