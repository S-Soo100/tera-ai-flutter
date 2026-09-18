import 'package:flutter/material.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';
import 'package:vivanaut/features/my_cage/presentation/webrtc_live_controller.dart';
import 'package:vivanaut/shared/widgets/live_surface.dart';

import '../../helpers/inert_live_controller.dart';
import 'package:vivanaut/features/home/presentation/widgets/top_fixed_area.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/domain/terra_camera.dart';

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
    currentUserProvider.overrideWithValue(null),
    homeDeviceSetsProvider.overrideWith((ref) async => sets),
    // 실피어 차단 — startConnection()을 부르지 않은 inert 컨트롤러(A2).
    webrtcLiveControllerProvider
        .overrideWith((ref, uuid) => InertLiveController(ref, uuid)),
    nowTickProvider
        .overrideWith((ref) => Stream.value(DateTime(2026, 9, 14, 12))),
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
  testWidgets('선택한 사육장에 카메라가 없으면 라이브와 안내 여백 모두 없다', (tester) async {
    await _pump(tester, [_set('e1', dev: true), _set('e2', cam: true)]);
    expect(find.byKey(TopFixedArea.liveKey), findsNothing);
    expect(find.byType(LiveSurface), findsNothing);
    expect(find.byKey(TopFixedArea.noCameraLineKey), findsNothing);
  });
  testWidgets('선택 카메라는 369:271 비율, 상태 배지 없이 표시한다', (tester) async {
    await _pump(tester, [_set('e1', dev: true, cam: true)]);
    expect(find.byKey(TopFixedArea.liveKey), findsOneWidget);
    expect(tester.widget<LiveSurface>(find.byType(LiveSurface)).status, isNull);
    final ar = tester.widget<AspectRatio>(find
        .descendant(
            of: find.byType(TopFixedArea), matching: find.byType(AspectRatio))
        .first);
    expect(ar.aspectRatio, closeTo(369 / 271, .001));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('선택 ID 변경으로 라이브 대상이 바뀐다', (tester) async {
    final c = await _pump(
        tester, [_set('e1', dev: true), _set('e2', dev: true, cam: true)]);
    c.read(selectedHomeDeviceIdProvider.notifier).state = 'd-e2';
    await tester.pumpAndSettle();
    expect(find.byKey(TopFixedArea.liveKey), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets('빈 선택은 라이브를 만들지 않는다', (tester) async {
    await _pump(tester, []);
    expect(find.byType(LiveSurface), findsNothing);
  });
}
