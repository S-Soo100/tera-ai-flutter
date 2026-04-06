import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../domain/pet.dart';
import '../domain/weight_log.dart';

final petRepositoryProvider = Provider<PetRepository>((ref) {
  return PetRepository();
});

class PetRepository {
  static const _petsBoxName = 'pets';
  static const _weightLogsBoxName = 'weight_logs';

  Box<Pet> get _petsBox => Hive.box<Pet>(_petsBoxName);
  Box<WeightLog> get _weightLogsBox => Hive.box<WeightLog>(_weightLogsBoxName);

  static Future<void> init() async {
    Hive.registerAdapter(PetAdapter());
    Hive.registerAdapter(WeightLogAdapter());
    await Hive.openBox<Pet>(_petsBoxName);
    await Hive.openBox<WeightLog>(_weightLogsBoxName);
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
