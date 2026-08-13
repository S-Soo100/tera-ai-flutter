import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_c_tokens.dart';

/// C안 — Copilot Money 스타일 커뮤니티 탭.
///
/// 거래 내역 문법 — 날짜 섹션 헤더(오늘/어제) 아래 순백 카드,
/// 행마다 파스텔 카테고리 원 + 제목 + 시각.
class VariantCCommunityScreen extends StatelessWidget {
  const VariantCCommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 날짜별 그룹 (fixtures가 최신순이라 순서 유지).
    final groups = <String, List<LabPost>>{};
    for (final p in kLabPosts) {
      groups.putIfAbsent(labDaySection(p.at), () => []).add(p);
    }

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
            const Text('커뮤니티', style: VariantCTokens.cardTitle),
            const SizedBox(height: 12),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  entry.key,
                  style: VariantCTokens.caption
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: VariantCTokens.card,
                  borderRadius:
                      BorderRadius.circular(VariantCTokens.cardRadius),
                  boxShadow: const [VariantCTokens.cardShadow],
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < entry.value.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1,
                            thickness: 1,
                            indent: 60,
                            color: Color(0x0F000000)),
                      _PostRow(post: entry.value[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({required this.post});

  final LabPost post;

  /// 카테고리 → 파스텔/컬러/아이콘 (Copilot 카테고리 문법).
  (Color, Color, IconData) get _style => switch (post.category) {
        LabPostCategory.notice => (
            VariantCTokens.heaterPastel,
            VariantCTokens.heaterOn,
            Icons.campaign_outlined
          ),
        LabPostCategory.qna => (
            VariantCTokens.mistPastel,
            VariantCTokens.mistOn,
            Icons.help_outline
          ),
        LabPostCategory.free => (
            VariantCTokens.ledPastel,
            VariantCTokens.ledOn,
            Icons.chat_bubble_outline
          ),
        LabPostCategory.wiki => (
            VariantCTokens.fanPastel,
            VariantCTokens.fanOn,
            Icons.menu_book_outlined
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (pastel, on, icon) = _style;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: pastel, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: on),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title,
                  style: VariantCTokens.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${post.categoryLabel} · ${post.author} · '
                  '댓글 ${post.commentCount}',
                  style: VariantCTokens.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(labHm(post.at), style: VariantCTokens.caption),
        ],
      ),
    );
  }
}
