import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivnanaut/features/home/presentation/widgets/device_offline_notice.dart';
import 'package:vivnanaut/features/my_cage/domain/device.dart';
import 'package:vivnanaut/features/my_cage/presentation/supabase_module_providers.dart';

const _deviceId = 'dev-1';

Device _device({DateTime? lastSeen}) => Device(
      id: _deviceId,
      name: 'terra-iot-03',
      isOnline: false,
      lastSeenAt: lastSeen,
      ownerId: 'u1',
      enclosureId: null,
    );

Future<void> _pump(
  WidgetTester tester, {
  required bool online,
  DateTime? lastSeen,
  String? deviceId = _deviceId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDeviceIdProvider.overrideWith((ref) async => deviceId),
        currentDeviceProvider
            .overrideWith((ref) async => _device(lastSeen: lastSeen)),
        moduleOnlineProvider(_deviceId).overrideWithValue(online),
        nowTickProvider
            .overrideWith((ref) => Stream.value(DateTime(2026, 8, 12, 10))),
      ],
      child: const MaterialApp(
        home: Scaffold(body: DeviceOfflineNotice()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('오프라인이면 왜 못 누르는지 밝힌다 — 회색 버튼만 두면 고장으로 읽힌다',
      (tester) async {
    await _pump(tester,
        online: false, lastSeen: DateTime(2026, 8, 12, 2));
    expect(find.byKey(DeviceOfflineNotice.noticeKey), findsOneWidget);
  });

  testWidgets('온라인이면 아무것도 그리지 않는다 — 늘 떠 있는 배너는 곧 안 읽힌다',
      (tester) async {
    await _pump(tester, online: true, lastSeen: DateTime(2026, 8, 12, 9, 59));
    expect(find.byKey(DeviceOfflineNotice.noticeKey), findsNothing);
  });

  testWidgets('마지막 신호 시각을 몰라도 뜬다 — 시각이 없다고 침묵하면 안 된다',
      (tester) async {
    await _pump(tester, online: false, lastSeen: null);
    expect(find.byKey(DeviceOfflineNotice.noticeKey), findsOneWidget);
  });

  testWidgets('제어기가 없는 세트(캠 단품)에서는 뜨지 않는다', (tester) async {
    await _pump(tester, online: false, deviceId: null);
    expect(find.byKey(DeviceOfflineNotice.noticeKey), findsNothing);
  });
}
