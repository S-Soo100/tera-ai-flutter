import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/features/my_cage/data/highlight_banner_store.dart';
import 'package:vivnanaut/features/my_cage/domain/highlight_group.dart';
import 'package:vivnanaut/features/my_cage/domain/nightly_highlight.dart';
import 'package:vivnanaut/features/my_cage/presentation/highlights_screen.dart';
import 'package:vivnanaut/features/my_cage/presentation/my_cage_providers.dart';

/// 하이라이트 상세(카메라 탭 재설계 T4) — 72h 그룹핑 단위 + 배너 위젯 테스트.
NightlyHighlight _h(String id, DateTime at) => NightlyHighlight(
      clipId: id,
      startedAt: at,
      vlmAction: 'motion',
      confidence: 0.9,
      careLevel: 'care',
    );

class _FakeBannerStore implements HighlightBannerStore {
  _FakeBannerStore([this.value]);

  String? value;

  @override
  String? load() => value;

  @override
  Future<void> save(String groupKey) async {
    value = groupKey;
  }
}

/// 묶음 픽스처 2개 — g1(최신, 8/28~8/31 3건) + g2(8/20 1건).
final _h1 = _h('h1', DateTime(2026, 8, 31, 10));
final _h2 = _h('h2', DateTime(2026, 8, 30, 9));
final _h3 = _h('h3', DateTime(2026, 8, 28, 11));
final _h4 = _h('h4', DateTime(2026, 8, 20, 22));

List<HighlightGroup> _groups() => [
      (from: _h3.startedAt, to: _h1.startedAt, items: [_h1, _h2, _h3]),
      (from: _h4.startedAt, to: _h4.startedAt, items: [_h4]),
    ];

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
  List<HighlightGroup>? groups,
  required _FakeBannerStore store,
}) async {
  pushedClipId = null;
  pushedPlaylist = null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        highlightGroupsProvider.overrideWith((ref) async => groups ?? _groups()),
        highlightBannerStoreProvider.overrideWith((ref) => store),
        motionThumbnailProvider.overrideWith((ref, clipId) async => null),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('groupHighlights — 72h 창 그룹핑', () {
    final base = DateTime(2026, 8, 31, 12);

    test('빈 목록 → 빈 그룹', () {
      expect(groupHighlights(const []), isEmpty);
    });

    test('앵커에서 71h 이내 → 같은 그룹', () {
      final a = _h('a', base);
      final b = _h('b', base.subtract(const Duration(hours: 71)));
      final groups = groupHighlights([b, a]); // 입력 순서 무관(내부 정렬)
      expect(groups, hasLength(1));
      expect(groups.first.items.map((h) => h.clipId), ['a', 'b']); // 내림차순
      expect(groups.first.to, base);
      expect(groups.first.from, b.startedAt);
    });

    test('앵커에서 73h → 다음 그룹(새 앵커)', () {
      final a = _h('a', base);
      final b = _h('b', base.subtract(const Duration(hours: 73)));
      final groups = groupHighlights([a, b]);
      expect(groups, hasLength(2));
      expect(groups[0].items.single.clipId, 'a');
      expect(groups[1].items.single.clipId, 'b');
      // 다음 그룹의 앵커는 b — from=to=b.
      expect(groups[1].from, b.startedAt);
      expect(groups[1].to, b.startedAt);
    });

    test('연쇄 — 창을 벗어난 항목이 새 앵커가 되어 다시 71h를 담는다', () {
      final a = _h('a', base);
      final b = _h('b', base.subtract(const Duration(hours: 73)));
      final c = _h('c',
          base.subtract(const Duration(hours: 73 + 71))); // b 앵커에서 71h
      final groups = groupHighlights([c, a, b]);
      expect(groups, hasLength(2));
      expect(groups[0].items.map((h) => h.clipId), ['a']);
      expect(groups[1].items.map((h) => h.clipId), ['b', 'c']);
    });

    test('그룹 key = from ISO 문자열', () {
      final a = _h('a', base);
      final groups = groupHighlights([a]);
      expect(highlightGroupKey(groups.single), base.toIso8601String());
    });
  });

  group('HighlightsScreen', () {
    testWidgets('도착 배너(미dismiss) + 묶음 섹션 헤더', (tester) async {
      await _pump(tester, store: _FakeBannerStore());
      expect(find.byKey(HighlightsScreen.bannerKey), findsOneWidget);
      expect(find.text('crecam_highlights_banner_title'), findsOneWidget);
      // 배너 기간(패딩 표기) + 섹션 헤더(비패딩 표기).
      expect(find.text('2026. 08. 28 - 08. 31'), findsOneWidget);
      expect(find.text('2026. 8. 28 - 8. 31'), findsOneWidget);
      // 단일 날짜 묶음은 날짜 하나만 — ListView 지연 빌드라 스크롤해서 확인.
      await tester.scrollUntilVisible(find.text('2026. 8. 20'), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('2026. 8. 20'), findsOneWidget);
    });

    testWidgets('배너 X → 숨김 + 스토어에 그룹 key 저장', (tester) async {
      final store = _FakeBannerStore();
      await _pump(tester, store: store);
      await tester.tap(find.byKey(HighlightsScreen.bannerCloseKey));
      await tester.pumpAndSettle();
      expect(find.byKey(HighlightsScreen.bannerKey), findsNothing);
      expect(store.value, _h3.startedAt.toIso8601String()); // key = from ISO
      // 섹션은 그대로 남는다.
      expect(find.text('2026. 8. 28 - 8. 31'), findsOneWidget);
    });

    testWidgets('같은 그룹 key가 이미 dismiss → 재방문에도 배너 숨김',
        (tester) async {
      final store = _FakeBannerStore(_h3.startedAt.toIso8601String());
      await _pump(tester, store: store);
      expect(find.byKey(HighlightsScreen.bannerKey), findsNothing);
    });

    testWidgets('다른(옛) 그룹 key dismiss → 새 그룹 배너는 다시 표시',
        (tester) async {
      final store = _FakeBannerStore(_h4.startedAt.toIso8601String());
      await _pump(tester, store: store);
      expect(find.byKey(HighlightsScreen.bannerKey), findsOneWidget);
    });

    testWidgets('빈 상태 — crecam_highlights_empty', (tester) async {
      await _pump(tester, groups: const [], store: _FakeBannerStore());
      expect(find.text('crecam_highlights_empty'), findsOneWidget);
      expect(find.byKey(HighlightsScreen.bannerKey), findsNothing);
    });

    testWidgets('셀 탭 → 세로 플레이어 + 그 묶음 재생목록(내림차순)',
        (tester) async {
      // 배너를 dismiss된 상태로 시작해 셀이 화면 안에 오게 한다.
      final store = _FakeBannerStore(_h3.startedAt.toIso8601String());
      await _pump(tester, store: store);
      final cell = find.byKey(const ValueKey('highlight_cell_h2'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await tester.pumpAndSettle();
      expect(find.text('player-screen'), findsOneWidget);
      expect(pushedClipId, 'h2');
      expect(pushedPlaylist, ['h1', 'h2', 'h3']);
    });

    testWidgets('배너 탭(X 제외) → 그 묶음 재생목록으로 플레이어', (tester) async {
      await _pump(tester, store: _FakeBannerStore());
      await tester.tap(find.text('crecam_highlights_banner_title'));
      await tester.pumpAndSettle();
      expect(pushedClipId, 'h1'); // 대표 = 그룹 첫(최신) 클립
      expect(pushedPlaylist, ['h1', 'h2', 'h3']);
    });
  });
}
