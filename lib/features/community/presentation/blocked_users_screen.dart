import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/account_avatar.dart';
import 'community_providers.dart';

/// 차단한 사용자 관리 (Task 12) — 프로필 > 차단한 사용자.
/// 해제하면 피드·댓글에 그 유저 글이 복귀한다.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    final blocked = ref.watch(blockedProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('community_blocked_users'.tr())),
      body: blocked.when(
        loading: () => Shimmer.fromColors(
          baseColor: glass.skeletonBase,
          highlightColor: glass.skeletonHighlight,
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 3; i++)
                const ListTile(
                    title: SizedBox(height: 14), subtitle: SizedBox(height: 12)),
            ],
          ),
        ),
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
                      onPressed: () async {
                        await ref
                            .read(communityRepositoryProvider)
                            .unblockUser(u.id);
                        ref.invalidate(blockedProfilesProvider);
                        // 피드·댓글에 복귀시킨다.
                        ref.invalidate(communityFeedProvider);
                      },
                      child: Text('community_unblock'.tr()),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
