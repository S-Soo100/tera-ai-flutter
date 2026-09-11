import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivnanaut/features/my_cage/data/highlight_banner_store.dart';
import 'package:vivnanaut/features/my_cage/domain/highlight_group.dart';
import 'package:vivnanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivnanaut/features/my_cage/presentation/highlights_controller.dart';
import 'package:vivnanaut/features/my_cage/presentation/highlights_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';

/// 하이라이트 상세 — /highlights/featured 전환(2026-09-11): day_key 묶음
/// (groupByDay) 단위 + 대표/후보 화면 위젯 테스트.
NightlyHighlight _h(
  String id,
  DateTime at, {
  String tier = 'candidate',
  String dayKey = '',
  int rank = 0,
}) =>
    NightlyHighlight(
      clipId: id,
      startedAt: at,
      source: 'rule',
      reason: '움직임 3.0초',
      tier: tier,
      dayKey: dayKey,
      episodeRank: rank,
      episodeClipCount: 4,
      episodeActivitySec: 42,
    );

class _FakeBannerStore implements HighlightBannerStore {
  _FakeBannerStore([this.value]);

  String? value;

  // 계정 격리(2026-09-07): 실 스토어는 ownerId별 키를 쓰지만, 위젯 테스트는
  // 단일 계정 시나리오라 fake는 ownerId를 무시한다.
  @override
  String? load(String? ownerId) => value;

  @override
  Future<void> save(String? ownerId, String groupKey) async {
    value = groupKey;
  }
}

/// 묶음 픽스처 2개 — dayA(최신, 대표 3 + 후보 2) + dayB(대표 1, 후보 0).
const _dayA = '2026-08-31';
const _dayB = '2026-08-30';
final _f1 = _h('f1', DateTime(2026, 8, 31, 23), tier: 'featured', dayKey: _dayA, rank: 1);
final _f2 = _h('f2', DateTime(2026, 9, 1, 2), tier: 'featured', dayKey: _dayA, rank: 2);
final _f3 = _h('f3', DateTime(2026, 8, 31, 21), tier: 'featured', dayKey: _dayA, rank: 3);
final _c1 = _h('c1', DateTime(2026, 8, 31, 22), dayKey: _dayA);
final _c2 = _h('c2', DateTime(2026, 9, 1, 1), dayKey: _dayA);
final _f4 = _h('f4', DateTime(2026, 8, 30, 23), tier: 'featured', dayKey: _dayB, rank: 1);

List<DayHighlightGroup> _groups() =>
    groupByDay([_c1, _f2, _f4, _f1, _c2, _f3]);

String? pushedClipId;
List<String>? pushedPlaylist;

GoRouter _router() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const HighlightsScreen()),
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
  List<DayHighlightGroup>? groups,
  required _FakeBannerStore store,
}) async {
  pushedClipId = null;
  pushedPlaylist = null;
  // 대표 카드는 전폭 16:9라 기본 600px 뷰포트엔 한 장도 안 담긴다 — lazy
  // ListView가 아래 위젯을 아예 안 만들어 find가 0을 돌려준다. 길게 편다.
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        highlightGroupsProvider.overrideWith((ref) async => groups ?? _groups()),
        highlightBannerStoreProvider.overrideWith((ref) => store),
        motionThumbnailProvider.overrideWith((ref, clipId) async => null),
        isFavoriteProvider.overrideWith((ref, id) => false),
        // dismiss notifier가 계정 id를 watch한다(격리 2026-09-07) — 테스트는
        // Supabase 미초기화라 실 체인 대신 미로그인으로 고정.
        currentUserProvider.overrideWith((ref) => null),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('groupByDay — 서버 day_key 묶음', () {
    test('빈 목록 → 빈 그룹', () {
      expect(groupByDay(const []), isEmpty);
    });

    test('day_key 2개 → 묶음 2개, 최신 day_key 먼저', () {
      final groups = _groups();
      expect(groups, hasLength(2));
      expect(groups[0].dayKey, _dayA);
      expect(groups[1].dayKey, _dayB);
    });

    test('묶음 안 대표는 episode.rank 오름차순, 후보는 startedAt 내림차순', () {
      final g = _groups().first;
      expect(g.featured.map((h) => h.clipId), ['f1', 'f2', 'f3']);
      // c2(9/1 01:00)가 c1(8/31 22:00)보다 최신.
      expect(g.candidates.map((h) => h.clipId), ['c2', 'c1']);
    });

    test('그룹 key = 가장 최신 대표 startedAt ISO — 새 대표가 오면 바뀐다', () {
      final g = _groups().first;
      // 대표 중 최신은 f2(9/1 02:00) — rank 1위(f1)가 아니다.
      expect(highlightGroupKey(g), _f2.startedAt.toIso8601String());
      expect(latestFeaturedAt(g), _f2.startedAt);
    });

    test('대표가 없는 묶음(방어) → key는 후보 최신 startedAt', () {
      final groups = groupByDay([_c1, _c2]);
      expect(highlightGroupKey(groups.single), _c2.startedAt.toIso8601String());
    });
  });

  group('parseDayKey', () {
    test('YYYY-MM-DD → 로컬 자정', () {
      expect(parseDayKey('2026-09-08'), DateTime(2026, 9, 8));
    });
    test('계약 밖 형식 → null', () {
      expect(parseDayKey('2026/09/08'), isNull);
      expect(parseDayKey(''), isNull);
    });
  });

  group('HighlightsScreen', () {
    testWidgets('대표 카드만 렌더 — 후보는 데이터가 있어도 노출 안 함(2026-09-11)',
        (tester) async {
      // 배너를 dismiss된 상태로 시작해 섹션이 화면 안에 오게 한다.
      // (실 조회는 tier=featured라 후보가 안 오지만, 픽스처에 후보를 섞어
      // "와도 안 그린다"를 고정한다.)
      final store = _FakeBannerStore(highlightGroupKey(_groups().first));
      await _pump(tester, store: store);
      expect(find.byKey(const ValueKey('highlight_featured_f1')),
          findsOneWidget);
      // 후보 셀·더 보기 버튼은 어디에도 없다.
      expect(find.byKey(const ValueKey('highlight_cell_c1')), findsNothing);
      expect(find.byKey(const ValueKey('highlight_cell_c2')), findsNothing);
      expect(find.textContaining('후보'), findsNothing);
      // 지난 날짜 묶음 헤더는 "M월 d일 밤" 서식 키(테스트는 미번역 키 노출).
      expect(find.text('crecam_highlights_night_of'), findsWidgets);
    });

    testWidgets('대표 6장 이상(하루 상한 폐지 2026-09-11 후속)도 전부 렌더',
        (tester) async {
      // 새 기준: 하루 상한 없음(10개 안팎, 최대 16) — 3장 가정 레이아웃이
      // 없는지 확인. 7장을 넣고 첫/끝 카드가 스크롤로 모두 닿는지 본다.
      final many = groupByDay([
        for (var i = 1; i <= 7; i++)
          _h('m$i', DateTime(2026, 8, 31, 20 + (i % 4), i),
              tier: 'featured', dayKey: _dayA, rank: i),
      ]);
      final store = _FakeBannerStore(highlightGroupKey(many.first));
      await _pump(tester, groups: many, store: store);
      expect(
          find.byKey(const ValueKey('highlight_featured_m1')), findsOneWidget);
      final last = find.byKey(const ValueKey('highlight_featured_m7'));
      await tester.scrollUntilVisible(last, 400,
          scrollable: find.byType(Scrollable).first);
      expect(last, findsOneWidget);
    });

    testWidgets('어젯밤 day_key 묶음 → "어젯밤" 헤더', (tester) async {
      final dayKey = lastNightDayKey(DateTime.now());
      final groups = groupByDay([
        _h('x1', DateTime.now(), tier: 'featured', dayKey: dayKey, rank: 1),
      ]);
      final store = _FakeBannerStore(highlightGroupKey(groups.first));
      await _pump(tester, groups: groups, store: store);
      expect(find.text('crecam_highlights_last_night'), findsOneWidget);
    });

    testWidgets('도착 배너(미dismiss) — X → 숨김 + 스토어에 최신 대표 ISO 저장',
        (tester) async {
      final store = _FakeBannerStore();
      await _pump(tester, store: store);
      expect(find.byKey(HighlightsScreen.bannerKey), findsOneWidget);
      await tester.tap(find.byKey(HighlightsScreen.bannerCloseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(HighlightsScreen.bannerKey), findsNothing);
      expect(store.value, _f2.startedAt.toIso8601String()); // 최신 대표 = f2
    });

    testWidgets('같은 그룹 key가 이미 dismiss → 재방문에도 배너 숨김',
        (tester) async {
      final store = _FakeBannerStore(_f2.startedAt.toIso8601String());
      await _pump(tester, store: store);
      expect(find.byKey(HighlightsScreen.bannerKey), findsNothing);
    });

    testWidgets('옛 key dismiss(새 대표 도착) → 배너 다시 표시', (tester) async {
      final store = _FakeBannerStore(_f1.startedAt.toIso8601String());
      await _pump(tester, store: store);
      expect(find.byKey(HighlightsScreen.bannerKey), findsOneWidget);
    });

    testWidgets('빈 상태 — crecam_highlights_empty', (tester) async {
      await _pump(tester, groups: const [], store: _FakeBannerStore());
      expect(find.text('crecam_highlights_empty'), findsOneWidget);
      expect(find.byKey(HighlightsScreen.bannerKey), findsNothing);
    });

    testWidgets('대표 카드 탭 → 플레이어(재생목록 = 그 묶음 대표, rank 순)',
        (tester) async {
      final store = _FakeBannerStore(highlightGroupKey(_groups().first));
      await _pump(tester, store: store);
      final card = find.byKey(const ValueKey('highlight_featured_f2'));
      await tester.scrollUntilVisible(card, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text('player-screen'), findsOneWidget);
      expect(pushedClipId, 'f2');
      expect(pushedPlaylist, ['f1', 'f2', 'f3']);
    });

    testWidgets('배너 탭(X 제외) → 대표 1위부터 대표 재생목록', (tester) async {
      await _pump(tester, store: _FakeBannerStore());
      await tester.tap(find.text('crecam_highlights_banner_title'));
      await tester.pumpAndSettle();
      expect(pushedClipId, 'f1'); // 배너 얼굴 = rank 1위
      expect(pushedPlaylist, ['f1', 'f2', 'f3']);
    });
  });
}
