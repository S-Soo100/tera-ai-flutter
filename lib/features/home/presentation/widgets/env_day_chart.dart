import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/domain/am_pm_time.dart';
import '../../../../shared/domain/axis_bounds.dart';
import '../../../../shared/domain/control_log.dart';
import '../../../../shared/domain/env_chart_data.dart';
import '../../../../shared/domain/num_format.dart';
import 'control_log_list.dart';
import '../../../../core/theme/viva_line.dart';

/// Split a telemetry line wherever at least one 30-minute bucket is absent.
/// Each metric uses its own points, so one failed sensor never bridges a gap.
List<List<({double x, double y})>> environmentLineSegments(
  List<({double x, double y})> points, {
  required double maxGap,
}) {
  final segments = <List<({double x, double y})>>[];
  for (final point in points) {
    if (!point.x.isFinite || !point.y.isFinite) continue;
    if (segments.isEmpty || point.x - segments.last.last.x > maxGap + 1e-9) {
      segments.add([point]);
    } else {
      segments.last.add(point);
    }
  }
  return segments;
}

/// 마커 중심 x들을 **실제 시각 자리에 두고, 가까운 것끼리는 살짝 겹쳐 편다.**
///
/// [centers]는 오름차순 픽셀 좌표. 이웃과 [clusterWidth] 안에 있는 마커들을
/// 한 묶음으로 보고, 묶음의 평균 위치를 중심으로 [maxGap] 간격(묶음이 크면
/// 전체 폭이 [clusterWidth]를 넘지 않게 더 좁게)으로 펼친다. 묶음은 통째로
/// [min]~[max] 안에 담는다.
///
/// 예전엔 22pt(≈1시간) 간격을 강제해 연속 조작이 몇 시간 뒤까지 밀려
/// 시각과 어긋나 보였다(2026-09-21 제보) — 색으로 구분되니 겹침을 허용한다.
List<double> resolveMarkerCenters(
  List<double> centers, {
  required double min,
  required double max,
  double maxGap = 8,
  double clusterWidth = 28,
}) {
  final out = <double>[];
  var i = 0;
  while (i < centers.length) {
    var j = i + 1;
    while (j < centers.length && centers[j] - centers[j - 1] < clusterWidth) {
      j++;
    }
    final n = j - i;
    final mean = centers.sublist(i, j).reduce((a, b) => a + b) / n;
    final gap = n > 1
        ? (clusterWidth / (n - 1) < maxGap ? clusterWidth / (n - 1) : maxGap)
        : 0.0;
    final spread = gap * (n - 1);
    var first = mean - spread / 2;
    if (first < min) first = min;
    if (first + spread > max) first = max - spread;
    for (var k = 0; k < n; k++) {
      out.add(first + gap * k);
    }
    i = j;
  }
  return out;
}

/// 온습도 상세의 **일간 가로 스크롤 차트** (Figma §A.5, 콘텐츠 폭 524pt = 24h).
///
/// 홈·통계의 [EnvChart](393pt 프레임 고정)와 다른 물건이다 — 하루를 통째로
/// 담아 옆으로 넘겨 본다. Y축 라벨은 **스크롤 밖 고정 오버레이**(좌 온도·우
/// 습도)라 차트가 라벨 밑으로 흘러 들어간다. 양끝 12px만 클리핑한다.
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
    this.scrubAnchor,
  });

  /// 손가락 표시 상자의 위치 기준 — 화면이 범위 막대(Figma BarGraph)를
  /// `CompositedTransformTarget`으로 감싸 넘긴다. 상자 아래 변이 막대 아래
  /// 변보다 1pt 위에 붙는다(Figma 상자 297 / 막대 298). 막대와 차트 사이에
  /// 다른 줄(지난날 일평균 안내)이 끼어도 상자가 그 줄을 덮지 않는다.
  /// null이면 차트 윗변에서 [scrubBoxGap] 위에 붙인다.
  final LayerLink? scrubAnchor;

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

  /// Y 눈금은 항상 6개([AxisBounds.defaultDivisions]+1) — 격자 5칸.
  static const double rowStep = 32;
  static const double gridSpan = rowStep * AxisBounds.defaultDivisions; // 160
  // Figma labels sit at the bottom of each 32px row. Keep one row above
  // the highest tick, and map both the curves and scrub dots to those ticks.
  static const double plotHeight = gridSpan + rowStep; // 192

  static const double axisHeight = 32;
  static const double totalHeight = markerBand + plotHeight + axisHeight;

  /// The graph clips at 12px screen insets; labels overlay the plot.
  static const double plotInset = 12;
  static const double yLabelWidth = 42;

  /// 격자선 — Figma 1610:5939·1610:6830 3배 PNG 실측 0.5pt `#E3E3E3`
  /// ([GlassPalette.border]).
  static const double gridStrokeWidth = kVivaHairline;

  // ── 손가락 표시 (Figma 1610:6830 `Dtail`) ──
  /// 상자 아래 변 ↔ 차트 윗변 22pt(상자 297 / 그래프 319). 상자는 아래 변을
  /// 기준으로 **위로** 커진다 — 휴대폰 글자를 키워도 차트를 덮지 않는다.
  /// 세로선은 이 높이(차트 윗변 22pt 위)에서 그래프 바닥선까지.
  static const double scrubBoxGap = 22;

  /// 상자를 담는 칸 높이 — 글자 2배(상한)에서도 상자가 들어간다.
  static const double scrubBoxSlot = 220;
  static const double scrubLineWidth = 2;
  static const double scrubDotRadius = 4;
  static const double scrubDotStroke = 2.5;
  static const scrubBoxKey = Key('env_day_chart_scrub_box');

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
    final target = (f * EnvDayChart.contentWidth - viewport)
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
      color: glass.deviceOff,
      letterSpacing: -.24,
      height: 1.193359375,
    );

    return SizedBox(
      key: EnvDayChart.chartKey,
      height: EnvDayChart.totalHeight,
      child: Stack(
        // 손가락 표시 상자가 차트 위(범위 막대 자리)로 올라간다.
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            left: EnvDayChart.plotInset,
            right: EnvDayChart.plotInset,
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
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
          // Y축 라벨은 스크롤 밖 고정. 그래프는 12px 안쪽까지 그린다.
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
          if (widget.scrubX case final scrubX?) _scrubOverlay(glass, scrubX),
        ],
      ),
    );
  }

  /// 손가락 표시(Figma 1610:6830) — 세로선·점·상자. 가로 스크롤 **밖** 층에
  /// 그려 차트 위로 올라갈 수 있게 하고, 스크롤 위치를 따라 x를 옮긴다.
  /// 세로선이 보이는 구간(좌우 12pt 안) 밖이면 통째로 숨긴다.
  Widget _scrubOverlay(GlassPalette glass, double scrubX) {
    const gap = EnvDayChart.scrubBoxGap;
    return Positioned(
      left: 0,
      right: 0,
      top: -gap,
      height: gap + EnvDayChart.markerBand + EnvDayChart.plotHeight,
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, c) => ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final offset = _controller.hasClients ? _controller.offset : 0.0;
              final x = EnvDayChart.plotInset +
                  scrubX * EnvDayChart.contentWidth -
                  offset;
              if (x < EnvDayChart.plotInset ||
                  x > c.maxWidth - EnvDayChart.plotInset) {
                return const SizedBox.shrink();
              }
              final t = widget.data.tempNormAt(scrubX);
              final h = widget.data.humidNormAt(scrubX);
              // 상자는 칸 아래쪽에 붙고 위로 커진다(글자 배율).
              final slot = SizedBox(
                width: c.maxWidth,
                height: EnvDayChart.scrubBoxSlot,
                child: CustomSingleChildLayout(
                  delegate:
                      _ScrubBoxLayout(lineX: x, inset: EnvDayChart.plotInset),
                  child: _scrubBox(glass, scrubX),
                ),
              );
              final anchor = widget.scrubAnchor;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _ScrubPainter(
                        x: x,
                        lineColor: glass.bodySecondary,
                        // 점 속은 두 모드 모두 흰색(Figma) — 색 원 안 글리프색.
                        dotFill: glass.deviceGlyph,
                        dots: [
                          if (t != null) (norm: t, color: glass.tempAccent),
                          if (h != null) (norm: h, color: glass.humidAccent),
                        ],
                      ),
                    ),
                  ),
                  if (anchor != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      child: CompositedTransformFollower(
                        link: anchor,
                        showWhenUnlinked: false,
                        targetAnchor: Alignment.bottomLeft,
                        followerAnchor: Alignment.bottomLeft,
                        offset: const Offset(0, -1),
                        child: slot,
                      ),
                    )
                  else
                    Positioned(
                        left: 0, top: -EnvDayChart.scrubBoxSlot, child: slot),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(GlassPalette glass, TextStyle labelStyle) {
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
              maxGap: const Duration(minutes: 30).inMicroseconds /
                  widget.data.to.difference(widget.data.from).inMicroseconds,
              tempPoints: widget.data.tempPoints,
              humidPoints: widget.data.humidPoints,
              tempColor: glass.tempAccent,
              humidColor: glass.humidAccent,
              gridColor: glass.border,
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
                  left: i / 4 * EnvDayChart.contentWidth + 4,
                  top: 10,
                  child: Text(_hourLabel(i * 6), style: labelStyle),
                ),
            ],
          ),
        ),
        ..._markers(glass),
      ],
    );
  }

  String _hourLabel(int hour) {
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return (hour < 12 ? 'home_chart_time_am' : 'home_chart_time_pm')
        .tr(namedArgs: {'h': '$h12'});
  }

  /// 마커 행 — 동작 시각 x에 28×28 원. 가까우면 살짝 겹쳐 편다(나중 것이 위).
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
    );

    return [
      for (var i = 0; i < spots.length; i++)
        Positioned(
          left: centers[i] - EnvDayChart.markerSize / 2,
          // Figma 1081:4873 — 28 마커가 32 띠 가운데(y+2).
          top: (EnvDayChart.markerBand - EnvDayChart.markerSize) / 2,
          child: Tooltip(
            message:
                '${formatAmPmTime(spots[i].e.at)} ${controlKindNameKey(spots[i].e.kind).tr()}',
            triggerMode: TooltipTriggerMode.tap,
            child: controlEntryIcon(spots[i].e, glass, EnvDayChart.markerSize),
          ),
        ),
    ];
  }

  /// 손가락 표시 상자(Figma 1610:7245 Box 143×66) — 윗줄 시각 12/500
  /// `#949090`, 아랫줄 온도·습도 20/600 `#1E1E1E`(사이 12). 면 `#F4F4F4`
  /// r12, **테두리 없음**. 안쪽 여백 12, 줄 사이 4.
  Widget _scrubBox(GlassPalette glass, double scrubX) {
    final at = widget.data.timeAt(scrubX);
    final t = widget.data.tempAt(scrubX);
    final h = widget.data.humidAt(scrubX);
    final valueStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 20,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 23.8671875 / 20,
      color: glass.textPrimary,
    );
    return Container(
      key: EnvDayChart.scrubBoxKey,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: glass.overlay,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatAmPmTime(at),
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.24,
              height: 14.3203125 / 12,
              color: glass.textTertiary,
            ),
          ),
          if (t != null || h != null) ...[
            const SizedBox(height: 4),
            // 휴대폰 글자를 키워 화면 폭을 넘을 때만 줄여 맞춘다(크기 자체는 Figma).
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t != null)
                    Text('env_detail_scrub_temp'.tr(args: [formatCompact(t)]),
                        maxLines: 1, style: valueStyle),
                  if (t != null && h != null) const SizedBox(width: 12),
                  if (h != null)
                    Text('env_detail_scrub_humid'.tr(args: [formatCompact(h)]),
                        maxLines: 1, style: valueStyle),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Fixed labels overlay the plot, matching Figma's 32px bottom-aligned rows.
  /// IgnorePointer keeps scrubbing available even beneath long decimal labels.
  Widget _axisOverlay({
    required GlassPalette glass,
    required bool left,
    required AxisBounds? axis,
    required String Function(double, int) format,
    required TextStyle style,
  }) {
    if (axis == null) return const SizedBox.shrink();
    final ticks = axis.ticks.reversed.toList();
    return Positioned(
      left: left ? EnvDayChart.plotInset : null,
      right: left ? null : EnvDayChart.plotInset,
      top: EnvDayChart.markerBand,
      height: EnvDayChart.plotHeight,
      width: EnvDayChart.yLabelWidth,
      child: IgnorePointer(
        child: Column(children: [
          for (final tick in ticks)
            SizedBox(
              height: EnvDayChart.rowStep,
              child: Align(
                alignment: left ? Alignment.bottomLeft : Alignment.bottomRight,
                child: Text(format(tick, axis.decimals),
                    style: style, maxLines: 1, softWrap: false),
              ),
            ),
        ]),
      ),
    );
  }
}

/// 손가락 표시 상자 자리 — 세로선 가운데, 좌우 [inset] 안에서 멈춘다. 칸
/// 아래쪽에 붙여 상자가 위로 커지게 한다.
class _ScrubBoxLayout extends SingleChildLayoutDelegate {
  const _ScrubBoxLayout({required this.lineX, required this.inset});

  final double lineX;
  final double inset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final maxWidth = constraints.maxWidth - inset * 2;
    return BoxConstraints(maxWidth: maxWidth < 0 ? 0 : maxWidth);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxLeft = size.width - inset - childSize.width;
    final left = (lineX - childSize.width / 2)
        .clamp(inset, maxLeft < inset ? inset : maxLeft);
    return Offset(left, size.height - childSize.height);
  }

  @override
  bool shouldRelayout(_ScrubBoxLayout old) =>
      old.lineX != lineX || old.inset != inset;
}

/// 손가락 표시 세로선·점(Figma 1610:6830) — 2pt `#626262` 선이 이 층 맨 위
/// (차트 윗변 [EnvDayChart.scrubBoxGap] 위 = 상자 아래 변)에서 그래프
/// 바닥선까지, 점은 지름 8 흰 채움 + 지표색 2.5 테두리.
class _ScrubPainter extends CustomPainter {
  const _ScrubPainter({
    required this.x,
    required this.lineColor,
    required this.dotFill,
    required this.dots,
  });

  final double x;
  final Color lineColor;
  final Color dotFill;
  final List<({double norm, Color color})> dots;

  @override
  void paint(Canvas canvas, Size size) {
    const plotTop = EnvDayChart.scrubBoxGap + EnvDayChart.markerBand;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, plotTop + EnvDayChart.plotHeight),
      Paint()
        ..color = lineColor
        ..strokeWidth = EnvDayChart.scrubLineWidth,
    );
    final fill = Paint()..color = dotFill;
    for (final d in dots) {
      final c = Offset(x, plotTop + _DayPlotPainter._dy(d.norm));
      canvas.drawCircle(c, EnvDayChart.scrubDotRadius, fill);
      canvas.drawCircle(
        c,
        EnvDayChart.scrubDotRadius,
        Paint()
          ..color = d.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = EnvDayChart.scrubDotStroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrubPainter old) =>
      old.x != x ||
      old.lineColor != lineColor ||
      old.dotFill != dotFill ||
      !listEquals(old.dots, dots);
}

/// 격자 + 온습도 라인. **직접 그린다** — 524pt 스크롤 캔버스는 프레임 고정
/// 전제의 fl_chart 배선보다 좌표를 직접 잡는 편이 정확하다. 손가락 표시는
/// 스크롤 밖 층([_ScrubPainter])이 그린다.
class _DayPlotPainter extends CustomPainter {
  const _DayPlotPainter({
    required this.maxGap,
    required this.tempPoints,
    required this.humidPoints,
    required this.tempColor,
    required this.humidColor,
    required this.gridColor,
  });

  final double maxGap;
  final List<({double x, double y})> tempPoints;
  final List<({double x, double y})> humidPoints;
  final Color tempColor;
  final Color humidColor;
  final Color gridColor;

  /// 정규화 y(0~1) → 픽셀. 1은 첫 눈금선, 0은 마지막 눈금선.
  static double _dy(double norm) =>
      EnvDayChart.rowStep + (1 - norm) * EnvDayChart.gridSpan;

  @override
  void paint(Canvas canvas, Size size) {
    // 가로 격자선 — Y 눈금마다 한 줄 (0.5pt #E3E3E3).
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = EnvDayChart.gridStrokeWidth;
    for (var i = 0; i <= AxisBounds.defaultDivisions + 1; i++) {
      final y = i * EnvDayChart.rowStep;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Six-hour boundaries are solid; their three-hour midpoints are dotted.
    // This painter scrolls with the same 524px time coordinate as the series.
    for (var hour = 0; hour <= 24; hour += 3) {
      final x = hour / 24 * size.width;
      final bottom = size.height + EnvDayChart.axisHeight;
      if (hour % 6 == 0) {
        canvas.drawLine(
            Offset(x, -EnvDayChart.markerBand), Offset(x, bottom), grid);
      } else {
        for (double y = -EnvDayChart.markerBand; y < size.height; y += 4) {
          canvas.drawLine(
              Offset(x, y),
              Offset(x, (y + 2).clamp(-EnvDayChart.markerBand, size.height)),
              grid);
        }
      }
    }
    for (final y in [-EnvDayChart.markerBand, size.height]) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    canvas.drawLine(Offset(0, size.height + EnvDayChart.axisHeight),
        Offset(size.width, size.height + EnvDayChart.axisHeight), grid);

    void drawLinePath(List<({double x, double y})> pts, Color color) {
      if (pts.length < 2) return; // 점 하나짜리 선은 보이지 않는다.
      final path = Path();
      for (final segment in environmentLineSegments(pts, maxGap: maxGap)) {
        if (segment.length < 2) continue;
        path.moveTo(segment.first.x * size.width, _dy(segment.first.y));
        for (final p in segment.skip(1)) {
          path.lineTo(p.x * size.width, _dy(p.y));
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    drawLinePath(tempPoints, tempColor);
    drawLinePath(humidPoints, humidColor);
  }

  @override
  bool shouldRepaint(_DayPlotPainter old) =>
      old.maxGap != maxGap ||
      old.tempPoints != tempPoints ||
      old.humidPoints != humidPoints ||
      old.tempColor != tempColor ||
      old.humidColor != humidColor ||
      old.gridColor != gridColor;
}
