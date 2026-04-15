import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/pet.dart';

class SupabasePetRepository {
  final SupabaseClient _client;

  Box<Pet> get _cacheBox => Hive.box<Pet>('pets');

  SupabasePetRepository(this._client);

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
      final pet = Pet(
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
        createdAt: DateTime.parse(row['created_at'] as String),
        updatedAt: DateTime.parse(row['updated_at'] as String),
      );
      await _cacheBox.put(pet.id, pet);
    }
  }
}
