import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/account_avatar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/community_post.dart';
import '../community_providers.dart';
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
    required this.isMine,
    this.onDelete, // 내 글 메뉴
    this.onReport, // 사유('spam'…) 선택 후 호출 — 타인 글 메뉴
    this.onBlock, // 타인 글 메뉴 (Task 12에서 배선 — null이면 항목 미표시)
    this.onOpenAuthor, // 작성자 행 탭 = 유저별 모아보기 (Task 13)
  });

  final CommunityPost post;
  final String? thumbnailUrl;
  final String? petPhotoUrl;
  final VoidCallback onPlay;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;
  final bool isMine;
  final VoidCallback? onDelete;
  final void Function(String reason)? onReport;
  final VoidCallback? onBlock;
  final VoidCallback? onOpenAuthor;

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
              // 작성자 영역 탭 = 유저별 모아보기 (Task 13).
              AccountAvatar(
                tooltip: authorLabel,
                onPressed: onOpenAuthor ?? () {},
                displayName: post.authorName,
                imageUrl: post.authorAvatarUrl,
              ),
              const SizedBox(width: 1),
              Expanded(
                child: GestureDetector(
                  onTap: onOpenAuthor,
                  behavior: HitTestBehavior.opaque,
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
              ),
              // ⋯ 메뉴는 항상 노출 — 내 글 [삭제], 타인 글 [신고]·[차단] (Apple 1.2).
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
                // 자동재생 (Task 14) — 60% 이상 보이는 카드 1개만 muted 루프.
                _AutoplayThumb(
                  post: post,
                  thumbnailUrl: thumbnailUrl,
                  fallback: _thumbFallback(glass),
                ),
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (isMine)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('community_delete_post'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text('community_report'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                showReportReasonsSheet(context, onReport);
              },
            ),
            if (onBlock != null)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text('community_block_user'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  onBlock?.call();
                },
              ),
          ],
        ]),
      ),
    );
  }
}

/// 신고 사유 4종 시트 — 게시물·댓글 공용 (Task 11).
void showReportReasonsSheet(
    BuildContext context, void Function(String reason)? onReport) {
  const reasons = ['spam', 'inappropriate', 'animal_abuse', 'other'];
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final r in reasons)
          ListTile(
            title: Text('community_report_$r'.tr()),
            onTap: () {
              Navigator.pop(ctx);
              onReport?.call(r);
            },
          ),
      ]),
    ),
  );
}

/// 자동재생 썸네일 (Task 14) — 가시성 60% 초과 시 활성 후보, 40% 미만이면 해제.
/// 활성 게시물 1개만 [_InlinePlayer]를 마운트한다(전역 단일 controller).
/// 비활성 전환 = _InlinePlayer 언마운트 = 즉시 dispose (controller 누적 OOM 방지).
class _AutoplayThumb extends ConsumerStatefulWidget {
  const _AutoplayThumb({
    required this.post,
    required this.thumbnailUrl,
    required this.fallback,
  });

  final CommunityPost post;
  final String? thumbnailUrl;
  final Widget fallback;

  @override
  ConsumerState<_AutoplayThumb> createState() => _AutoplayThumbState();
}

class _AutoplayThumbState extends ConsumerState<_AutoplayThumb> {
  void _onVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final active = ref.read(activeAutoplayPostIdProvider.notifier);
    if (info.visibleFraction > 0.6) {
      active.state = widget.post.id;
    } else if (info.visibleFraction < 0.4 && active.state == widget.post.id) {
      active.state = null;
    }
  }

  @override
  void dispose() {
    // 카드가 리스트에서 빠질 때 활성 상태를 남기지 않는다. 언마운트는 빌드
    // 정리 중에 올 수 있어 provider 변경은 microtask로 미룬다(빌드 중 변경 금지).
    final active = ref.read(activeAutoplayPostIdProvider.notifier);
    final myId = widget.post.id;
    Future.microtask(() {
      try {
        if (active.state == myId) active.state = null;
      } catch (_) {
        // ProviderScope 해체 중이면 무시.
      }
    });
    super.dispose();
  }

  Widget _thumb() => widget.thumbnailUrl != null
      ? Image.network(widget.thumbnailUrl!,
          fit: BoxFit.cover, errorBuilder: (_, __, ___) => widget.fallback)
      : widget.fallback;

  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(activeAutoplayPostIdProvider) == widget.post.id;
    return VisibilityDetector(
      key: Key('post-autoplay-${widget.post.id}'),
      onVisibilityChanged: _onVisibility,
      child: isActive
          ? _InlinePlayer(
              videoPath: widget.post.videoPath, placeholder: _thumb())
          : _thumb(),
    );
  }
}

/// muted 루프 인라인 플레이어 — controls 없음, 탭은 부모(전체화면 재생)로 통과.
class _InlinePlayer extends ConsumerStatefulWidget {
  const _InlinePlayer({required this.videoPath, required this.placeholder});
  final String videoPath;
  final Widget placeholder;

  @override
  ConsumerState<_InlinePlayer> createState() => _InlinePlayerState();
}

class _InlinePlayerState extends ConsumerState<_InlinePlayer> {
  VideoPlayerController? _controller;
  bool _initStarted = false;
  bool _ready = false;

  Future<void> _init(String url) async {
    _initStarted = true;
    // hoist — initialize 실패 시에도 dispose (controller leak 교훈).
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = controller;
    try {
      await controller.setVolume(0); // muted
      await controller.setLooping(true);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        _controller = null;
        return;
      }
      await controller.play();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      await controller.dispose();
      if (mounted) {
        setState(() {
          _controller = null;
          _ready = false;
        });
      } else {
        _controller = null;
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose(); // 비가시 전환 = 즉시 해제
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = ref.watch(postVideoUrlProvider(widget.videoPath)).valueOrNull;
    if (url != null && !_initStarted) _init(url);
    if (!_ready || _controller == null) return widget.placeholder;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _controller!.value.size.width,
        height: _controller!.value.size.height,
        // 탭이 전체화면 재생(onPlay)으로 가도록 포인터를 먹지 않는다.
        child: IgnorePointer(child: VideoPlayer(_controller!)),
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
