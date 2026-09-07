import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivnanaut/features/my_cage/presentation/bookmarks_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivnanaut/features/my_cage/presentation/widgets/crecam_detail_top_bar.dart';

/// 북마크 상세(카메라 탭 재설계 T3) 위젯 테스트.
///
/// EasyLocalization 미탑재 → tr()는 키를 그대로 돌려준다(crecam_home_test 선례).
FavoriteClip _fav(String id, DateTime startedAt, DateTime favoritedAt) =>
    FavoriteClip(
      clipId: id,
      cameraId: 'cam-1',
      startedAt: startedAt,
      durationSec: 8,
      filePath: '/tmp/$id.mp4',
      sizeBytes: 1,
      favoritedAt: favoritedAt,
      ownerId: 'u1',
    );

/// favoritedAt desc(repository 정렬 계약) 픽스처 — c1이 최신.
final _favorites = [
  _fav('c1', DateTime(2026, 8, 12, 0, 50), DateTime(2026, 9, 2)),
  _fav('c2', DateTime(2026, 8, 11, 14, 5), DateTime(2026, 9, 1)),
];

String? pushedClipId;
List<String>? pushedPlaylist;

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const BookmarksScreen()),
        GoRoute(
          path: '/crecam/player/:clipId',
          builder: (_, state) {
            pushedClipId = state.pathParameters['clipId'];
            pushedPlaylist =
                (state.extra as List?)?.whereType<String>().toList();
            return const Scaffold(body: Center(child: Text('player-screen')));
          },
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  List<FavoriteClip>? favorites,
  DateTime? dayFilter,
}) async {
  pushedClipId = null;
  pushedPlaylist = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allFavoriteClipsProvider
            .overrideWith((ref) async => favorites ?? _favorites),
        motionThumbnailProvider.overrideWith((ref, clipId) async => null),
        if (dayFilter != null)
          bookmarksDayFilterProvider.overrideWith((ref) => dayFilter),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('카드 렌더 — 타이틀 + 시각 헤더(자정 12시·오후 표기)', (tester) async {
    await _pump(tester);
    expect(find.text('crecam_bookmarks_title'), findsOneWidget);
    // 00:50 → 오전 12:50 (0시 = 12시 표기 엣지)
    expect(
        find.text('2026. 08. 12 · time_am_fmt'), findsOneWidget);
    // 14:05 → 오후 2:05
    expect(find.text('2026. 08. 11 · time_pm_fmt'), findsOneWidget);
    expect(find.byKey(CrecamDetailTopBar.calendarButtonKey), findsOneWidget);
  });

  testWidgets('빈 상태 — clip_favorites_empty', (tester) async {
    await _pump(tester, favorites: const []);
    expect(find.text('clip_favorites_empty'), findsOneWidget);
  });

  testWidgets('카드 탭 → 세로 플레이어 + 전체 북마크 재생목록(정렬 순서)',
      (tester) async {
    await _pump(tester);
    // 카드 면적이 커서 카드 중심이 화면 밖일 수 있다 — 헤더 텍스트를 탭한다.
    final header = find.text('2026. 08. 11 · time_pm_fmt');
    await tester.ensureVisible(header);
    await tester.pumpAndSettle();
    await tester.tap(header);
    await tester.pumpAndSettle();
    expect(find.text('player-screen'), findsOneWidget);
    expect(pushedClipId, 'c2');
    expect(pushedPlaylist, ['c1', 'c2']);
  });

  testWidgets('날짜 필터 — 그 날짜만 + 칩 탭으로 해제', (tester) async {
    await _pump(tester, dayFilter: DateTime(2026, 8, 11));
    // 8/11 카드만 남는다.
    expect(find.byKey(const ValueKey('bookmark_card_c2')), findsOneWidget);
    expect(find.byKey(const ValueKey('bookmark_card_c1')), findsNothing);
    // 필터 칩 라벨 + 탭 → 해제(전체 복귀).
    final chip = find.byKey(CrecamDateFilterChip.chipKey);
    expect(chip, findsOneWidget);
    expect(find.text('2026. 8. 11'), findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bookmark_card_c1')), findsOneWidget);
    expect(find.byKey(CrecamDateFilterChip.chipKey), findsNothing);
  });

  testWidgets('필터 결과 0건 — 날짜 빈 문구(전체 빈 문구와 구분)', (tester) async {
    await _pump(tester, dayFilter: DateTime(2026, 1, 1));
    expect(find.text('crecam_home_empty_day'), findsOneWidget);
    expect(find.text('clip_favorites_empty'), findsNothing);
  });
}
