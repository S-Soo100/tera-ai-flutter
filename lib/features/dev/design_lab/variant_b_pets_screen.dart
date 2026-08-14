import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_b_tokens.dart';

/// B안 — Flighty 스타일 마이크레 탭: 보딩패스식 개체 카드.
///
/// 항공편 카드 문법 — 이름·모프를 대문자 라벨로, 해칭일·경과일(D+N)·체중을
/// 게이트/좌석 박스 문법으로. 하단에 어젯밤 리포트 요약(진행 바 재사용).
class VariantBPetsScreen extends StatelessWidget {
  const VariantBPetsScreen({super.key});

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
          children: [
            const Text('MY CREATURES', style: VariantBTokens.dataLabel),
            const SizedBox(height: 12),
            for (final p in kLabPets) ...[
              _BoardingPassCard(pet: p),
              const SizedBox(height: VariantBTokens.cardGap),
            ],
            const SizedBox(height: 8),
            const Text('LAST NIGHT', style: VariantBTokens.dataLabel),
            const SizedBox(height: 12),
            const _NightReportCard(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 보딩패스식 개체 카드
// ─────────────────────────────────────────────────────────────────────────────

class _BoardingPassCard extends StatelessWidget {
  const _BoardingPassCard({required this.pet});

  final LabPet pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: VariantBTokens.card,
        borderRadius: BorderRadius.circular(VariantBTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 아바타 + 이름 + 종 배지.
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: pet.avatarColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pets,
                      size: 18, color: Color(0xCC000000)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pet.name, style: VariantBTokens.midNumber),
                      const SizedBox(height: 2),
                      Text(pet.species,
                          style: VariantBTokens.bodySecondary),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: VariantBTokens.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '건강',
                    style: VariantBTokens.badge
                        .copyWith(color: VariantBTokens.green),
                  ),
                ),
              ],
            ),
          ),
          // 절취선 — 보딩패스 문법.
          Row(
            children: [
              const _Notch(isLeft: true),
              Expanded(
                child: CustomPaint(
                  size: const Size(double.infinity, 1),
                  painter: _DashPainter(),
                ),
              ),
              const _Notch(isLeft: false),
            ],
          ),
          // 하단: 게이트/좌석 문법 3열 (MORPH | AGE | WEIGHT).
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _PassField(
                    label: 'MORPH',
                    value: pet.morph,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _PassField(
                    label: 'AGE',
                    value: 'D+${pet.ageDays}',
                    accent: true,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: _PassField(
                    label: 'WEIGHT',
                    value: '${pet.weightG.toStringAsFixed(1)}g',
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

class _PassField extends StatelessWidget {
  const _PassField({
    required this.label,
    required this.value,
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VariantBTokens.dataLabel),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: VariantBTokens.body.copyWith(
            fontWeight: FontWeight.w700,
            color: accent ? VariantBTokens.amber : VariantBTokens.textPrimary,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// 절취선 좌우 반원 홈 — 배경색으로 파낸다.
class _Notch extends StatelessWidget {
  const _Notch({required this.isLeft});

  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 16,
      decoration: BoxDecoration(
        color: VariantBTokens.background,
        borderRadius: BorderRadius.horizontal(
          left: isLeft ? Radius.zero : const Radius.circular(16),
          right: isLeft ? const Radius.circular(16) : Radius.zero,
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VariantBTokens.divider
      ..strokeWidth = 1.4;
    const dash = 5.0;
    const gap = 4.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(x + dash, y), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// 어젯밤 리포트 요약 (진행 바 재사용)
// ─────────────────────────────────────────────────────────────────────────────

class _NightReportCard extends StatelessWidget {
  const _NightReportCard();

  @override
  Widget build(BuildContext context) {
    final report = kLabNightActivity;

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
              const Text('어젯밤 활동', style: VariantBTokens.body),
              const Spacer(),
              Text(
                '${labHm(kLabNightActivity.start)} → '
                '${labHm(kLabNightActivity.end)}',
                style: VariantBTokens.bodySecondary.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 활동/휴식 비율 바 — 비행 진행 바 문법 재사용.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: report.activeRatio),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, r, _) => ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: VariantBTokens.progressHeight,
                child: Row(
                  children: [
                    Expanded(
                      flex: (r * 1000).round().clamp(1, 999),
                      child: const ColoredBox(color: VariantBTokens.amber),
                    ),
                    Expanded(
                      flex: (1000 - (r * 1000).round()).clamp(1, 999),
                      child: const ColoredBox(
                          color: VariantBTokens.progressTrack),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ReportStat(
                  label: 'ACTIVE',
                  value: '${report.activeMinutes}분',
                ),
              ),
              Expanded(
                child: _ReportStat(
                  label: 'REST',
                  value: '${report.restMinutes}분',
                ),
              ),
              Expanded(
                child: _ReportStat(
                  label: 'MIST',
                  value: '${report.mistCount}회',
                ),
              ),
              Expanded(
                child: _ReportStat(
                  label: 'PEAK',
                  value: labHm(report.peakAt),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: VariantBTokens.dataLabel),
        const SizedBox(height: 4),
        Text(
          value,
          style: VariantBTokens.body.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
