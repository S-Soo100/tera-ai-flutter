import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/home/domain/timeline_summary.dart';
import 'package:vivananunt/features/home/presentation/home_timeline_providers.dart';
import 'package:vivananunt/features/home/presentation/widgets/timeline_date_scroller.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Map<TimelineFilter, int> counts,
) async {
  // 칩은 가로 ListView라 기본 800px 뷰포트에서는 뒤쪽 칩이 빌드되지 않는다.
  // 5종을 한 번에 검사하려고 넓힌다.
  tester.view.physicalSize = const Size(1600, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final c = ProviderContainer(overrides: [
    timelineFilterCountsProvider.overrideWith((ref) async => counts),
  ]);
  addTearDown(c.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        home: Scaffold(body: TimelineDateScroller()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

/// 칩이 눌리는가 = onSelected가 붙어 있는가.
bool _enabled(WidgetTester tester, String label) {
  final chip = tester.widget<FilterChip>(
    find.ancestor(of: find.text(label), matching: find.byType(FilterChip)),
  );
  return chip.onSelected != null;
}

void main() {
  group('필터 칩 카운트 표기 (Figma Asset §4.4 — [카운트] [라벨])', () {
    testWidgets('카운트가 라벨 앞에 붙는다', (tester) async {
      await _pump(tester, {
        TimelineFilter.moving: 3,
        TimelineFilter.eating: 1,
      });
      // .tr()이 로케일 없이 키를 그대로 돌려주므로 키 기준으로 확인한다.
      expect(find.text('3 home_filter_moving'), findsOneWidget);
      expect(find.text('1 home_filter_eating'), findsOneWidget);
    });

    testWidgets('0건도 카운트를 보여준다 — 없다는 사실 자체가 정보다', (tester) async {
      await _pump(tester, {TimelineFilter.shedding: 0});
      expect(find.text('0 home_filter_shedding'), findsOneWidget);
    });

    testWidgets('카운트가 아직 안 온 필터는 0으로 표기', (tester) async {
      await _pump(tester, const {});
      expect(find.text('0 home_filter_moving'), findsOneWidget);
    });

    testWidgets('전체 칩도 카운트를 갖는다', (tester) async {
      await _pump(tester, {TimelineFilter.all: 12});
      expect(find.text('12 home_filter_all'), findsOneWidget);
    });
  });

  group('0건 비활성 (PRD §3.5) — 카운트를 붙여도 유지된다', () {
    testWidgets('0건 칩은 누를 수 없다', (tester) async {
      await _pump(tester, {TimelineFilter.shedding: 0});
      expect(_enabled(tester, '0 home_filter_shedding'), isFalse);
    });

    testWidgets('1건 이상이면 누를 수 있다', (tester) async {
      await _pump(tester, {TimelineFilter.moving: 3});
      expect(_enabled(tester, '3 home_filter_moving'), isTrue);
    });

    testWidgets('활성 칩을 누르면 필터가 바뀐다', (tester) async {
      final c = await _pump(tester, {TimelineFilter.eating: 2});
      await tester.tap(find.text('2 home_filter_eating'));
      await tester.pumpAndSettle();
      expect(c.read(timelineFilterProvider), TimelineFilter.eating);
    });

    testWidgets('0건 칩을 눌러도 필터가 안 바뀐다', (tester) async {
      final c = await _pump(tester, {TimelineFilter.shedding: 0});
      final before = c.read(timelineFilterProvider);
      await tester.tap(find.text('0 home_filter_shedding'));
      await tester.pumpAndSettle();
      expect(c.read(timelineFilterProvider), before);
    });
  });

  group('칩 목록', () {
    testWidgets('필터 5종이 모두 고정 노출된다 — 0건이어도 숨기지 않는다',
        (tester) async {
      await _pump(tester, const {});
      expect(find.byType(FilterChip), findsNWidgets(TimelineFilter.values.length));
    });
  });
}
