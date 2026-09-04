import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/am_pm_time.dart';
import '../../../../shared/domain/axis_bounds.dart';
import '../../../../shared/domain/control_log.dart';
import '../../../../shared/domain/env_chart_data.dart';
import '../../../../shared/domain/num_format.dart';
import 'control_log_list.dart';

/// 겹치는 마커 중심 x들을 **최소 [minGap] 간격**으로 벌린다 (계획서 §A.5).
///
/// [centers]는 오름차순 픽셀 좌표. 앞에서 뒤로 밀어 간격을 확보하고, 끝을
/// 넘치면 뒤에서 앞으로 되밀어 [max] 안에 담는다 — 한 방향만 밀면 마지막
/// 마커가 차트 밖으로 나간다. 되밀어도 안 담기면(마커가 폭보다 많으면) 겹침을
/// 허용한다 — Figma도 22px 간격 겹침을 허용했다.
List<double> resolveMarkerCenters(
  List<double> centers, {
  required double min,
  required double max,
  double minGap = 22,
}) {
  final out = List<double>.of(centers);
  for (var i = 0; i < out.length; i++) {
    out[i] = out[i].clamp(min, max);
    if (i > 0 && out[i] < out[i - 1] + minGap) {
      out[i] = out[i - 1] + minGap;
    }
  }
  for (var i = out.length - 1; i >= 0; i--) {
    if (out[i] > max) out[i] = max;
    if (i < out.length - 1 && out[i] > out[i + 1] - minGap) {
      out[i] = (out[i + 1] - minGap).clamp(min, max);
    }
  }
  return out;
}

/// 온습도 상세의 **일간 가로 스크롤 차트** (Figma §A.5, 콘텐츠 폭 524pt = 24h).
///
/// 홈·통계의 [EnvChart](393pt 프레임 고정)와 다른 물건이다 — 하루를 통째로
/// 담아 옆으로 넘겨 본다. Y축 라벨은 **스크롤 밖 고정 오버레이**(좌 온도·우
/// 습도, 흰 바닥 마스크)라 차트가 라벨 밑으로 흘러 들어간다(Figma Hide 구조).
///
/// 마커 행은 [ControlLogEntry]를 쓴다 — [ActuatorMarker]는 방향(on/off)이
/// 없어 꺼짐 마커를 [GlassPalette.deviceOff]로 못 칠한다.
class EnvDayChart extends StatefulWidget {
  const EnvDayChart({
    super.key,
    required this.data,
    this.log = const [],
    this.scrubX,
    this.onScrubChanged,
    this.initialFraction = 0,
  });

  final EnvChartData data;

  /// 마커 행 소스 (시간 오름차순 — buildControlLog 반환 그대로).
  final List<ControlLogEntry> log;

  /// 스크러버 위치(0~1). null이면 표시하지 않는다. 상태는 화면이 갖는다 —
  /// 날짜가 바뀌면 화면이 해제한다.
  final double? scrubX;
  final ValueChanged<double>? onScrubChanged;

  /// 초기 가로 스크롤 기준(0~1). 오늘이면 현재 시각 비율 — 현재가 뷰포트
  /// 우측에 오게 민다. 과거일은 0(자정부터).
  final double initialFraction;

  static const chartKey = Key('env_day_chart');

  // ── 치수 (계획서 §A.5) ──
  /// 콘텐츠 폭 = 24시간. 1시간 ≈ 21.8pt.
  static const double contentWidth = 524;

  /// 마커 행 높이 — 스크롤 콘텐츠에 포함(시각 x좌표 정렬).
  static const double markerBand = 32;
  static const double markerSize = 28;
  static const double markerMinGap = 22;

  /// Y 눈금은 항상 6개([AxisBounds.divisions]+1) — 격자 5칸.
  static const double rowStep = 36;
  static const double gridSpan = rowStep * AxisBounds.divisions; // 180
  static const double footroom = 8;
  static const double plotHeight = gridSpan + footroom; // 188

  static const double axisHeight = 20;
  static const double totalHeight = markerBand + plotHeight + axisHeight;

  /// 고정 Y축 라벨 컬럼 폭 (흰 바닥 마스크 포함).
  // "28.0°"(소수 축)가 12pt로 ~36px — 34면 왼쪽으로 흘러 잘린다.
  static const double yLabelWidth = 42;
  static const double labelHeight = 14;

  @override
  State<EnvDayChart> createState() => _EnvDayChartState();
}

class _EnvDayChartState extends State<EnvDayChart> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToInitial());
  }

  @override
  void didUpdateWidget(EnvDayChart old) {
    super.didUpdateWidget(old);
    // 날짜 페이징으로 창이 바뀌면 스크롤도 그 날 기준으로 다시 잡는다.
    if (old.data.from != widget.data.from) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToInitial());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 오늘이면 현재 시각이 뷰포트 우측에 오도록, 과거일은 0.
  void _jumpToInitial() {
    if (!mounted || !_controller.hasClients) return;
    final f = widget.initialFraction;
    if (f <= 0) {
      _controller.jumpTo(0);
      return;
    }
    final viewport = _controller.position.viewportDimension;
    final target = (EnvDayChart.yLabelWidth +
            f * EnvDayChart.contentWidth -
            (viewport - EnvDayChart.yLabelWidth))
        .clamp(0.0, _controller.position.maxScrollExtent);
    _controller.jumpTo(target);
  }

  void _scrubAt(Offset local) {
    final onScrub = widget.onScrubChanged;
    if (onScrub == null) return;
    final x = (local.dx / EnvDayChart.contentWidth).clamp(0.0, 1.0);
    // 곡선 위 값으로 스냅 — 원시 x를 쓰면 선과 점이 어긋난다(EnvChartData 규칙).
    onScrub(widget.data.snap(x) ?? x);
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final labelStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: glass.textTertiary,
    );

    return SizedBox(
      key: EnvDayChart.chartKey,
      height: EnvDayChart.totalHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: EnvDayChart.yLabelWidth),
              child: SizedBox(
                width: EnvDayChart.contentWidth,
                height: EnvDayChart.totalHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _scrubAt(d.localPosition),
                  onLongPressStart: (d) => _scrubAt(d.localPosition),
                  onLongPressMoveUpdate: (d) => _scrubAt(d.localPosition),
                  child: _content(glass, labelStyle),
                ),
              ),
            ),
          ),
          // Y축 라벨 — 스크롤 밖 고정 + 흰 바닥 마스크(Figma Hide 구조).
          _axisOverlay(
            glass: glass,
            left: true,
            axis: widget.data.tempAxis,
            format: (v, d) =>
                'stats_axis_temp'.tr(namedArgs: {'v': v.toStringAsFixed(d)}),
            style: labelStyle,
          ),
          _axisOverlay(
            glass: glass,
            left: false,
            axis: widget.data.humidAxis,
            format: (v, d) =>
                'stats_axis_humid'.tr(namedArgs: {'v': v.toStringAsFixed(d)}),
            style: labelStyle,
          ),
        ],
      ),
    );
  }

  Widget _content(GlassPalette glass, TextStyle labelStyle) {
    final scrubX = widget.scrubX;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: EnvDayChart.markerBand,
          left: 0,
          right: 0,
          height: EnvDayChart.plotHeight,
          child: CustomPaint(
            painter: _DayPlotPainter(
              tempPoints: widget.data.tempPoints,
              humidPoints: widget.data.humidPoints,
              tempColor: glass.tempAccent,
              humidColor: glass.humidAccent,
              gridColor: glass.chartGridLine,
              scrubX: scrubX,
              scrubTempY: scrubX == null
                  ? null
                  : widget.data.tempNormAt(scrubX),
              scrubHumidY: scrubX == null
                  ? null
                  : widget.data.humidNormAt(scrubX),
              scrubLineColor: glass.textSecondary,
              scrubDotFill: glass.overlay,
            ),
          ),
        ),
        // X축 눈금 — 자정 경계 4개 (오전 12시/6시/오후 12시/6시).
        Positioned(
          top: EnvDayChart.markerBand + EnvDayChart.plotHeight,
          left: 0,
          right: 0,
          height: EnvDayChart.axisHeight,
          child: Stack(
            children: [
              for (var i = 0; i < 4; i++)
                Positioned(
                  left: i / 4 * EnvDayChart.contentWidth,
                  top: 4,
                  child: Text(_hourLabel(i * 6), style: labelStyle),
                ),
            ],
          ),
        ),
        ..._markers(glass),
        if (scrubX != null) _tooltip(glass, scrubX),
      ],
    );
  }

  String _hourLabel(int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return (hour < 12 ? 'home_chart_time_am' : 'home_chart_time_pm')
        .tr(namedArgs: {'h': '$h12'});
  }

  /// 마커 행 — 동작 시각 x에 28×28 원. 겹치면 22pt 간격으로 벌린다.
  List<Widget> _markers(GlassPalette glass) {
    final span = widget.data.to.difference(widget.data.from).inMicroseconds;
    if (span <= 0) return const [];

    final spots = <({double x, ControlLogEntry e})>[];
    for (final e in widget.log) {
      final f = e.at.difference(widget.data.from).inMicroseconds / span;
      if (f < 0 || f > 1) continue;
      spots.add((x: f * EnvDayChart.contentWidth, e: e));
    }
    spots.sort((a, b) => a.x.compareTo(b.x));

    final centers = resolveMarkerCenters(
      [for (final s in spots) s.x],
      min: EnvDayChart.markerSize / 2,
      max: EnvDayChart.contentWidth - EnvDayChart.markerSize / 2,
      minGap: EnvDayChart.markerMinGap,
    );

    return [
      for (var i = 0; i < spots.length; i++)
        Positioned(
          left: centers[i] - EnvDayChart.markerSize / 2,
          top: 0,
          child: Tooltip(
            message:
                '${formatAmPmTime(spots[i].e.at)} ${controlKindNameKey(spots[i].e.kind).tr()}',
            triggerMode: TooltipTriggerMode.tap,
            child: Container(
              width: EnvDayChart.markerSize,
              height: EnvDayChart.markerSize,
              decoration: BoxDecoration(
                color: controlEntryColor(spots[i].e, glass),
                shape: BoxShape.circle,
              ),
              child: Icon(
                controlKindIcon(spots[i].e.kind),
                size: 15,
                color: glass.deviceGlyph,
              ),
            ),
          ),
        ),
    ];
  }

  /// 스크러버 툴팁 — `오전 11:23  35.2°C 59%`. 콘텐츠 좌표라 차트와 같이
  /// 스크롤된다(세로선과 붙어 다녀야 읽힌다).
  Widget _tooltip(GlassPalette glass, double scrubX) {
    final at = widget.data.timeAt(scrubX);
    final t = widget.data.tempAt(scrubX);
    final h = widget.data.humidAt(scrubX);
    final values = (t == null || h == null)
        ? null
        : 'env_detail_scrub_values'
            .tr(args: [formatCompact(t), formatCompact(h)]);

    final x = (scrubX * EnvDayChart.contentWidth).clamp(
      70.0,
      EnvDayChart.contentWidth - 70.0,
    );
    return Positioned(
      left: x,
      top: 0,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: glass.overlay,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: glass.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatAmPmTime(at),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: glass.textTertiary,
                ),
              ),
              if (values != null) ...[
                const SizedBox(width: 6),
                Text(
                  values,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: glass.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 고정 Y축 라벨 컬럼. 라벨 **중앙**이 격자선에 온다(EnvChart와 같은 규칙 —
  /// spaceBetween으로 흘리면 위아래 라벨이 반 칸 밀린다).
  Widget _axisOverlay({
    required GlassPalette glass,
    required bool left,
    required AxisBounds? axis,
    required String Function(double, int) format,
    required TextStyle style,
  }) {
    if (axis == null) return const SizedBox.shrink();
    final ticks = axis.ticks.reversed.toList(); // 위 → 아래

    return Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: EnvDayChart.markerBand,
      height: EnvDayChart.plotHeight,
      width: EnvDayChart.yLabelWidth,
      // 흰 바닥 마스크 — 차트가 라벨 밑으로 흐를 때 글자가 뭉개지지 않게.
      child: ColoredBox(
        color: glass.wallpaper,
        child: Stack(
          children: [
            for (var i = 0; i < ticks.length; i++)
              Positioned(
                top: i * EnvDayChart.rowStep - EnvDayChart.labelHeight / 2,
                left: left ? null : 2,
                right: left ? 2 : null,
                child: SizedBox(
                  height: EnvDayChart.labelHeight,
                  child: Text(
                    format(ticks[i], axis.decimals),
                    style: style,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 격자 + 온습도 라인 + 스크러버. **직접 그린다** — 524pt 스크롤 캔버스는
/// 프레임 고정 전제의 fl_chart 배선보다 좌표를 직접 잡는 편이 정확하다.
class _DayPlotPainter extends CustomPainter {
  const _DayPlotPainter({
    required this.tempPoints,
    required this.humidPoints,
    required this.tempColor,
    required this.humidColor,
    required this.gridColor,
    required this.scrubX,
    required this.scrubTempY,
    required this.scrubHumidY,
    required this.scrubLineColor,
    required this.scrubDotFill,
  });

  final List<({double x, double y})> tempPoints;
  final List<({double x, double y})> humidPoints;
  final Color tempColor;
  final Color humidColor;
  final Color gridColor;
  final double? scrubX;
  final double? scrubTempY;
  final double? scrubHumidY;
  final Color scrubLineColor;
  final Color scrubDotFill;

  /// 정규화 y(0~1) → 픽셀. 1이 첫 격자선(위), 0이 마지막 격자선.
  static double _dy(double norm) => (1 - norm) * EnvDayChart.gridSpan;

  @override
  void paint(Canvas canvas, Size size) {
    // 가로 격자선 — Y 눈금마다 한 줄 (연회색).
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..isAntiAlias = false;
    for (var i = 0; i <= AxisBounds.divisions; i++) {
      final y = i * EnvDayChart.rowStep;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    void drawLinePath(List<({double x, double y})> pts, Color color) {
      if (pts.length < 2) return; // 점 하나짜리 선은 보이지 않는다.
      final path = Path()
        ..moveTo(pts.first.x * size.width, _dy(pts.first.y));
      for (final p in pts.skip(1)) {
        path.lineTo(p.x * size.width, _dy(p.y));
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    drawLinePath(tempPoints, tempColor);
    drawLinePath(humidPoints, humidColor);

    // 스크러버 — 세로선은 플롯 전체, 점은 곡선 위 4pt.
    if (scrubX case final x?) {
      final dx = (x * size.width).clamp(0.0, size.width);
      canvas.drawLine(
        Offset(dx, 0),
        Offset(dx, size.height),
        Paint()
          ..color = scrubLineColor
          ..strokeWidth = 1,
      );
      final fill = Paint()..color = scrubDotFill;
      final stroke = Paint()
        ..color = scrubLineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final norm in [scrubTempY, scrubHumidY]) {
        if (norm == null) continue;
        final c = Offset(dx, _dy(norm));
        canvas.drawCircle(c, 2, fill);
        canvas.drawCircle(c, 2, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_DayPlotPainter old) =>
      old.tempPoints != tempPoints ||
      old.humidPoints != humidPoints ||
      old.tempColor != tempColor ||
      old.humidColor != humidColor ||
      old.gridColor != gridColor ||
      old.scrubX != scrubX ||
      old.scrubTempY != scrubTempY ||
      old.scrubHumidY != scrubHumidY;
}
