import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'tokens/variant_a_tokens.dart';
import 'tokens/variant_b_tokens.dart';

/// 디자인 테스트 선택 화면 — 테스트 유저용 A/B 시안 카드.
/// C안(Copilot Money)은 2026-08-14 폐기(A안 개선·B안 유지 결정).
///
/// 스펙: `docs/design-lab-benchmark-specs.md`, 공개 계획:
/// `docs/design-test-rollout-plan.md`. 하드코딩 색·문자열은
/// 랩 한정 허용(chart-lab 전례) — 전면 적용 단계에서 승격한다.
class DesignLabScreen extends StatelessWidget {
  const DesignLabScreen({super.key});

  static const screenKey = Key('design_lab_screen');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: DesignLabScreen.screenKey,
      appBar: AppBar(title: const Text('디자인 미리보기')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '비바나트가 검토 중인 두 가지 디자인을 직접 체험해 보세요. '
            '모든 데이터는 데모입니다 — 실제 사육장·계정과 연결되지 않아요.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            '느낀 점은 운영자에게 알려주세요.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          _VariantCard(
            label: 'A안',
            title: 'Apple Home — 솔리드 다크·와이드 카메라',
            summary: '4탭 풀 체험(홈·통계·마이크레·커뮤니티). '
                '차분한 단색 바닥 위 솔리드 타일, 풀블리드 4:3 카메라, '
                '2×2 그리드, 스프링 스케일 탭.',
            colors: [
              VariantATokens.of(context).wallpaperTop,
              VariantATokens.of(context).glassOverlayStrong,
              VariantATokens.of(context).heaterTint,
              VariantATokens.of(context).mistTint,
            ],
            onTap: () => context.push('/design-test/a'),
          ),
          const SizedBox(height: 12),
          _VariantCard(
            label: 'B안',
            title: 'Flighty — 공항 전광판',
            summary: '4탭 풀 체험(홈·통계·마이크레·커뮤니티). '
                '다크 전광판 위계, FIDS 보드, 보딩패스 개체 카드.',
            colors: [
              VariantBTokens.of(context).background,
              VariantBTokens.of(context).card,
              VariantBTokens.of(context).amber,
              VariantBTokens.of(context).green,
            ],
            onTap: () => context.push('/design-test/b'),
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
