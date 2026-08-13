import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_b_tokens.dart';

/// B안 — Flighty 스타일 커뮤니티 탭: 출발/도착 보드식 게시글 리스트.
///
/// 공항 전광판 문법 — 시각(tabular)·앰버 대문자 카테고리 라벨·제목 행.
/// 모노스페이스 감성은 tabular figures + 자간으로 낸다.
class VariantBCommunityScreen extends StatelessWidget {
  const VariantBCommunityScreen({super.key});

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
            Text('DEPARTURES — 커뮤니티', style: VariantBTokens.dataLabel),
            SizedBox(height: 12),
            _BoardCard(),
          ],
        ),
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: VariantBTokens.card,
        borderRadius: BorderRadius.circular(VariantBTokens.cardRadius),
      ),
      child: Column(
        children: [
          for (var i = 0; i < kLabPosts.length; i++) ...[
            if (i > 0)
              const Divider(
                  color: VariantBTokens.divider, height: 1, thickness: 1),
            _BoardRow(post: kLabPosts[i]),
          ],
        ],
      ),
    );
  }
}

class _BoardRow extends StatelessWidget {
  const _BoardRow({required this.post});

  final LabPost post;

  /// 공지는 앰버 강조(보드의 지연 안내 문법), 나머지는 그린.
  Color get _categoryColor => post.category == LabPostCategory.notice
      ? VariantBTokens.amber
      : VariantBTokens.green;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 시각 열 — 전광판 좌측 고정폭.
          SizedBox(
            width: 48,
            child: Text(
              labHm(post.at),
              style: VariantBTokens.bodySecondary.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.categoryLabel.toUpperCase(),
                  style: VariantBTokens.dataLabel
                      .copyWith(color: _categoryColor),
                ),
                const SizedBox(height: 3),
                Text(
                  post.title,
                  style: VariantBTokens.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${post.author} · ${labDaySection(post.at)}',
                  style: VariantBTokens.bodySecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 댓글 수 — 보드 우측 상태 칸.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.chat_bubble_outline,
                  size: 14, color: VariantBTokens.textTertiary),
              const SizedBox(height: 2),
              Text(
                '${post.commentCount}',
                style: VariantBTokens.bodySecondary.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
