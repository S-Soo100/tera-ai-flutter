import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/account_avatar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/community_post.dart';
import 'pet_tag_row.dart';

/// 피드 카드 — 작성자 / 썸네일(탭=재생) / 행동 칩 / 크레 행 / 캡션 / 좋아요·댓글.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.thumbnailUrl,
    this.petPhotoUrl,
    required this.onPlay,
    required this.onToggleLike,
    required this.onOpenComments,
    this.onDelete, // 내 글일 때만 non-null
  });

  final CommunityPost post;
  final String? thumbnailUrl;
  final String? petPhotoUrl;
  final VoidCallback onPlay;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;
  final VoidCallback? onDelete;

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

  String _duration(double? sec) {
    if (sec == null) return '';
    final s = sec.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final authorLabel = post.authorName.isEmpty
        ? 'community_author_unknown'.tr()
        : post.authorName;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
            child: Row(children: [
              // AccountAvatar는 onPressed·tooltip 필수 + 고정 28pt(내장 패딩 8) —
              // 유저별 모아보기(Task 13) 전까지는 no-op.
              AccountAvatar(
                tooltip: authorLabel,
                onPressed: () {},
                displayName: post.authorName,
                imageUrl: post.authorAvatarUrl,
              ),
              const SizedBox(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorLabel,
                        style: glass.tileTitle.copyWith(fontSize: 12.5)),
                    Text(_relativeTime(post.createdAt),
                        style: glass.tileStatus.copyWith(fontSize: 10.5)),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.more_horiz, color: glass.textTertiary),
                  onPressed: () => _showMenu(context),
                ),
            ]),
          ),
          GestureDetector(
            onTap: onPlay,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(fit: StackFit.expand, children: [
                if (thumbnailUrl != null)
                  Image.network(thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(glass))
                else
                  _thumbFallback(glass),
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
                if (post.action != null)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: glass.activeTile,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(post.action!,
                          style: glass.tileTitleActive.copyWith(fontSize: 10)),
                    ),
                  ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(_duration(post.durationSec),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ),
              ]),
            ),
          ),
          if (post.petName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: PetTagRow(
                  name: post.petName!, tag: post.petTag, photoUrl: petPhotoUrl),
            ),
          if (post.caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(post.caption!,
                  style: glass.tileStatus
                      .copyWith(fontSize: 12, color: glass.textPrimary)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 11),
            child: Row(children: [
              _ActionChip(
                icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                color: post.likedByMe ? glass.signalAlert : glass.textSecondary,
                label: '${post.likeCount}',
                onTap: onToggleLike,
              ),
              const SizedBox(width: 16),
              _ActionChip(
                icon: Icons.chat_bubble_outline,
                color: glass.textSecondary,
                label: '${post.commentCount}',
                onTap: onOpenComments,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback(GlassPalette glass) => ColoredBox(
        color: glass.overlayFaint,
        child: Icon(Icons.videocam_off_outlined,
            color: glass.textTertiary, size: 32),
      );

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text('community_delete_post'.tr()),
          onTap: () {
            Navigator.pop(ctx);
            onDelete?.call();
          },
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: glass.tileStatus.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}
