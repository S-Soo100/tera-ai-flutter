// 기기 예약 설정 — 사육장 여럿일 때 선택 칩 캡처. 옵트인:
//   flutter test --dart-define=CAPTURE_ROUTINE=true \
//     test/design/routine_cage_chips_capture_test.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vivanaut/features/home/data/schedule_repository.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart';
import 'package:vivanaut/features/home/presentation/schedule_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'remaining_ui_capture_test.dart' show shell, capture;

class _Repo implements ScheduleRepository {
  @override
  Future<List<Schedule>> list(String deviceId) async => [
        for (final (i, a, h) in [
          (1, ScheduleAction.mist, 8),
          (2, ScheduleAction.fanOn, 13),
          (3, ScheduleAction.mist, 20),
        ])
          Schedule(
              id: 's$i',
              deviceId: deviceId,
              action: a,
              payload: const {'duration_ms': 3000},
              kind: ScheduleKind.daily,
              hour: h,
              minute: 0,
              daysOfWeek: const [],
              enabled: true,
              guard: null,
              pairId: null,
              nextRunAt: null,
              lastRunAt: null),
      ];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

EnclosureSet _set(String id, String name) => EnclosureSet(
    enclosure: Enclosure(id: 'e$id', name: name, createdAt: DateTime(2026)),
    device: Device(
        id: id,
        ownerId: 'u',
        enclosureId: 'e$id',
        name: name,
        isOnline: true,
        lastSeenAt: DateTime(2026)),
    camera: null,
    pet: null);

void main() {
  if (!const bool.fromEnvironment('CAPTURE_ROUTINE')) {
    test('opt-in routine captures', () {}, skip: 'CAPTURE_ROUTINE=true');
    return;
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    final f = FontLoader('Pretendard');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      f.addFont(rootBundle.load('assets/fonts/Pretendard-$w.otf'));
    }
    await f.load();
  });

  testWidgets('routine cage chips', (tester) async {
    final boundary = GlobalKey();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.binding.setSurfaceSize(const Size(393, 852));
    await tester
        .pumpWidget(shell(boundary, const RoutineSettingsScreen(), overrides: [
      scheduleRepositoryProvider.overrideWithValue(_Repo()),
      scheduleLastRunsProvider.overrideWith((ref) async => const {}),
      homeDeviceSetsProvider.overrideWith((ref) async => [
            _set('d1', '크레 1번 사육장'),
            _set('d2', '레오파드 사육장'),
            _set('d3', '거실 사육장')
          ]),
      currentDeviceIdProvider.overrideWith((ref) async => 'd1'),
    ]));
    await tester.pumpAndSettle();
    await capture(tester, boundary, 'routine-cage-chips');
  });
}
