import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivananunt/features/home/domain/device_mode.dart';
import 'package:vivananunt/features/home/domain/enclosure_set.dart';
import 'package:vivananunt/features/home/presentation/home_set_providers.dart';
import 'package:vivananunt/features/my_cage/domain/enclosure.dart';

EnclosureSet _set(String id) => EnclosureSet(
      enclosure: Enclosure(id: id, name: id, createdAt: DateTime(2026, 1, 1)),
      device: null,
      camera: null,
      pet: null,
    );

ProviderContainer _container(List<EnclosureSet> sets) => ProviderContainer(
      overrides: [
        enclosureSetsProvider.overrideWith((ref) async => sets),
      ],
    );

void main() {
  test('세트 없음 → currentSet은 null', () async {
    final c = _container(const []);
    addTearDown(c.dispose);
    expect(await c.read(currentSetProvider.future), isNull);
  });

  test('기본 선택은 첫 세트', () async {
    final c = _container([_set('e1'), _set('e2')]);
    addTearDown(c.dispose);
    expect((await c.read(currentSetProvider.future))!.id, 'e1');
  });

  test('선택 인덱스 변경이 currentSet에 반영된다', () async {
    final c = _container([_set('e1'), _set('e2')]);
    addTearDown(c.dispose);
    c.read(selectedSetIndexProvider.notifier).state = 1;
    expect((await c.read(currentSetProvider.future))!.id, 'e2');
  });

  test('인덱스가 범위를 넘으면 clamp — RangeError 없이 마지막 세트', () async {
    final c = _container([_set('e1')]);
    addTearDown(c.dispose);
    c.read(selectedSetIndexProvider.notifier).state = 5;
    expect((await c.read(currentSetProvider.future))!.id, 'e1');
  });

  test('음수 인덱스도 clamp', () async {
    final c = _container([_set('e1'), _set('e2')]);
    addTearDown(c.dispose);
    c.read(selectedSetIndexProvider.notifier).state = -3;
    expect((await c.read(currentSetProvider.future))!.id, 'e1');
  });

  test('currentDeviceMode — 세트 없으면 none', () async {
    final c = _container(const []);
    addTearDown(c.dispose);
    expect(await c.read(currentDeviceModeProvider.future), DeviceMode.none);
  });
}
