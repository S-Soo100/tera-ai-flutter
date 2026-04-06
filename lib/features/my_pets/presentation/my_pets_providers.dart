import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/pet_repository.dart';
import '../domain/pet.dart';
import '../domain/weight_log.dart';

/// Pet 목록 — Hive에서 전체 로드, invalidate로 refresh
final petListProvider = StateNotifierProvider<PetListNotifier, List<Pet>>((ref) {
  final repo = ref.watch(petRepositoryProvider);
  return PetListNotifier(repo);
});

class PetListNotifier extends StateNotifier<List<Pet>> {
  final PetRepository _repo;

  PetListNotifier(this._repo) : super([]) {
    refresh();
  }

  void refresh() {
    state = _repo.getAllPets();
  }

  Future<void> add(Pet pet) async {
    await _repo.addPet(pet);
    refresh();
  }

  Future<void> update(Pet pet) async {
    await _repo.updatePet(pet);
    refresh();
  }

  Future<void> delete(String id) async {
    await _repo.deletePet(id);
    refresh();
  }
}

/// 단일 Pet 조회 (family provider)
final petDetailProvider = Provider.family<Pet?, String>((ref, petId) {
  final repo = ref.watch(petRepositoryProvider);
  return repo.getPet(petId);
});

/// 체중 기록 조회 (family provider)
final weightLogsProvider =
    StateNotifierProvider.family<WeightLogsNotifier, List<WeightLog>, String>(
  (ref, petId) {
    final repo = ref.watch(petRepositoryProvider);
    return WeightLogsNotifier(repo, petId);
  },
);

class WeightLogsNotifier extends StateNotifier<List<WeightLog>> {
  final PetRepository _repo;
  final String _petId;

  WeightLogsNotifier(this._repo, this._petId) : super([]) {
    refresh();
  }

  void refresh() {
    state = _repo.getWeightLogs(_petId);
  }

  Future<void> add(WeightLog log) async {
    await _repo.addWeightLog(log);
    refresh();
  }

  Future<void> delete(String id) async {
    await _repo.deleteWeightLog(id);
    refresh();
  }
}
