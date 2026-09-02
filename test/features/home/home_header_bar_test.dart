import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivnanaut/features/home/domain/enclosure_set.dart';
import 'package:vivnanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/home_header_bar.dart';
import 'package:vivnanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivnanaut/features/my_pets/domain/pet.dart';

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

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<EnclosureSet> sets,
) async {
  final c = ProviderContainer(overrides: [
    enclosureSetsProvider.overrideWith((ref) async => sets),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

/// `[+]` 메뉴·person 탭이 라우팅이라 GoRouter가 필요하다. 실제 앱과 같은
/// 경로를 쓴다 — 경로가 어긋나면 여기서 잡힌다.
GoRouter _router() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: HomeHeaderBar()),
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('profile-screen'))),
        ),
        GoRoute(
          path: '/smart-cage/devices/pair',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('device-pair-screen'))),
        ),
        GoRoute(
          path: '/my-pets/add',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('pet-add-screen'))),
        ),
        GoRoute(
          path: '/enclosure-settings',
          builder: (_, __) => const Scaffold(
              body: Center(child: Text('enclosure-settings-screen'))),
        ),
      ],
    );

void main() {
  testWidgets('필 라벨 = 개체명(있으면), 사육장명과 합치지 않는다', (tester) async {
    await _pump(tester, [_set('e1', '1번 사육장', petName: '젤리')]);
    expect(find.text('젤리'), findsOneWidget);
    expect(find.text('젤리 (1번 사육장)'), findsNothing);
  });

  testWidgets('개체가 없으면 사육장명으로 폴백', (tester) async {
    await _pump(tester, [_set('e1', '1번 사육장')]);
    expect(find.text('1번 사육장'), findsOneWidget);
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

    await tester.tap(find.byKey(HomeHeaderBar.setPillKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();

    expect(c.read(selectedSetIndexProvider), 1);
  });

  testWidgets('세트가 없으면 빈 라벨로 죽지 않는다', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(HomeHeaderBar), findsOneWidget);
    expect(find.text('home_no_set'), findsOneWidget);
  });

  testWidgets('person 버튼 → 프로필 화면 — 계정으로 가는 유일한 문이다',
      (tester) async {
    await _pump(tester, [_set('e1', 'A')]);
    await tester.tap(find.byKey(HomeHeaderBar.personButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('profile-screen'), findsOneWidget);
  });

  group('[+] 메뉴', () {
    testWidgets('탭하면 기기/개체/사육세트 추가 3항목이 뜬다', (tester) async {
      await _pump(tester, [_set('e1', 'A')]);
      await tester.tap(find.byKey(HomeHeaderBar.addButtonKey));
      await tester.pumpAndSettle();
      expect(find.text('home_add_device'), findsOneWidget);
      expect(find.text('home_add_pet'), findsOneWidget);
      expect(find.text('home_add_set'), findsOneWidget);
    });

    testWidgets('기기 추가 → /smart-cage/devices/pair', (tester) async {
      await _pump(tester, [_set('e1', 'A')]);
      await tester.tap(find.byKey(HomeHeaderBar.addButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('home_add_device'));
      await tester.pumpAndSettle();
      expect(find.text('device-pair-screen'), findsOneWidget);
    });

    testWidgets('개체 추가 → /my-pets/add', (tester) async {
      await _pump(tester, [_set('e1', 'A')]);
      await tester.tap(find.byKey(HomeHeaderBar.addButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('home_add_pet'));
      await tester.pumpAndSettle();
      expect(find.text('pet-add-screen'), findsOneWidget);
    });

    testWidgets('사육세트 추가 → /enclosure-settings', (tester) async {
      await _pump(tester, [_set('e1', 'A')]);
      await tester.tap(find.byKey(HomeHeaderBar.addButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('home_add_set'));
      await tester.pumpAndSettle();
      expect(find.text('enclosure-settings-screen'), findsOneWidget);
    });
  });
}
