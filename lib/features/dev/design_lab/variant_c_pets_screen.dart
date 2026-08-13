import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_c_tokens.dart';

/// C안 — Copilot Money 스타일 마이크레 탭.
///
/// 계좌 카드 문법의 개체 카드(파스텔 아바타 원 + 큰 이름 + D-day 배지)
/// + 어젯밤 리포트를 월간 요약 문법(큰 수치 + 내역 행)으로.
class VariantCPetsScreen extends StatelessWidget {
  const VariantCPetsScreen({super.key});

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
          children: [
            const Text('내 크리처', style: VariantCTokens.cardTitle),
            const SizedBox(height: 12),
            for (final p in kLabPets) ...[
              _PetAccountCard(pet: p),
              const SizedBox(height: VariantCTokens.cardGap),
            ],
            const SizedBox(height: 12),
            const Text('어젯밤 리포트', style: VariantCTokens.sectionLabel),
            const SizedBox(height: 10),
            const _NightSummaryCard(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 계좌 카드 문법의 개체 카드
// ─────────────────────────────────────────────────────────────────────────────

class _PetAccountCard extends StatelessWidget {
  const _PetAccountCard({required this.pet});

  final LabPet pet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VariantCTokens.card,
        borderRadius: BorderRadius.circular(VariantCTokens.cardRadius),
        boxShadow: const [VariantCTokens.cardShadow],
      ),
      child: Row(
        children: [
          // 파스텔 아바타 원 — 사진 대신 개체 대체 컬러.
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: pet.avatarColor.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.pets, size: 24, color: pet.avatarColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: VariantCTokens.cardTitle.copyWith(fontSize: 19),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pet.species} · ${pet.morph}',
                  style: VariantCTokens.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  '체중 ${pet.weightG.toStringAsFixed(1)}g',
                  style: VariantCTokens.caption.copyWith(
                    color: VariantCTokens.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // D-day 배지 (해칭 후 경과일).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: pet.avatarColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              'D+${pet.ageDays}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: pet.avatarColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 어젯밤 리포트 — 월간 요약 문법
// ─────────────────────────────────────────────────────────────────────────────

class _NightSummaryCard extends StatelessWidget {
  const _NightSummaryCard();

  @override
  Widget build(BuildContext context) {
    final report = kLabNightReport;

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
          // 큰 수치 — 월 지출 합계 문법.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: report.activeMinutes.toDouble()),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => RichText(
              text: TextSpan(
                text: '${v.round()}',
                style: VariantCTokens.heroNumber,
                children: const [
                  TextSpan(
                      text: '분 활동',
                      style: VariantCTokens.heroNumberMinor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text('22:00 ~ 06:00 기준', style: VariantCTokens.caption),
          const SizedBox(height: 14),
          // 활동/휴식 비율 바 — 파스텔 스택.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: report.activeRatio),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, r, _) => ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    Expanded(
                      flex: (r * 1000).round().clamp(1, 999),
                      child:
                          const ColoredBox(color: VariantCTokens.fanOn),
                    ),
                    Expanded(
                      flex: (1000 - (r * 1000).round()).clamp(1, 999),
                      child: const ColoredBox(
                          color: VariantCTokens.fanPastel),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: Color(0x0F000000)),
          const SizedBox(height: 8),
          // 내역 행 — 거래 내역 문법.
          _SummaryRow(
            pastel: VariantCTokens.fanPastel,
            on: VariantCTokens.fanOn,
            icon: Icons.directions_run,
            label: '활동',
            value: '${report.activeMinutes}분',
          ),
          _SummaryRow(
            pastel: VariantCTokens.ledPastel,
            on: VariantCTokens.ledOn,
            icon: Icons.bedtime_outlined,
            label: '휴식',
            value: '${report.restMinutes}분',
          ),
          _SummaryRow(
            pastel: VariantCTokens.mistPastel,
            on: VariantCTokens.mistOn,
            icon: Icons.water_drop_outlined,
            label: '분무',
            value: '${report.mistCount}회',
          ),
          _SummaryRow(
            pastel: VariantCTokens.heaterPastel,
            on: VariantCTokens.heaterOn,
            icon: Icons.trending_up,
            label: '피크 시각',
            value: labHm(report.peakAt),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.pastel,
    required this.on,
    required this.icon,
    required this.label,
    required this.value,
  });

  final Color pastel;
  final Color on;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: pastel, shape: BoxShape.circle),
            child: Icon(icon, size: 15, color: on),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: VariantCTokens.body)),
          Text(
            value,
            style: VariantCTokens.value.copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}
