import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/storage/safe_hive.dart';
import '../../auth/presentation/auth_providers.dart';
import '../domain/pet.dart';
import '../domain/weight_log.dart';
import 'pet_event_repository.dart';
import 'supabase_pet_repository.dart';

/// 항상 Hive 로컬 리포지토리 반환 (P0 기본값)
final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepository();
});

/// 인증 상태에 따라 Supabase 리포지토리 반환 (미인증 시 null)
final supabasePetRepositoryProvider = Provider<SupabasePetRepository?>((ref) {
  // 계정 id를 watch → 로그아웃 없는 직접 계정 전환도 repo 재생성으로 감지 (stale 방지)
  final userId = ref.watch(currentUserProvider.select((u) => u?.id));
  if (userId == null) return null;
  return SupabasePetRepository(Supabase.instance.client);
});

class PetRepository {
  static const _petsBoxName = 'pets';
  static const _weightLogsBoxName = 'weight_logs';

  Box<Pet> get _petsBox => Hive.box<Pet>(_petsBoxName);
  Box<WeightLog> get _weightLogsBox => Hive.box<WeightLog>(_weightLogsBoxName);

  static Future<void> init() async {
    Hive.registerAdapter(PetAdapter());
    Hive.registerAdapter(WeightLogAdapter());
    await openBoxSafely<Pet>(_petsBoxName);
    await openBoxSafely<WeightLog>(_weightLogsBoxName);
    await PetEventRepository.init();
    await PetEventRepository.migrateWeightLogs();
  }

  // Pet CRUD
  List<Pet> getAllPets() {
    return _petsBox.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Pet? getPet(String id) {
    try {
      return _petsBox.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> addPet(Pet pet) async {
    await _petsBox.put(pet.id, pet);
  }

  Future<void> updatePet(Pet pet) async {
    pet.updatedAt = DateTime.now();
    await _petsBox.put(pet.id, pet);
  }

  Future<void> deletePet(String id) async {
    await _petsBox.delete(id);
    // Delete associated weight logs
    final logs = _weightLogsBox.values.where((l) => l.petId == id).toList();
    for (final log in logs) {
      await _weightLogsBox.delete(log.id);
    }
  }

  int get petCount => _petsBox.length;

  // Weight Log CRUD
  List<WeightLog> getWeightLogs(String petId) {
    return _weightLogsBox.values
        .where((l) => l.petId == petId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addWeightLog(WeightLog log) async {
    await _weightLogsBox.put(log.id, log);
  }

  Future<void> deleteWeightLog(String id) async {
    await _weightLogsBox.delete(id);
  }
}
