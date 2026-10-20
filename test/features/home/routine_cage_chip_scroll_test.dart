import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivanaut/features/home/data/schedule_repository.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/domain/schedule.dart';
import 'package:vivanaut/features/home/presentation/home_control_providers.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/home/presentation/routine_settings_screen.dart';
import 'package:vivanaut/features/home/presentation/schedule_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';

class _Repo implements ScheduleRepository {
  @override
  Future<List<Schedule>> list(String deviceId) async => const [];
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

/// 선택 칩이 줄 끝(화면 밖)에 있어도 예약 설정에 들어오면 보이는 자리로
/// 옮겨 온다(2026-10-20 시뮬레이터 대조).
void main() {
  testWidgets('선택된 사육장 칩이 화면 안에 보인다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        scheduleRepositoryProvider.overrideWithValue(_Repo()),
        scheduleLastRunsProvider.overrideWith((ref) async => const {}),
        homeDeviceSetsProvider.overrideWith((ref) async => [
              for (var i = 1; i <= 8; i++) _set('d$i', '아주 긴 사육장 이름 $i'),
            ]),
        currentDeviceIdProvider.overrideWith((ref) async => 'd8'),
      ],
      child: const MaterialApp(home: RoutineSettingsScreen()),
    ));
    await tester.pumpAndSettle();
    final chip = tester.getRect(find.byKey(const Key('routine_cage_chip_d8')));
    expect(chip.left, greaterThanOrEqualTo(0));
    expect(chip.right, lessThanOrEqualTo(375));
  });
}
