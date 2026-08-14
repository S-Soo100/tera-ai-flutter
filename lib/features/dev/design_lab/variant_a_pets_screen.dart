import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_a_tokens.dart';
import 'variant_a_widgets.dart';

/// A안 — Liquid Glass 마이크레 탭.
///
/// 실앱 구성 미러: [개체 목록|리포트] 세그먼트. 개체는 유리 카드
/// (아바타·이름·종/모프·D+N·체중), 리포트는 어젯밤 활동 요약.
class VariantAPetsScreen extends StatefulWidget {
  const VariantAPetsScreen({super.key});

  @override
  State<VariantAPetsScreen> createState() => _VariantAPetsScreenState();
}

class _VariantAPetsScreenState extends State<VariantAPetsScreen> {
  /// 0=개체 목록, 1=리포트.
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VariantATokens.wallpaperTop,
      body: Stack(
        children: [
          const Positioned.fill(child: AWallpaper()),
          SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                VariantATokens.screenHPad,
                12,
                VariantATokens.screenHPad,
                120,
              ),
              children: [
                const Text('마이 크레', style: VariantATokens.headerTitle),
                const SizedBox(height: 16),
                AGlassSegment(
                  labels: const ['개체 목록', '리포트'],
                  selected: _tab,
                  onSelected: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: VariantATokens.tileGap),
                if (_tab == 0)
                  for (final p in kLabPets) ...[
                    _PetCard(pet: p),
                    const SizedBox(height: VariantATokens.tileGap),
                  ]
                else ...[
                  const _NightReportCard(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 개체 유리 카드
// ─────────────────────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  const _PetCard({required this.pet});

  final LabPet pet;

  @override
  Widget build(BuildContext context) {
    return AGlass(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: pet.avatarColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.pets, size: 20, color: Color(0xCC000000)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: VariantATokens.tileTitle),
                const SizedBox(height: 2),
                Text(
                  '${pet.species} · ${pet.morph}',
                  style: VariantATokens.tileStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('D+${pet.ageDays}', style: VariantATokens.chipValue),
              const SizedBox(height: 2),
              Text('${pet.weightG.toStringAsFixed(1)}g',
                  style: VariantATokens.tileStatus),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 어젯밤 리포트 (활동/휴식 비율 바 + 4열 수치)
// ─────────────────────────────────────────────────────────────────────────────

class _NightReportCard extends StatelessWidget {
  const _NightReportCard();

  @override
  Widget build(BuildContext context) {
    final report = kLabNightReport;
    final night = kLabNightActivity;

    return AGlass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('어젯밤 활동', style: VariantATokens.tileTitle),
              const Spacer(),
              Text(
                '${labHm(night.start)} → ${labHm(night.end)}',
                style: VariantATokens.tileStatus,
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 활동/휴식 비율 바.
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: (report.activeRatio * 1000).round().clamp(1, 999),
                    child:
                        const ColoredBox(color: VariantATokens.heaterTint),
                  ),
                  Expanded(
                    flex: (1000 - (report.activeRatio * 1000).round())
                        .clamp(1, 999),
                    child:
                        const ColoredBox(color: VariantATokens.glassOverlay),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ReportStat(
                    label: '활동', value: '${report.activeMinutes}분'),
              ),
              Expanded(
                child:
                    _ReportStat(label: '휴식', value: '${report.restMinutes}분'),
              ),
              Expanded(
                child:
                    _ReportStat(label: '분무', value: '${report.mistCount}회'),
              ),
              Expanded(
                child: _ReportStat(label: '피크', value: labHm(report.peakAt)),
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
        Text(label, style: VariantATokens.tileStatus),
        const SizedBox(height: 2),
        Text(
          value,
          style: VariantATokens.tileTitle.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
