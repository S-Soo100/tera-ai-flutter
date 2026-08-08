import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/pending_section.dart';
import '../../../shared/widgets/screen_header.dart';
import '../../profile/presentation/profile_providers.dart';
import '../domain/community_post.dart';
import 'community_providers.dart';

/// 커뮤니티 탭. 기획안 §4.5 — 공지사항 / QnA / 자유 게시판 / 사육 위키.
///
/// **지금 실물은 사육 위키 하나뿐이다.** 게시판은 Supabase에 테이블이 없어
/// 읽을 것도 쓸 것도 없다. 예전엔 지어낸 글 5건을 채워 그럴듯하게 보였는데,
/// 사용자에게는 **실재하는 커뮤니티로 보이는 거짓말**이었다. 지금은 카테고리
/// 구조만 세워두고 무엇이 준비 중인지 밝힌다.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  static const pendingKey = Key('community_board_pending');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCommunityCategoryProvider);
    final posts = ref.watch(communityPostsProvider);
    final profile = ref.watch(profileNotifierProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScreenHeader(
              title: 'community_title'.tr(),
              actions: [
                AccountAvatar(
                  tooltip: 'home_account'.tr(),
                  imageUrl: profile?.avatarUrl,
                  displayName: profile?.displayName,
                  onPressed: () => context.push('/profile'),
                ),
              ],
            ),
            _CategoryChips(
              selected: selected,
              onChanged: (cat) =>
                  ref.read(selectedCommunityCategoryProvider.notifier).state =
                      cat,
            ),
            const SizedBox(height: AppStyles.spacing12),
            Expanded(child: _CategoryBody(selected: selected, posts: posts)),
          ],
        ),
      ),
    );
  }
}

/// 카테고리별 본문.
///
/// 글쓰기 버튼(FAB)을 두지 않는다. 쓸 곳이 없는데 버튼만 있으면 누를 때마다
/// "준비 중"을 확인하게 된다 — **누르기 전에 알 수 있어야 한다.**
class _CategoryBody extends StatelessWidget {
  const _CategoryBody({required this.selected, required this.posts});

  final CommunityCategory selected;
  final List<CommunityPost> posts;

  /// 이 카테고리가 무엇을 담을 자리인지. 기획안 §4.5의 나열을 그대로 쓴다.
  String get _descKey => switch (selected) {
        CommunityCategory.notice => 'community_pending_notice',
        CommunityCategory.qna => 'community_pending_qna',
        CommunityCategory.free => 'community_pending_free',
        _ => 'community_pending_all',
      };

  @override
  Widget build(BuildContext context) {
    // 위키는 별도 탭이 아니라 커뮤니티 하위다(기획안 §4.5). 전체에서도 보인다.
    final showWiki = selected == CommunityCategory.wiki ||
        selected == CommunityCategory.all;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, AppStyles.spacing24),
      children: [
        if (showWiki) ...[
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
            child: _WikiShortcutCard(),
          ),
          const SizedBox(height: AppStyles.spacing12),
        ],
        // 위키만 고른 상태에서는 게시판 얘기를 꺼내지 않는다 — 여긴 이미 실물이다.
        if (selected != CommunityCategory.wiki)
          PendingSection(
            key: CommunityScreen.pendingKey,
            title: 'community_board_title'.tr(),
            description: _descKey.tr(),
            reason: 'community_pending_reason'.tr(),
          ),
        for (final post in posts)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppStyles.spacing16,
                AppStyles.spacing12, AppStyles.spacing16, 0),
            child: _PostCard(post: post),
          ),
      ],
    );
  }
}

// ── 카테고리 칩 ───────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.selected, required this.onChanged});

  final CommunityCategory selected;
  final ValueChanged<CommunityCategory> onChanged;

  String _label(CommunityCategory cat) {
    switch (cat) {
      case CommunityCategory.all:
        return 'community_cat_all'.tr();
      case CommunityCategory.notice:
        return 'community_cat_notice'.tr();
      case CommunityCategory.wiki:
        return 'community_cat_wiki'.tr();
      case CommunityCategory.qna:
        return 'community_cat_qna'.tr();
      case CommunityCategory.free:
        return 'community_cat_free'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppStyles.spacing16),
      child: Row(
        children: CommunityCategory.values.map((cat) {
          final isSelected = selected == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _Chip(
              label: _label(cat),
              selected: isSelected,
              onTap: () => onChanged(cat),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 하드코딩 검정(#222222)이었다. 선택 상태는 브랜드 메인컬러가 맡는다 —
    // 검정은 팔레트에 없는 색이라 다크 테마에서 배경과 붙어버렸다.
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── 게시글 카드 ─────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});
  final CommunityPost post;

  String _categoryLabel(CommunityCategory cat) {
    switch (cat) {
      case CommunityCategory.notice:
        return 'community_cat_notice'.tr();
      case CommunityCategory.wiki:
        return 'community_cat_wiki'.tr();
      case CommunityCategory.qna:
        return 'community_cat_qna'.tr();
      case CommunityCategory.free:
        return 'community_cat_free'.tr();
      case CommunityCategory.all:
        return '';
    }
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'time_just_now'.tr();
    if (diff.inMinutes < 60) {
      return 'time_minutes_ago'.tr(namedArgs: {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'time_hours_ago'.tr(namedArgs: {'n': '${diff.inHours}'});
    }
    return 'time_days_ago'.tr(namedArgs: {'n': '${diff.inDays}'});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _categoryLabel(post.category),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  post.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  '${post.authorName} · ${_relativeTime(post.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 28),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
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

// ── 사육위키 카테고리 진입 카드 (wiki 기능 통합) ──────────────────────────────

class _WikiShortcutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded,
                  color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'community_wiki_shortcut_title'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ShortcutChip(
                icon: Icons.search,
                label: 'community_wiki_action_search'.tr(),
                onTap: () => context.push('/search'),
              ),
              _ShortcutChip(
                icon: Icons.auto_stories_rounded,
                label: 'community_wiki_action_info'.tr(),
                onTap: () => context.push('/wiki'),
              ),
              _ShortcutChip(
                icon: Icons.biotech_rounded,
                label: 'community_wiki_action_morph_calc'.tr(),
                onTap: () => context.push('/wiki/crested-gecko/morph-calc'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
