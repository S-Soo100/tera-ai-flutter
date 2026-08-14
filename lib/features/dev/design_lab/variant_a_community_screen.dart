import 'package:flutter/material.dart';

import 'design_lab_fixtures.dart';
import 'tokens/variant_a_tokens.dart';
import 'variant_a_widgets.dart';

/// A안 — Liquid Glass 커뮤니티 탭.
///
/// 실앱 구성 미러: 카테고리 칩(전체+4종, 필터) + 게시글 유리 카드 리스트.
class VariantACommunityScreen extends StatefulWidget {
  const VariantACommunityScreen({super.key});

  @override
  State<VariantACommunityScreen> createState() =>
      _VariantACommunityScreenState();
}

class _VariantACommunityScreenState extends State<VariantACommunityScreen> {
  /// null = 전체.
  LabPostCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final posts = _filter == null
        ? kLabPosts
        : kLabPosts.where((p) => p.category == _filter).toList();

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
                const Text('커뮤니티', style: VariantATokens.headerTitle),
                const SizedBox(height: 16),
                // 카테고리 칩 행 — 가로 스크롤(작은 화면 오버플로 방지).
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryChip(
                        label: '전체',
                        active: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final c in LabPostCategory.values) ...[
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: _categoryLabel(c),
                          active: _filter == c,
                          onTap: () => setState(() => _filter = c),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: VariantATokens.tileGap),
                for (final p in posts) ...[
                  _PostCard(post: p),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _categoryLabel(LabPostCategory c) => switch (c) {
        LabPostCategory.notice => '공지',
        LabPostCategory.qna => '질문답변',
        LabPostCategory.free => '자유',
        LabPostCategory.wiki => '사육위키',
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// 카테고리 칩
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: active
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: VariantATokens.activeTile,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: VariantATokens.textOnActive,
                ),
              ),
            )
          : AGlassCapsule(
              child: Text(label, style: VariantATokens.tileStatus),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 게시글 유리 카드
// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final LabPost post;

  /// 카테고리 틴트 — 기기 틴트 팔레트 재사용(랩 격리 내 일관 색).
  Color get _tint => switch (post.category) {
        LabPostCategory.notice => VariantATokens.heaterTint,
        LabPostCategory.qna => VariantATokens.mistTint,
        LabPostCategory.free => VariantATokens.ledTint,
        LabPostCategory.wiki => VariantATokens.fanTint,
      };

  @override
  Widget build(BuildContext context) {
    return AGlass(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                post.categoryLabel,
                style: VariantATokens.tileStatus.copyWith(
                  color: _tint,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${labDaySection(post.at)} ${labHm(post.at)}',
                style: VariantATokens.tileStatus,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            post.title,
            style: VariantATokens.tileTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  post.author,
                  style: VariantATokens.tileStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chat_bubble_outline,
                  size: 14, color: VariantATokens.textSecondary),
              const SizedBox(width: 4),
              Text('${post.commentCount}', style: VariantATokens.tileStatus),
            ],
          ),
        ],
      ),
    );
  }
}
