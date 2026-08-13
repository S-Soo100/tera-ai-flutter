import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_c_tokens.dart';

/// C안 — Copilot Money 스타일 통계 탭.
///
/// 구성: 주간 히어로 수치 → 주간 그라데이션 영역 차트(reveal) →
/// 요일별 습도 바 차트 → 기기 가동 도넛 분포(파스텔 + 범례).
/// 카드 위계(순백 카드 + 그림자 + radius 20)는 홈과 동일.
class VariantCStatsScreen extends StatelessWidget {
  const VariantCStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantCTokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            VariantCTokens.screenHPad,
            8,
            VariantCTokens.screenHPad,
            32,
          ),
          children: const [
            Text('이번 주', style: VariantCTokens.cardTitle),
            SizedBox(height: 12),
            _WeekHero(),
            SizedBox(height: 16),
            _WeekAreaChartCard(),
            SizedBox(height: 24),
            Text('요일별 습도', style: VariantCTokens.sectionLabel),
            SizedBox(height: 10),
            _HumidBarsCard(),
            SizedBox(height: 24),
            Text('기기 가동 분포', style: VariantCTokens.sectionLabel),
            SizedBox(height: 10),
            _RuntimeDonutCard(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 주간 히어로 수치
// ─────────────────────────────────────────────────────────────────────────────

class _WeekHero extends StatelessWidget {
  const _WeekHero();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: kLabWeekTempAvg - 2, end: kLabWeekTempAvg),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            final whole = v.truncate();
            final frac = ((v - whole) * 10).round().clamp(0, 9);
            return RichText(
              text: TextSpan(
                text: '$whole',
                style: VariantCTokens.heroNumber,
                children: [
                  TextSpan(
                      text: '.$frac℃',
                      style: VariantCTokens.heroNumberMinor),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text('주간 평균', style: VariantCTokens.caption),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '습도 ${kLabWeekHumidAvg.round()}%',
            style: VariantCTokens.value,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 주간 그라데이션 영역 차트 (일평균 + 최고/최저 밴드)
// ─────────────────────────────────────────────────────────────────────────────

class _WeekAreaChartCard extends StatelessWidget {
  const _WeekAreaChartCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VariantCTokens.card,
        borderRadius: BorderRadius.circular(VariantCTokens.cardRadius),
        boxShadow: const [VariantCTokens.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('온도 추이 · 7일', style: VariantCTokens.cardTitle),
          const SizedBox(height: 14),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, reveal, _) => SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeekAreaPainter(reveal: reveal),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in kLabWeekEnv)
                Expanded(
                  child: Text(
                    kLabWeekdayKo[d.day.weekday - 1],
                    textAlign: TextAlign.center,
                    style: VariantCTokens.caption,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 일평균 라인(코럴→퍼플 그라데이션) + 최고/최저 밴드(연한 필).
class _WeekAreaPainter extends CustomPainter {
  _WeekAreaPainter({required this.reveal});

  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final days = kLabWeekEnv;
    final min = days.map((d) => d.tempMin).reduce(math.min) - 0.5;
    final max = days.map((d) => d.tempMax).reduce(math.max) + 0.5;
    final span = max - min;

    double yOf(double v) => size.height * (1 - (v - min) / span);
    double xOf(int i) => size.width * i / (days.length - 1);

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height));

    // 최고/최저 밴드.
    final band = Path()..moveTo(xOf(0), yOf(days[0].tempMax));
    for (var i = 1; i < days.length; i++) {
      band.lineTo(xOf(i), yOf(days[i].tempMax));
    }
    for (var i = days.length - 1; i >= 0; i--) {
      band.lineTo(xOf(i), yOf(days[i].tempMin));
    }
    band.close();
    canvas.drawPath(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            VariantCTokens.tempGradStart.withValues(alpha: 0.18),
            VariantCTokens.tempGradEnd.withValues(alpha: 0.04),
          ],
        ),
    );

    // 일평균 라인.
    final line = Path()..moveTo(xOf(0), yOf(days[0].tempAvg));
    for (var i = 1; i < days.length; i++) {
      line.lineTo(xOf(i), yOf(days[i].tempAvg));
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = VariantCTokens.chartLineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, 0),
          [VariantCTokens.tempGradStart, VariantCTokens.tempGradEnd],
        ),
    );

    // 일평균 점.
    for (var i = 0; i < days.length; i++) {
      final p = Offset(xOf(i), yOf(days[i].tempAvg));
      canvas.drawCircle(p, 4, Paint()..color = Colors.white);
      canvas.drawCircle(
        p,
        4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Color.lerp(
            VariantCTokens.tempGradStart,
            VariantCTokens.tempGradEnd,
            i / (days.length - 1),
          )!,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WeekAreaPainter oldDelegate) =>
      oldDelegate.reveal != reveal;
}

// ─────────────────────────────────────────────────────────────────────────────
// 요일별 습도 바 차트 (블루→시안 그라데이션 바)
// ─────────────────────────────────────────────────────────────────────────────

class _HumidBarsCard extends StatelessWidget {
  const _HumidBarsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VariantCTokens.card,
        borderRadius: BorderRadius.circular(VariantCTokens.cardRadius),
        boxShadow: const [VariantCTokens.cardShadow],
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, grow, _) => SizedBox(
              height: 110,
              width: double.infinity,
              child: CustomPaint(painter: _HumidBarsPainter(grow: grow)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in kLabWeekEnv)
                Expanded(
                  child: Text(
                    kLabWeekdayKo[d.day.weekday - 1],
                    textAlign: TextAlign.center,
                    style: VariantCTokens.caption,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HumidBarsPainter extends CustomPainter {
  _HumidBarsPainter({required this.grow});

  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final days = kLabWeekEnv;
    // 습도 스케일 50~70% 고정 — 랩 데이터가 그 안에서 논다.
    const floor = 50.0;
    const ceil = 70.0;
    final slot = size.width / days.length;
    final barW = slot * 0.46;

    for (var i = 0; i < days.length; i++) {
      final ratio =
          ((days[i].humidAvg - floor) / (ceil - floor)).clamp(0.0, 1.0);
      final h = size.height * ratio * grow;
      final x = slot * i + (slot - barW) / 2;
      final rect = Rect.fromLTWH(x, size.height - h, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barW / 2)),
        Paint()
          ..shader = ui.Gradient.linear(
            rect.topCenter,
            rect.bottomCenter,
            [VariantCTokens.humidGradEnd, VariantCTokens.humidGradStart],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HumidBarsPainter oldDelegate) =>
      oldDelegate.grow != grow;
}

// ─────────────────────────────────────────────────────────────────────────────
// 기기 가동 도넛 분포 (파스텔 세그먼트 + 범례)
// ─────────────────────────────────────────────────────────────────────────────

class _RuntimeDonutCard extends StatelessWidget {
  const _RuntimeDonutCard();

  static Color _onColorOf(LabDeviceKind kind) => switch (kind) {
        LabDeviceKind.heater => VariantCTokens.heaterOn,
        LabDeviceKind.mist => VariantCTokens.mistOn,
        LabDeviceKind.led => VariantCTokens.ledOn,
        LabDeviceKind.fan => VariantCTokens.fanOn,
      };

  static String _runtimeLabel(int minutes) {
    if (minutes < 60) return '$minutes분';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h시간' : '$h시간 $m분';
  }

  @override
  Widget build(BuildContext context) {
    final total = kLabDevices.fold<int>(
        0, (sum, d) => sum + d.todayRuntimeMinutes);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VariantCTokens.card,
        borderRadius: BorderRadius.circular(VariantCTokens.cardRadius),
        boxShadow: const [VariantCTokens.cardShadow],
      ),
      child: Row(
        children: [
          // 도넛 — sweep 채움 애니메이션.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, sweep, _) => SizedBox(
              width: 116,
              height: 116,
              child: CustomPaint(
                painter: _DonutPainter(sweep: sweep),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _runtimeLabel(total),
                        style: VariantCTokens.value,
                        textAlign: TextAlign.center,
                      ),
                      const Text('오늘 합계', style: VariantCTokens.caption),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // 범례.
          Expanded(
            child: Column(
              children: [
                for (final d in kLabDevices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _onColorOf(d.kind),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(d.name, style: VariantCTokens.caption),
                        ),
                        Text(
                          _runtimeLabel(d.todayRuntimeMinutes),
                          style: VariantCTokens.caption.copyWith(
                            color: VariantCTokens.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.sweep});

  final double sweep;

  static Color _colorOf(LabDeviceKind kind) => switch (kind) {
        LabDeviceKind.heater => VariantCTokens.heaterOn,
        LabDeviceKind.mist => VariantCTokens.mistOn,
        LabDeviceKind.led => VariantCTokens.ledOn,
        LabDeviceKind.fan => VariantCTokens.fanOn,
      };

  @override
  void paint(Canvas canvas, Size size) {
    final total = kLabDevices.fold<int>(
        0, (sum, d) => sum + d.todayRuntimeMinutes);
    if (total == 0) return;

    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 7;
    const gapRad = 0.06; // 세그먼트 사이 숨 쉬는 틈.
    var start = -math.pi / 2;

    for (final d in kLabDevices) {
      final frac = d.todayRuntimeMinutes / total;
      final arc = (2 * math.pi * frac - gapRad).clamp(0.02, 2 * math.pi);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        arc * sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round
          ..color = _colorOf(d.kind),
      );
      start += 2 * math.pi * frac;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.sweep != sweep;
}
