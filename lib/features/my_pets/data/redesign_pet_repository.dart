import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../my_cage/data/redesign_group_repository.dart';
import '../domain/pet.dart';

typedef PetMutationRpc = Future<Object?> Function(
    String name, Map<String, Object?> params);

/// Atomic profile + membership writes. No profile-only fallback or local-cache
/// mutation: callers resync after success and retain the editor draft on failure.
class RedesignPetRepository {
  RedesignPetRepository({required PetMutationRpc rpc}) : _rpc = rpc;
  factory RedesignPetRepository.supabase(SupabaseClient client, String userId) {
    void requireOwner() {
      if (client.auth.currentUser?.id != userId) {
        throw const ManagementFailure('management_auth_changed');
      }
    }

    return RedesignPetRepository(rpc: (name, params) async {
      requireOwner();
      final Object? result = await client.rpc(name, params: params);
      requireOwner();
      return result;
    });
  }
  final PetMutationRpc _rpc;
  final Map<String, String> _pendingRequests = {};

  Future<void> save(
    Pet pet,
    String? groupId, {
    required String? expectedGroupId,
    String? requestId,
  }) =>
      _mutate(
          'redesign_save_pet_v1',
          {
            'p_pet': {
              'id': pet.id,
              'name': pet.name,
              'species_id': pet.speciesId,
              'species_name': pet.speciesName,
              'morph': pet.morph,
              'sex': pet.sex,
              'birth_date': _date(pet.birthDate),
              'adoption_date': _date(pet.adoptionDate),
              'weight': pet.weight,
              'avatar_url': pet.photoPath,
              'memo': pet.memo,
            },
            'p_group_id': groupId,
            'p_expected_group_id': expectedGroupId,
          },
          requestId: requestId,
          accepts: (result) => result['pet_id'] == pet.id);

  Future<void> delete(Pet pet, {String? requestId}) => _mutate(
        'redesign_delete_pet_v1',
        {
          'p_pet_id': pet.id,
          'p_expected_group_id': pet.enclosureId,
        },
        requestId: requestId,
        accepts: (result) =>
            result['deleted'] == true && result['pet_id'] == pet.id,
      );

  static String? _date(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _mutate(
    String name,
    Map<String, Object?> payload, {
    String? requestId,
    required bool Function(Map<Object?, Object?>) accepts,
  }) async {
    final fingerprint = '$name:${jsonEncode(payload)}';
    final key = requestId ??
        _pendingRequests.putIfAbsent(fingerprint, () => const Uuid().v4());
    try {
      final result = await _rpc(name, {...payload, 'p_request_id': key});
      if (result is! Map<Object?, Object?> || !accepts(result)) {
        throw const ManagementFailure('management_save_failed');
      }
      _pendingRequests.remove(fingerprint);
    } on ManagementFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw ManagementFailure(switch (error.code) {
        'PGRST202' || '42883' || '0A000' => 'management_server_unsupported',
        '23505' => 'management_name_duplicate',
        // PT409: 2026-09-22부터의 '구성 변경'(40001은 PostgREST 무한 재시도).
        '40001' || 'PT409' => 'management_membership_changed',
        '42501' => 'management_auth_changed',
        _ => 'management_save_failed',
      });
    } catch (_) {
      throw const ManagementFailure('management_save_failed');
    }
  }
}
