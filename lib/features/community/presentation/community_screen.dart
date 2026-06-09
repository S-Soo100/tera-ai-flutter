import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/community_post.dart';
import 'community_providers.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCommunityCategoryProvider);
    final posts = ref.watch(communityPostsProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(
          'community_title'.tr(),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF222222),
        foregroundColor: Colors.white,
        onPressed: () => _showComingSoon(context),
        tooltip: 'community_new_post'.tr(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CategoryChips(
            selected: selected,
            onChanged: (cat) =>
                ref.read(selectedCommunityCategoryProvider.notifier).state = cat,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _PostsList(
              posts: posts,
              showWikiShortcut: selected == CommunityCategory.wiki,
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('community_new_post_coming_soon'.tr()),
        duration: const Duration(seconds: 2),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
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
    const blackColor = Color(0xFF222222);
    final bg = selected
        ? blackColor
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    final fg = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;
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

// ── 게시글 리스트 ────────────────────────────────────────────────────────────

class _PostsList extends StatelessWidget {
  const _PostsList({required this.posts, required this.showWikiShortcut});
  final List<CommunityPost> posts;
  final bool showWikiShortcut;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty && !showWikiShortcut) {
      return Center(
        child: Text(
          'community_empty'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      children: [
        if (showWikiShortcut) ...[
          _WikiShortcutCard(),
          const SizedBox(height: 12),
        ],
        ...posts.map((post) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PostCard(post: post),
            )),
      ],
    );
  }
}

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
