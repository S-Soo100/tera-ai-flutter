import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_b_tokens.dart';

/// B안 — Flighty 스타일 통계 탭: 전광판 데이터 보드.
///
/// 구성: 상단 대형 수치(주간 평균) + 미니 바 차트(CustomPaint) →
/// 주간 7일 FIDS 행(날짜|최고|최저|상태배지). 앰버=주의, 그린=안정.
class VariantBStatsScreen extends StatelessWidget {
  const VariantBStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantBTokens.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            VariantBTokens.screenHPad,
            12,
            VariantBTokens.screenHPad,
            32,
          ),
          children: const [
            Text('WEEKLY REPORT', style: VariantBTokens.dataLabel),
            SizedBox(height: 12),
            _WeekSummaryCard(),
            SizedBox(height: VariantBTokens.cardGap),
            _FidsBoardCard(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 주간 요약 (대형 수치 + 미니 바 차트)
// ─────────────────────────────────────────────────────────────────────────────

class _WeekSummaryCard extends StatelessWidget {
  const _WeekSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VariantBTokens.card,
        borderRadius: BorderRadius.circular(VariantBTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CountUpStat(
                  label: 'AVG TEMP',
                  value: kLabWeekTempAvg,
                  format: (v) => '${v.toStringAsFixed(1)}℃',
                ),
              ),
              Container(width: 1, height: 44, color: VariantBTokens.divider),
              const SizedBox(width: 16),
              Expanded(
                child: _CountUpStat(
                  label: 'AVG HUMIDITY',
                  value: kLabWeekHumidAvg,
                  format: (v) => '${v.round()}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('DAILY MAX TEMP', style: VariantBTokens.dataLabel),
          const SizedBox(height: 10),
          // 미니 바 차트 — 채움 애니메이션 후 고정.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, grow, _) => CustomPaint(
              size: const Size(double.infinity, 72),
              painter: _WeekBarsPainter(grow: grow),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final d in kLabWeekEnv)
                Expanded(
                  child: Text(
                    kLabWeekdayKo[d.day.weekday - 1],
                    textAlign: TextAlign.center,
                    style: VariantBTokens.dataLabel.copyWith(fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountUpStat extends StatelessWidget {
  const _CountUpStat({
    required this.label,
    required this.value,
    required this.format,
  });

  final String label;
  final double value;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VariantBTokens.dataLabel),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) =>
              Text(format(v), style: VariantBTokens.bigNumber),
        ),
      ],
    );
  }
}

/// 일별 최고온도 바 — 주의(≥28.5℃)는 앰버, 안정은 그린.
class _WeekBarsPainter extends CustomPainter {
  _WeekBarsPainter({required this.grow});

  final double grow;

  @override
  void paint(Canvas canvas, Size size) {
    final days = kLabWeekEnv;
    // 바 높이 스케일: 최저 24℃ 바닥 ~ 최고 29.5℃ 상한 고정(비교 안정).
    const floor = 24.0;
    const ceil = 29.5;
    final slot = size.width / days.length;
    final barW = slot * 0.42;

    for (var i = 0; i < days.length; i++) {
      final d = days[i];
      final ratio = ((d.tempMax - floor) / (ceil - floor)).clamp(0.0, 1.0);
      final h = size.height * ratio * grow;
      final x = slot * i + (slot - barW) / 2;
      final color = d.isWarning ? VariantBTokens.amber : VariantBTokens.green;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barW, h),
          const Radius.circular(3),
        ),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WeekBarsPainter oldDelegate) =>
      oldDelegate.grow != grow;
}

// ─────────────────────────────────────────────────────────────────────────────
// FIDS 보드 (날짜 | 최고 | 최저 | 상태배지)
// ─────────────────────────────────────────────────────────────────────────────

class _FidsBoardCard extends StatelessWidget {
  const _FidsBoardCard();

  @override
  Widget build(BuildContext context) {
    // 전광판은 최신이 위 — 역순.
    final days = kLabWeekEnv.reversed.toList();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: VariantBTokens.card,
        borderRadius: BorderRadius.circular(VariantBTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                    child: Text('DATE', style: VariantBTokens.dataLabel)),
                SizedBox(
                  width: 64,
                  child: Text('MAX',
                      textAlign: TextAlign.right,
                      style: VariantBTokens.dataLabel),
                ),
                SizedBox(
                  width: 64,
                  child: Text('MIN',
                      textAlign: TextAlign.right,
                      style: VariantBTokens.dataLabel),
                ),
                SizedBox(
                  width: 64,
                  child: Text('STATUS',
                      textAlign: TextAlign.right,
                      style: VariantBTokens.dataLabel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < days.length; i++) ...[
            if (i > 0)
              const Divider(
                  color: VariantBTokens.divider, height: 1, thickness: 1),
            _FidsRow(day: days[i]),
          ],
        ],
      ),
    );
  }
}

class _FidsRow extends StatelessWidget {
  const _FidsRow({required this.day});

  final LabDayEnv day;

  @override
  Widget build(BuildContext context) {
    final tabular = VariantBTokens.body.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final statusColor =
        day.isWarning ? VariantBTokens.amber : VariantBTokens.green;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Expanded(child: Text(labDayLabel(day.day), style: tabular)),
          SizedBox(
            width: 64,
            child: Text(
              '${day.tempMax.toStringAsFixed(1)}℃',
              textAlign: TextAlign.right,
              style: tabular,
            ),
          ),
          SizedBox(
            width: 64,
            child: Text(
              '${day.tempMin.toStringAsFixed(1)}℃',
              textAlign: TextAlign.right,
              style: tabular.copyWith(color: VariantBTokens.textSecondary),
            ),
          ),
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  day.isWarning ? '주의' : '안정',
                  style:
                      VariantBTokens.badge.copyWith(color: statusColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
