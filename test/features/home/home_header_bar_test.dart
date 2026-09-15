import 'package:flutter/material.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/home/presentation/widgets/home_header_bar.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';

EnclosureSet _set(String id, String encName, {String? petName}) => EnclosureSet(
      enclosure:
          Enclosure(id: id, name: encName, createdAt: DateTime(2026, 1, 1)),
      device: Device(
          id: 'd-$id',
          ownerId: 'u',
          enclosureId: id,
          name: '기기 $id',
          isOnline: true,
          lastSeenAt: null),
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
    currentUserProvider.overrideWithValue(null),
    homeDeviceSetsProvider.overrideWith((ref) async => sets),
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
          path: '/devices/add',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('device-pair-screen'))),
        ),
        GoRoute(
          path: '/crecam/cameras/pair',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('camera-pair-screen'))),
        ),
        GoRoute(
          path: '/my-pets/manage',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('pet-add-screen'))),
        ),
        GoRoute(
          path: '/devices/manage',
          builder: (_, __) => const Scaffold(
              body: Center(child: Text('enclosure-link-screen'))),
        ),
        GoRoute(
          path: '/env-settings',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('env-settings-screen'))),
        ),
      ],
    );

void main() {
  testWidgets('그룹명을 표시하고 한 항목이어도 펼칠 수 있다', (tester) async {
    await _pump(tester, [_set('e1', '사육 환경 1', petName: '젤리')]);
    expect(find.text('사육 환경 1'), findsOneWidget);
    expect(find.text('젤리'), findsNothing);
    expect(find.byKey(HomeHeaderBar.dropdownArrowKey), findsOneWidget);
    final header = tester.getRect(find.byType(HomeHeaderBar));
    expect(tester.getRect(find.byKey(HomeHeaderBar.personButtonKey)).right,
        header.right);
    expect(tester.getRect(find.byKey(HomeHeaderBar.setPillKey)).height, 44);
  });
  testWidgets('드롭다운은 기기 ID로 선택하고 이름 변경과 분리한다', (tester) async {
    final c = await _pump(tester, [_set('e1', 'A'), _set('e2', 'B')]);
    await tester.tap(find.byKey(HomeHeaderBar.setPillKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    expect(c.read(selectedHomeDeviceIdProvider), 'd-e2');
  });
  testWidgets('0대면 pill 없이 관리와 계정만 표시한다', (tester) async {
    await _pump(tester, []);
    expect(find.byKey(HomeHeaderBar.setPillKey), findsNothing);
    expect(find.byKey(HomeHeaderBar.personButtonKey), findsOneWidget);
  });
  testWidgets('긴 그룹명과 확대 글꼴이 320px 헤더를 넘지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(tester, [_set('e1', '아주긴사육환경이름입니다')]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('관리 메뉴에서 세 진입점을 열 수 있다', (tester) async {
    await _pump(tester, [_set('e1', 'A')]);
    await tester.tap(find.byKey(HomeHeaderBar.addButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('redesign_device_add'), findsOneWidget);
    expect(find.text('redesign_device_manage'), findsOneWidget);
    expect(find.text('redesign_pet_manage'), findsOneWidget);
    await tester.tap(find.text('redesign_device_add'));
    await tester.pumpAndSettle();
    expect(find.text('device-pair-screen'), findsOneWidget);
  });
  testWidgets('계정 아이콘은 프로필로 이동한다', (tester) async {
    await _pump(tester, [_set('e1', 'A')]);
    await tester.tap(find.byKey(HomeHeaderBar.personButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('profile-screen'), findsOneWidget);
  });
}
