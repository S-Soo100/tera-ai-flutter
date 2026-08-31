import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import 'community_providers.dart';

/// 차단한 사용자 관리 (Task 12) — 프로필 > 차단한 사용자.
/// 해제하면 피드·댓글에 그 유저 글이 복귀한다.
///
/// Stateful인 이유: 해제는 await 뒤에 provider를 invalidate해야 하는데,
/// ConsumerWidget에는 `mounted`가 없어 화면 pop 후 ref 사용을 막을 수 없다.
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() =>
      _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  Future<void> _unblock(String userId) async {
    final messenger = ScaffoldMessenger.of(context); // async gap 전에 캡처
    try {
      await ref.read(communityRepositoryProvider).unblockUser(userId);
      if (!mounted) return;
      ref.invalidate(blockedProfilesProvider);
      // 피드·댓글에 복귀시킨다.
      ref.invalidate(communityFeedProvider);
    } catch (_) {
      messenger.showSnackBar(
          SnackBar(content: Text('community_unblock_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final blocked = ref.watch(blockedProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('community_blocked_users'.tr())),
      body: blocked.when(
        // 투명 위젯 + Shimmer 조합은 아무것도 안 그려진다(srcIn) — 공용 스켈레톤.
        loading: () => const SkeletonListLoading(itemCount: 3),
        error: (e, _) => Center(
            child:
                Text('community_feed_error'.tr(), style: glass.tileStatus)),
        data: (users) => users.isEmpty
            ? Center(
                child: Text('community_blocked_empty'.tr(),
                    style: glass.tileStatus))
            : ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, i) {
                  final u = users[i];
                  final name = u.name.isEmpty
                      ? 'community_author_unknown'.tr()
                      : u.name;
                  return ListTile(
                    leading: AccountAvatar(
                      tooltip: name,
                      onPressed: () {},
                      displayName: u.name,
                      imageUrl: u.avatarUrl,
                    ),
                    title: Text(name, style: glass.tileTitle),
                    trailing: TextButton(
                      onPressed: () => _unblock(u.id),
                      child: Text('community_unblock'.tr()),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
