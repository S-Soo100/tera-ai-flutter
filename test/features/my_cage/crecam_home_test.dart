import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/home_header_bar.dart';
import 'package:vivnanaut/features/my_cage/domain/favorite_clip.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivnanaut/features/my_cage/domain/terra_camera.dart';
import 'package:vivnanaut/features/my_cage/presentation/crecam_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';
import 'package:vivnanaut/features/my_cage/presentation/widgets/camera_live_area.dart';

/// Camera Home(카메라 탭 재설계 T2) 위젯 테스트.
///
/// 카메라는 **오프라인** 픽스처를 쓴다 — 온라인이면 WebRtcLiveView가 실제
/// 시그널링을 시도한다(홈 home_layout_test가 캠 없는 세트를 쓰는 것과 같은
/// 이유). 클립 그리드는 카메라 온라인 여부와 무관하게 로드된다.
const _cameraId = 'cam-1';

TerraCamera _offlineCamera() => TerraCamera(
      id: _cameraId,
      cameraId: 'p4cam-1',
      name: '테스트캠',
      isOnline: false,
      createdAt: DateTime(2026, 1, 1),
    );

final _day = DateTime(2026, 8, 31);

MotionClip _clip(String id, int hour, int minute) => MotionClip(
      id: id,
      cameraId: _cameraId,
      startedAt: DateTime(2026, 8, 31, hour, minute),
      durationSec: 8,
    );

/// 시간 내림차순 재생목록 기대값: c1(10:15) → c2(10:05) → c3(08:30).
final _clips = [_clip('c2', 10, 5), _clip('c3', 8, 30), _clip('c1', 10, 15)];

String? pushedClipId;
List<String>? pushedPlaylist;

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const CrecamScreen()),
        GoRoute(
          path: '/crecam/player/:clipId',
          builder: (_, state) {
            pushedClipId = state.pathParameters['clipId'];
            pushedPlaylist =
                (state.extra as List?)?.whereType<String>().toList();
            return const Scaffold(body: Center(child: Text('player-screen')));
          },
        ),
        GoRoute(
          path: '/crecam/highlights',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('highlights-screen'))),
        ),
        GoRoute(
          path: '/crecam/bookmarks',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('bookmarks-screen'))),
        ),
        GoRoute(
          path: '/crecam/cameras/pair',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('pair-screen'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('profile-screen'))),
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester, {
  List<TerraCamera>? cameras,
  List<MotionClip>? clips,
  DateTime? latestHighlightAt,
  List<FavoriteClip>? favorites,
}) async {
  pushedClipId = null;
  pushedPlaylist = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        enclosureSetsProvider.overrideWith((ref) async => const []),
        camerasProvider.overrideWith(
            (ref) => Stream.value(cameras ?? [_offlineCamera()])),
        crecamDayProvider.overrideWith((ref) => _day),
        motionClipsProvider
            .overrideWith((ref, key) async => clips ?? _clips),
        motionThumbnailProvider.overrideWith((ref, clipId) async => null),
        latestHighlightAtProvider
            .overrideWith((ref) async => latestHighlightAt),
        allFavoriteClipsProvider
            .overrideWith((ref) async => favorites ?? const []),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('헤더 + 엔트리 카드 2개(하이라이트/북마크) 렌더', (tester) async {
    await _pump(tester);
    expect(find.byType(HomeHeaderBar), findsOneWidget);
    expect(find.byKey(CrecamScreen.highlightCardKey), findsOneWidget);
    expect(find.byKey(CrecamScreen.bookmarkCardKey), findsOneWidget);
    expect(find.text('crecam_home_highlights'), findsOneWidget);
    expect(find.text('crecam_home_bookmarks'), findsOneWidget);
    // 하이라이트·북마크 둘 다 없음 → "아직 없어요" ×2.
    expect(find.text('crecam_home_no_updates'), findsNWidgets(2));
    // 기간 설정 버튼(선택일이 오늘이 아니면 날짜 라벨).
    expect(find.byKey(CrecamScreen.periodButtonKey), findsOneWidget);
    expect(find.text('2026. 8. 31'), findsWidgets);
  });

  testWidgets('엔트리 카드 탭 → 하이라이트/북마크 라우트', (tester) async {
    await _pump(tester);
    // 라이브 면(369:271)이 테스트 서피스 대부분을 차지해 카드가 폴드 밖이다.
    final card = find.byKey(CrecamScreen.highlightCardKey);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('highlights-screen'), findsOneWidget);
  });

  testWidgets('카메라 0대 → 빈 상태 카드 + 페어링 진입', (tester) async {
    await _pump(tester, cameras: const []);
    expect(find.byKey(CameraLiveArea.emptyCardKey), findsOneWidget);
    expect(find.text('my_cage_empty_title'), findsOneWidget);
    await tester.tap(find.text('my_cage_add_camera'));
    await tester.pumpAndSettle();
    expect(find.text('pair-screen'), findsOneWidget);
  });

  testWidgets('오프라인 카메라 → WebRTC 시도 없이 오프라인 페이지', (tester) async {
    await _pump(tester);
    expect(find.byKey(CameraLiveArea.offlinePaneKey), findsOneWidget);
    expect(find.text('crecam_camera_offline'), findsOneWidget);
    // 확장 버튼은 오프라인이어도 카메라 상세로 갈 수 있게 노출.
    expect(find.byKey(CameraLiveArea.expandButtonKey), findsOneWidget);
  });

  testWidgets('시간 그룹 헤더 — 최신 시간부터, 날짜는 첫 그룹만', (tester) async {
    await _pump(tester);
    // EasyLocalization 없이 tr()는 키를 돌려준다 → "crecam_player_am 10:00".
    expect(find.text('crecam_player_am 10:00'), findsOneWidget);
    expect(find.text('crecam_player_am 8:00'), findsOneWidget);
    // 첫 그룹(10시)에만 날짜 라벨 — 기간 버튼 라벨과 합쳐 2개.
    expect(find.text('2026. 8. 31'), findsNWidgets(2));
  });

  testWidgets('클립 0건 날짜 → 빈 상태 문구', (tester) async {
    await _pump(tester, clips: const []);
    expect(find.text('crecam_home_empty_day'), findsOneWidget);
  });

  testWidgets('셀 탭 → 세로 플레이어 + 그날 전체 재생목록(시간 내림차순)',
      (tester) async {
    await _pump(tester);
    final cell = find.byKey(const ValueKey('crecam_clip_c3'));
    await tester.ensureVisible(cell);
    await tester.tap(cell);
    await tester.pumpAndSettle();
    expect(find.text('player-screen'), findsOneWidget);
    expect(pushedClipId, 'c3');
    expect(pushedPlaylist, ['c1', 'c2', 'c3']);
  });

  testWidgets('최신 즐겨찾기 시각 → 북마크 카드 "업데이트" 서브타이틀',
      (tester) async {
    await _pump(tester, favorites: [
      FavoriteClip(
        clipId: 'c1',
        cameraId: _cameraId,
        startedAt: DateTime(2026, 8, 31, 10, 15),
        durationSec: 8,
        filePath: '/tmp/c1.mp4',
        sizeBytes: 1,
        favoritedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ownerId: 'u1',
      ),
    ]);
    // timeAgo → "time_minutes_ago" 키 → crecam_home_updated 조합.
    expect(find.textContaining('crecam_home_updated'), findsOneWidget);
  });
}
