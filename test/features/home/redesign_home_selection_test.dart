import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/auth/presentation/auth_providers.dart';
import 'package:vivanaut/features/home/domain/enclosure_set.dart';
import 'package:vivanaut/features/home/domain/group_display_label.dart';
import 'package:vivanaut/features/home/presentation/home_set_providers.dart';
import 'package:vivanaut/features/my_cage/domain/device.dart';
import 'package:vivanaut/features/my_cage/domain/enclosure.dart';
import 'package:vivanaut/features/my_cage/presentation/supabase_module_providers.dart';

Device device(String id, {String? group}) => Device(
    id: id,
    ownerId: 'u',
    enclosureId: group,
    name: '사육장 $id',
    isOnline: true,
    lastSeenAt: null);
final devicesState = StateProvider<List<Device>>(
    (ref) => [device('1', group: 'g'), device('2')]);
final userState = StateProvider<String>((ref) => 'u');
void main() {
  test('ungrouped devices stay selectable and group labels use IDs, not names',
      () async {
    final d = device('1', group: 'g');
    final group =
        Enclosure(id: 'g', name: '사육 환경 1', createdAt: DateTime.utc(2026));
    final c = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => User(
          id: ref.watch(userState),
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01')),
      deviceListProvider.overrideWith((ref) async => ref.watch(devicesState)),
      enclosureSetsProvider.overrideWith((ref) async =>
          [EnclosureSet(enclosure: group, device: d, camera: null, pet: null)]),
    ]);
    addTearDown(c.dispose);
    final sets = await c.read(homeDeviceSetsProvider.future);
    expect(sets.map((s) => s.homeLabel), ['사육 환경 1', '사육장 2']);
    expect(sets.last.groupId, isNull);
    c.read(selectedHomeDeviceIdProvider.notifier).state = '2';
    expect((await c.read(currentSetProvider.future))!.device!.id, '2');
    c.read(devicesState.notifier).state = [device('2'), d];
    expect((await c.read(currentSetProvider.future))!.device!.id, '2');
    c.read(userState.notifier).state = 'other';
    expect(c.read(selectedHomeDeviceIdProvider), isNull);
    expect(
        groupDisplayLabel(
            groupId: 'missing', individualName: '크레', groups: [group]),
        '크레');
  });
}
