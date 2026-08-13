import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'tokens/variant_a_tokens.dart';
import 'tokens/variant_b_tokens.dart';
import 'tokens/variant_c_tokens.dart';

/// 디자인 랩 선택 화면 — 벤치마크 3안 카드.
///
/// 스펙: `docs/design-lab-benchmark-specs.md`. 하드코딩 색·문자열은
/// 랩 한정 허용(chart-lab 전례) — 전면 적용 단계에서 승격한다.
class DesignLabScreen extends StatelessWidget {
  const DesignLabScreen({super.key});

  static const screenKey = Key('design_lab_screen');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: DesignLabScreen.screenKey,
      appBar: AppBar(title: const Text('디자인 랩 — 벤치마크 3안')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '같은 더미 데이터로 세 가지 디자인 언어를 체험한다. '
            '구조·위계·모션은 벤치마크를 따르고, 그래픽은 비바나트 자산으로 치환.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _VariantCard(
            label: 'A안',
            title: 'Apple Home — Liquid Glass',
            summary: '실앱에 적용된 현행 디자인(홈 미리보기). '
                '딥 월페이퍼 위 유리 타일, 2×2 그리드, 스프링 스케일 탭.',
            colors: const [
              VariantATokens.wallpaperTop,
              VariantATokens.wallpaperBottom,
              VariantATokens.heaterTint,
              VariantATokens.mistTint,
            ],
            onTap: () => context.push('/dev/design-lab/a'),
          ),
          const SizedBox(height: 12),
          _VariantCard(
            label: 'B안',
            title: 'Flighty — 공항 전광판',
            summary: '4탭 풀 체험(홈·통계·마이크레·커뮤니티). '
                '다크 전광판 위계, FIDS 보드, 보딩패스 개체 카드.',
            colors: const [
              VariantBTokens.background,
              VariantBTokens.card,
              VariantBTokens.amber,
              VariantBTokens.green,
            ],
            onTap: () => context.push('/dev/design-lab/b'),
          ),
          const SizedBox(height: 12),
          _VariantCard(
            label: 'C안',
            title: 'Copilot Money — 데이터 시각화',
            summary: '4탭 풀 체험(홈·통계·마이크레·커뮤니티). '
                '웜 화이트 + 그라데이션 차트 + 파스텔 카드/도넛.',
            colors: const [
              VariantCTokens.background,
              VariantCTokens.tempGradStart,
              VariantCTokens.tempGradEnd,
              VariantCTokens.humidGradStart,
            ],
            onTap: () => context.push('/dev/design-lab/c'),
          ),
        ],
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  const _VariantCard({
    required this.label,
    required this.title,
    required this.summary,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final String title;
  final String summary;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 대표색 미니 프리뷰
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < colors.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Swatch(colors[i]),
                          const SizedBox(width: 4),
                          _Swatch(colors[i + 1]),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.labelSmall),
                    const SizedBox(height: 2),
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(summary, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
    );
  }
}
