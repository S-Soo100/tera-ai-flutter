import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/data/clip_visibility_repository.dart';
import 'package:vivanaut/features/my_cage/data/passed_clip_feed_source.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivanaut/features/my_cage/domain/motion_clip_page.dart';
import 'package:vivanaut/features/my_cage/presentation/clip_visibility_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/player_view_providers.dart';

// 숨김 저장소 가짜·계정 override는 clip_visibility_feed_test.dart와 같은 방식(SOT).
class _Visibility implements ClipVisibilityRepository {
  @override
  Future<Set<String>> hiddenClipIds(String owner) async => <String>{};
  @override
  Future<void> hide(String owner, String clip) async {}
}

void main() {
  // 그리드와 플레이어 필름스트립이 같은 "통과 영상" 소스를 봐야 한다 —
  // 어긋나면 목록에 없던 영상이 플레이어에서 재생된다(정책 v2).
  test('플레이어 필름스트립 로더는 통과 영상 소스를 쓴다', () async {
    final at = DateTime.utc(2026, 9, 7, 15);
    const ClipFeedQuery query =
        (ownerId: 'owner', cameraId: 'cam', range: null);
    final container = ProviderContainer(overrides: [
      passedClipFeedSourceProvider.overrideWithValue(PassedClipFeedSource(
        listRefs: ({required cameraId, since, until, cursor}) async => (
          clipIds: ['p'],
          startedAts: [at],
          oldestStartedAt: at,
          nextCursor: null,
          hasMore: false,
        ),
        hydrate: (ids) async => [
          MotionClip(id: 'p', cameraId: 'cam', startedAt: at, durationSec: 5)
        ],
      )),
      currentUserProvider.overrideWithValue(User(
          id: 'owner',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01')),
      clipVisibilityRepositoryProvider.overrideWithValue(_Visibility()),
    ]);
    addTearDown(container.dispose);
    final page =
        await container.read(playerFeedPageLoaderProvider(query))(null);
    expect(page.items.single.id, 'p');
  });
}
