import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tera_ai/features/home/domain/enclosure_set.dart';
import 'package:tera_ai/features/home/presentation/home_set_providers.dart';
import 'package:tera_ai/features/home/presentation/widgets/home_header_bar.dart';
import 'package:tera_ai/features/my_cage/domain/enclosure.dart';
import 'package:tera_ai/features/my_pets/domain/pet.dart';

EnclosureSet _set(String id, String encName, {String? petName}) => EnclosureSet(
      enclosure:
          Enclosure(id: id, name: encName, createdAt: DateTime(2026, 1, 1)),
      device: null,
      camera: null,
      pet: petName == null
          ? null
          : Pet(
              id: 'p-$id',
              name: petName,
              speciesId: 'crested_gecko',
              speciesName: '크레스티드 게코',
            ),
    );

ProviderContainer _makeContainer(List<EnclosureSet> sets, int unread) =>
    ProviderContainer(overrides: [
      enclosureSetsProvider.overrideWith((ref) async => sets),
      unreadNotificationCountProvider.overrideWith((ref) => unread),
    ]);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<EnclosureSet> sets, {
  int unread = 0,
}) async {
  final c = _makeContainer(sets, unread);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: HomeHeaderBar())),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  testWidgets('현재 세트 라벨을 보여준다', (tester) async {
    await _pump(tester, [_set('e1', '1번 사육장', petName: '젤리')]);
    // 개체명과 사육장명을 **한 덩어리로 합치지 않는다** — 뭐가 주인공인지
    // 읽는 사람이 매번 판단하게 만들지 않기 위함.
    expect(find.text('젤리'), findsOneWidget);
    expect(find.text('1번 사육장'), findsOneWidget);
    expect(find.text('젤리 (1번 사육장)'), findsNothing);
  });

  testWidgets('세트가 1개면 드롭다운 화살표 비노출 (PRD §3.1 예외)', (tester) async {
    await _pump(tester, [_set('e1', '1번 사육장')]);
    expect(find.byKey(HomeHeaderBar.dropdownArrowKey), findsNothing);
  });

  testWidgets('세트가 2개 이상이면 화살표 노출', (tester) async {
    await _pump(tester, [_set('e1', 'A'), _set('e2', 'B')]);
    expect(find.byKey(HomeHeaderBar.dropdownArrowKey), findsOneWidget);
  });

  testWidgets('드롭다운에서 다른 세트를 고르면 선택 인덱스가 바뀐다', (tester) async {
    final c = await _pump(tester, [_set('e1', 'A'), _set('e2', 'B')]);

    await tester.tap(find.byKey(HomeHeaderBar.dropdownArrowKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(c.read(selectedSetIndexProvider), 1);
  });

  testWidgets('미읽음 0이면 Red Dot 없음', (tester) async {
    await _pump(tester, [_set('e1', 'A')], unread: 0);
    expect(find.byKey(HomeHeaderBar.redDotKey), findsNothing);
  });

  testWidgets('미읽음이 있으면 Red Dot 노출', (tester) async {
    await _pump(tester, [_set('e1', 'A')], unread: 3);
    expect(find.byKey(HomeHeaderBar.redDotKey), findsOneWidget);
  });

  testWidgets('세트가 없으면 빈 라벨로 죽지 않는다', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(HomeHeaderBar), findsOneWidget);
  });
}
