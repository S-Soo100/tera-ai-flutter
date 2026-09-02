import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/domain/enclosure_set.dart';
import 'package:vivnanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/top_fixed_area.dart';
import 'package:vivnanaut/features/my_cage/domain/device.dart';
import 'package:vivnanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivnanaut/features/my_cage/domain/terra_camera.dart';

EnclosureSet _set(String id, {bool cam = false, bool dev = false}) =>
    EnclosureSet(
      enclosure: Enclosure(id: id, name: id, createdAt: DateTime(2026, 1, 1)),
      device: dev
          ? Device(
              id: 'd-$id',
              ownerId: 'u1',
              enclosureId: id,
              name: 'dev',
              isOnline: true,
              lastSeenAt: null)
          : null,
      camera: cam
          ? TerraCamera(
              id: 'c-$id',
              cameraId: 'p4cam-$id',
              name: 'cam',
              isOnline: true,
              enclosureId: id,
              createdAt: DateTime(2026, 1, 1))
          : null,
      pet: null,
    );

Future<ProviderContainer> _pump(
    WidgetTester tester, List<EnclosureSet> sets) async {
  final c = ProviderContainer(overrides: [
    enclosureSetsProvider.overrideWith((ref) async => sets),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: Scaffold(body: TopFixedArea())),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

void main() {
  // ⚠️ 캠 세트를 첫 페이지에 두면 WebRtcLiveView가 실제 피어 연결을 시도해
  // 위젯 테스트가 깨진다 — 캠 세트는 항상 **방문하지 않는 마지막 페이지**에
  // 둔다(PageView.builder는 보이는 페이지만 빌드한다).

  testWidgets('어느 세트에도 캠이 없으면 라이브 자리를 접고 한 줄 안내', (tester) async {
    await _pump(tester, [_set('e1', dev: true)]);
    expect(find.byKey(TopFixedArea.noCameraLineKey), findsOneWidget);
    expect(find.byKey(TopFixedArea.pageViewKey), findsNothing);
    expect(find.byType(AspectRatio), findsNothing);
  });

  testWidgets('캠이 하나라도 있으면 면이 서고, 캠 없는 세트 페이지는 안내 한 줄',
      (tester) async {
    await _pump(tester, [_set('e1', dev: true), _set('e2', cam: true)]);
    expect(find.byKey(TopFixedArea.pageViewKey), findsOneWidget);
    expect(find.byKey(TopFixedArea.noCameraPaneKey), findsOneWidget);
    expect(find.byKey(TopFixedArea.liveKey), findsNothing);
  });

  testWidgets('세트 1개면(캠 없음) 페이지 인디케이터도 없다', (tester) async {
    await _pump(tester, [_set('e1', dev: true)]);
    expect(find.byKey(TopFixedArea.indicatorKey), findsNothing);
  });

  testWidgets('세트 2개 이상이면 인디케이터 노출', (tester) async {
    await _pump(tester,
        [_set('e1', dev: true), _set('e2', dev: true), _set('e3', cam: true)]);
    expect(find.byKey(TopFixedArea.indicatorKey), findsOneWidget);
  });

  testWidgets('스와이프하면 선택 인덱스가 따라온다', (tester) async {
    final c = await _pump(tester,
        [_set('e1', dev: true), _set('e2', dev: true), _set('e3', cam: true)]);
    await tester.drag(
        find.byKey(TopFixedArea.pageViewKey), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(c.read(selectedSetIndexProvider), 1);
  });

  testWidgets('Figma 실측 비율(369:271)을 유지한다', (tester) async {
    await _pump(tester, [_set('e1', dev: true), _set('e2', cam: true)]);
    final ar = tester.widget<AspectRatio>(find
        .descendant(
            of: find.byType(TopFixedArea), matching: find.byType(AspectRatio))
        .first);
    expect(ar.aspectRatio, closeTo(TopFixedArea.aspectRatio, 0.001));
    expect(TopFixedArea.aspectRatio, closeTo(369 / 271, 0.001));
  });

  testWidgets('세트 없음 → 한 줄 안내로 죽지 않는다', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(TopFixedArea), findsOneWidget);
    expect(find.text('home_no_set'), findsOneWidget);
  });
}
