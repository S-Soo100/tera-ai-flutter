import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/core/theme/app_theme.dart';
import 'package:vivanaut/features/community/presentation/clip_select_screen.dart';
import 'package:vivanaut/features/community/presentation/widgets/community_share_prompt.dart';
import 'package:vivanaut/features/my_cage/domain/favorite_clip.dart';

/// 북마크 저장 직후 커뮤니티 공유 제안(2026-09-24) — 공유하기는 클립 선택을
/// 건너뛰고 캡션 화면으로, "다시 묻지 않기"는 기기 로컬에 남는다.
class _Store implements CommunitySharePromptStore {
  @override
  bool dismissed = false;
  @override
  Future<void> dismiss() async => dismissed = true;
}

final _fav = FavoriteClip(
    clipId: 'clip-1',
    cameraId: 'cam',
    startedAt: DateTime(2026, 9, 24),
    durationSec: 12,
    filePath: '/tmp/clip-1.mp4',
    sizeBytes: 1,
    favoritedAt: DateTime(2026, 9, 24),
    ownerId: 'owner');

void main() {
  late _Store store;
  late List<Object?> pushedExtras;

  Future<void> pump(WidgetTester tester,
      {FavoriteClip? Function(String)? lookup, String clipId = 'clip-1'}) async {
    pushedExtras = [];
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
              body: Consumer(
                  builder: (context, ref, _) => TextButton(
                      key: const Key('trigger'),
                      onPressed: () => offerCommunityShare(context, ref, clipId),
                      child: const Text('go'))))),
      GoRoute(
          path: '/community-share/caption',
          builder: (context, state) {
            pushedExtras.add(state.extra);
            return const Scaffold(body: Text('caption-screen'));
          }),
    ]);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          communitySharePromptStoreProvider.overrideWithValue(store),
          communityShareClipLookupProvider.overrideWithValue(
              lookup ?? (id) => id == 'clip-1' ? _fav : null),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router)));
    await tester.pump();
  }

  Future<void> trigger(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('trigger')));
    await tester.pumpAndSettle();
  }

  setUp(() => store = _Store());

  testWidgets('공유하기 → 클립 선택을 건너뛰고 캡션 화면으로 그 북마크를 넘긴다',
      (tester) async {
    await pump(tester);
    await trigger(tester);
    expect(find.byKey(const Key('community_share_prompt')), findsOneWidget);
    await tester.tap(find.byKey(const Key('community_share_prompt_share')));
    await tester.pumpAndSettle();
    expect(find.text('caption-screen'), findsOneWidget);
    expect(pushedExtras, hasLength(1));
    expect((pushedExtras.single as ComposeDraft).fav.clipId, 'clip-1');
    expect(store.dismissed, isFalse);
  });

  testWidgets('나중에 + 다시 묻지 않기 → 이동 없이 기억하고, 다음부턴 묻지 않는다',
      (tester) async {
    await pump(tester);
    await trigger(tester);
    await tester.tap(find.byKey(const Key('community_share_prompt_dont_ask')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('community_share_prompt_later')));
    await tester.pumpAndSettle();
    expect(find.text('caption-screen'), findsNothing);
    expect(pushedExtras, isEmpty);
    expect(store.dismissed, isTrue);

    await trigger(tester);
    expect(find.byKey(const Key('community_share_prompt')), findsNothing);
  });

  testWidgets('바깥을 탭해 닫으면 답하지 않은 것 — 설정을 건드리지 않는다',
      (tester) async {
    await pump(tester);
    await trigger(tester);
    await tester.tap(find.byKey(const Key('community_share_prompt_dont_ask')));
    await tester.pump();
    await tester.tapAt(const Offset(10, 10)); // 시트 밖(barrier)
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community_share_prompt')), findsNothing);
    expect(store.dismissed, isFalse);
    expect(pushedExtras, isEmpty);
  });

  testWidgets('북마크 메타가 없으면(계정 전환 등) 묻지 않는다', (tester) async {
    await pump(tester, clipId: 'unknown');
    await trigger(tester);
    expect(find.byKey(const Key('community_share_prompt')), findsNothing);
  });
}
