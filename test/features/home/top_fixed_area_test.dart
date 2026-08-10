import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/home/domain/enclosure_set.dart';
import 'package:vivananunt/features/home/presentation/home_set_providers.dart';
import 'package:vivananunt/features/home/presentation/widgets/top_fixed_area.dart';
import 'package:vivananunt/features/my_cage/domain/device.dart';
import 'package:vivananunt/features/my_cage/domain/enclosure.dart';
import 'package:vivananunt/features/my_cage/domain/terra_camera.dart';

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
  testWidgets('캠 없는 세트 → 프로필 카드 영역', (tester) async {
    await _pump(tester, [_set('e1', dev: true)]);
    expect(find.byKey(TopFixedArea.profileKey), findsOneWidget);
    expect(find.byKey(TopFixedArea.liveKey), findsNothing);
  });

  testWidgets('세트 1개면 페이지 인디케이터 비노출', (tester) async {
    await _pump(tester, [_set('e1', dev: true)]);
    expect(find.byKey(TopFixedArea.indicatorKey), findsNothing);
  });

  testWidgets('세트 2개 이상이면 인디케이터 노출', (tester) async {
    await _pump(tester, [_set('e1', dev: true), _set('e2', dev: true)]);
    expect(find.byKey(TopFixedArea.indicatorKey), findsOneWidget);
  });

  testWidgets('스와이프하면 선택 인덱스가 따라온다', (tester) async {
    final c =
        await _pump(tester, [_set('e1', dev: true), _set('e2', dev: true)]);
    await tester.drag(
        find.byKey(TopFixedArea.pageViewKey), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(c.read(selectedSetIndexProvider), 1);
  });

  testWidgets('16:9 비율을 유지한다 — 서브탭 높이 변화에 안 흔들림', (tester) async {
    await _pump(tester, [_set('e1', dev: true)]);
    final ar = tester.widget<AspectRatio>(find
        .descendant(
            of: find.byType(TopFixedArea), matching: find.byType(AspectRatio))
        .first);
    expect(ar.aspectRatio, closeTo(16 / 9, 0.001));
  });

  testWidgets('세트 없음 → 빈 상태로 죽지 않는다', (tester) async {
    await _pump(tester, const []);
    expect(find.byType(TopFixedArea), findsOneWidget);
  });
}
