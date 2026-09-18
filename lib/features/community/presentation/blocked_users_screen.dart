import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../../../shared/widgets/viva_modal.dart';
import '../../my_cage/presentation/widgets/clip_toast.dart';
import '../../my_cage/presentation/widgets/management_widgets.dart';
import '../../profile/presentation/widgets/my_page_widgets.dart';
import 'community_providers.dart';

/// 차단한 사용자(Figma Commu_block 1142:9422) — 마이 페이지 > 차단한 사용자.
/// 카드 369×76 흰색 r12(간격 12): 아바타 52, 닉네임 16/700, 부제 14/500,
/// 오른쪽 "차단됨" 16/600 `#C00306`. 카드를 누르면 "차단을 해제하시겠습니까?"
/// 모달 → 해제 → 토스트 "차단 해제 완료". 해제하면 피드·댓글에 그 유저 글이
/// 복귀한다.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  static Key cardKey(String id) => Key('blocked_card_$id');

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  Future<void> _unblock(String userId) async {
    final ok = await showVivaModal(context,
        message: 'blocked_unblock_question'.tr(),
        cancelLabel: 'common_cancel'.tr(),
        confirmLabel: 'blocked_unblock_confirm'.tr());
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context); // async gap 전에 캡처
    try {
      await ref.read(communityRepositoryProvider).unblockUser(userId);
      if (!mounted) return;
      ref.invalidate(blockedProfilesProvider);
      // 피드·댓글에 복귀시킨다.
      ref.invalidate(communityFeedProvider);
      showClipToast(context, text: 'blocked_unblock_done'.tr());
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text('community_unblock_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final blocked = ref.watch(blockedProfilesProvider);
    return MyPageScaffold(
      title: 'mypage_blocked_title'.tr(),
      // 원본 첫 카드 y127 = 헤더 106 + 21.
      padding: const EdgeInsets.fromLTRB(12, 21, 12, 24),
      child: blocked.when(
        loading: () => const SkeletonListLoading(itemCount: 3),
        error: (e, _) => Center(
            child: Text('community_feed_error'.tr(),
                style: managementStyle(context, color: glass.textTertiary))),
        data: (users) => users.isEmpty
            ? Container(
                height: 64,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                    color: glass.surfaceHeader,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('community_blocked_empty'.tr(),
                    style: managementStyle(context,
                        color: glass.textTertiary)))
            : Column(children: [
                for (final (i, u) in users.indexed) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Material(
                      key: BlockedUsersScreen.cardKey(u.id),
                      color: glass.surfaceHeader,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _unblock(u.id),
                          child: SizedBox(
                              height: 76,
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  child: Row(children: [
                                    MyPageAvatar(
                                        size: 52, imageUrl: u.avatarUrl),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(
                                              u.name.isEmpty
                                                  ? 'community_author_unknown'
                                                      .tr()
                                                  : u.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: managementStyle(context,
                                                  weight: FontWeight.w700)),
                                          const SizedBox(height: 8),
                                          Text('commu_profile_exp_hidden'.tr(),
                                              style: managementStyle(context,
                                                  size: 14,
                                                  color: glass.textTertiary)),
                                        ])),
                                    const SizedBox(width: 8),
                                    Text('blocked_user_badge'.tr(),
                                        style: managementStyle(context,
                                            weight: FontWeight.w600,
                                            color: glass.navSelected)),
                                  ]))))),
                ],
              ]),
      ),
    );
  }
}
