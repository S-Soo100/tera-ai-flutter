import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vivanaut/features/my_cage/data/redesign_group_repository.dart';
import 'package:vivanaut/features/my_pets/data/redesign_pet_repository.dart';
import 'package:vivanaut/features/my_pets/domain/pet.dart';

void main() {
  Pet fixture() => Pet(
      id: 'pet',
      name: '크랑',
      speciesId: 'crested_gecko',
      speciesName: '크레스티드 게코',
      enclosureId: 'old');
  test('save sends full profile and expected group in exactly one RPC',
      () async {
    final calls = <String>[];
    final repo = RedesignPetRepository(rpc: (name, values) async {
      calls.add(name);
      expect(values['p_group_id'], 'new');
      expect(values['p_expected_group_id'], 'old');
      expect(values['p_request_id'], 'request');
      expect((values['p_pet'] as Map<String, Object?>)['name'], '크랑');
      return {'pet_id': 'pet'};
    });
    await repo.save(fixture(), 'new',
        expectedGroupId: 'old', requestId: 'request');
    expect(calls, ['redesign_save_pet_v1']);
  });
  test('missing RPC preserves model and reuses retry key without partial save',
      () async {
    final keys = <Object?>[];
    final pet = fixture();
    final repo = RedesignPetRepository(rpc: (name, values) async {
      expect(name, 'redesign_save_pet_v1');
      keys.add(values['p_request_id']);
      throw const PostgrestException(
          message: 'missing function', code: 'PGRST202');
    });
    for (var i = 0; i < 2; i++) {
      await expectLater(
          repo.save(pet, 'new', expectedGroupId: 'old'),
          throwsA(isA<ManagementFailure>()
              .having((e) => e.key, 'key', 'management_server_unsupported')));
    }
    expect(keys[0], keys[1]);
    expect(pet.enclosureId, 'old');
  });
  test(
      'tombstone success requires matching pet identity without mutating original model',
      () async {
    final pet = fixture();
    final repo = RedesignPetRepository(rpc: (name, values) async {
      expect(name, 'redesign_delete_pet_v1');
      expect(values['p_pet_id'], pet.id);
      return {'deleted': true, 'pet_id': pet.id};
    });
    await repo.delete(pet);
    expect(pet.enclosureId, 'old');
    expect(pet.name, '크랑');
  });
  test('delete is safe RPC only and refuses malformed success', () async {
    var calls = 0;
    final repo = RedesignPetRepository(rpc: (name, values) async {
      calls++;
      expect(name, 'redesign_delete_pet_v1');
      expect(values['p_expected_group_id'], 'old');
      return {'deleted': false};
    });
    await expectLater(
        repo.delete(fixture()), throwsA(isA<ManagementFailure>()));
    expect(calls, 1);
  });
  test('stale membership and unsupported deletion are explicit failures',
      () async {
    for (final code in ['40001', '0A000']) {
      final repo = RedesignPetRepository(
          rpc: (_, __) async =>
              throw PostgrestException(message: 'blocked', code: code));
      await expectLater(
          repo.delete(fixture()),
          throwsA(isA<ManagementFailure>().having(
              (e) => e.key,
              'key',
              code == '40001'
                  ? 'management_membership_changed'
                  : 'management_server_unsupported')));
    }
  });
}
