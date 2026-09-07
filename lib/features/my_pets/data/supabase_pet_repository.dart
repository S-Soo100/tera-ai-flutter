import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/pet.dart';
import 'pet_assignment_service.dart';

/// 서버 `pets` 행 → [Pet].
///
/// `enclosure_id` 복원이 핵심이다. [SupabasePetRepository.syncFromRemote]는
/// Hive box를 clear한 뒤 서버 행으로 재구성하므로, 여기서 빠뜨리면 배정이
/// 동기화 한 번에 조용히 사라진다.
/// 컬럼이 없는 구버전 서버에서도 죽지 않도록 없으면 null로 둔다.
Pet petFromRow(Map<String, dynamic> row) {
  return Pet(
    id: row['id'] as String,
    name: row['name'] as String,
    speciesId: (row['species_id'] as String?) ?? 'custom',
    speciesName: row['species_name'] as String,
    morph: row['morph'] as String?,
    sex: (row['sex'] as String?) ?? 'unknown',
    birthDate: row['birth_date'] != null
        ? DateTime.tryParse(row['birth_date'] as String)
        : null,
    adoptionDate: row['adoption_date'] != null
        ? DateTime.tryParse(row['adoption_date'] as String)
        : null,
    weight: (row['weight'] as num?)?.toDouble(),
    photoPath: row['avatar_url'] as String?,
    memo: row['memo'] as String?,
    enclosureId: row['enclosure_id'] as String?,
    createdAt: DateTime.parse(row['created_at'] as String),
    updatedAt: DateTime.parse(row['updated_at'] as String),
  );
}

class SupabasePetRepository {
  final SupabaseClient _client;

  /// 배정 RPC 주입(테스트용). null이면 [_defaultAssignRpc]를 쓴다.
  final AssignPetRpc? _assignRpcOverride;

  Box<Pet> get _cacheBox => Hive.box<Pet>('pets');

  SupabasePetRepository(this._client, {AssignPetRpc? assignRpc})
      : _assignRpcOverride = assignRpc;

  AssignPetRpc get _assignRpc => _assignRpcOverride ?? _defaultAssignRpc;

  Future<void> _defaultAssignRpc({
    required String petId,
    required String? enclosureId,
  }) async {
    await _client.rpc('assign_pet_to_enclosure', params: {
      'p_pet_id': petId,
      'p_enclosure_id': enclosureId,
    });
  }

  List<Pet> getAllPets() {
    return _cacheBox.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Pet? getPet(String id) {
    try {
      return _cacheBox.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addPet(Pet pet) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    await _client.from('pets').insert({
      'id': pet.id,
      'user_id': userId,
      'species_id': pet.speciesId,
      'name': pet.name,
      'species_name': pet.speciesName,
      'morph': pet.morph,
      'sex': pet.sex,
      'birth_date': pet.birthDate?.toIso8601String(),
      'adoption_date': pet.adoptionDate?.toIso8601String(),
      'weight': pet.weight,
      'avatar_url': pet.photoPath,
      'memo': pet.memo,
    });

    await _cacheBox.put(pet.id, pet);
  }

  Future<void> updatePet(Pet pet) async {
    pet.updatedAt = DateTime.now();
    await _client.from('pets').update({
      'name': pet.name,
      'species_id': pet.speciesId,
      'species_name': pet.speciesName,
      'morph': pet.morph,
      'sex': pet.sex,
      'birth_date': pet.birthDate?.toIso8601String(),
      'adoption_date': pet.adoptionDate?.toIso8601String(),
      'weight': pet.weight,
      'avatar_url': pet.photoPath,
      'memo': pet.memo,
      'updated_at': pet.updatedAt.toIso8601String(),
    }).eq('id', pet.id);

    await _cacheBox.put(pet.id, pet);
  }

  Future<void> deletePet(String id) async {
    await _client.from('pets').delete().eq('id', id);
    await _cacheBox.delete(id);
  }

  int get petCount => _cacheBox.length;

  /// Supabase에서 전체 동기화 (캐시 갱신)
  Future<void> syncFromRemote() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final data = await _client
        .from('pets')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    await _cacheBox.clear();
    for (final row in data) {
      final pet = petFromRow(Map<String, dynamic>.from(row as Map));
      await _cacheBox.put(pet.id, pet);
    }
  }

  /// 개체를 사육장에 배정한다. [enclosureId]가 null이면 해제.
  ///
  /// `assign_pet_to_enclosure` RPC **1회**가 유일한 쓰기 경로다.
  /// 1:1 교체(기존 점유 개체 해제)는 서버가 원자적으로 처리하므로 앱은
  /// 다단계 UPDATE를 하지 않는다.
  ///
  /// 서버 예외(소유권 불일치·1:1 위반·미인증)는 그대로 전파한다 —
  /// 실패했는데 로컬만 성공한 것처럼 저장하지 않는다.
  Future<void> assignPetToEnclosure({
    required String petId,
    required String? enclosureId,
  }) {
    return PetAssignmentService(
      rpc: _assignRpc,
      resync: syncFromRemote,
    ).assign(petId: petId, enclosureId: enclosureId);
  }
}
