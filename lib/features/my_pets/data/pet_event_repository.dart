import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../../../core/storage/safe_hive.dart';
import '../domain/pet_event.dart';
import '../domain/weight_log.dart';

final petEventRepositoryProvider = Provider<PetEventRepository>((ref) {
  return PetEventRepository();
});

class PetEventRepository {
  static const _boxName = 'pet_events';

  Box<PetEvent> get _box => Hive.box<PetEvent>(_boxName);

  static Future<void> init() async {
    Hive.registerAdapter(PetEventAdapter());
    await openBoxSafely<PetEvent>(_boxName);
  }

  List<PetEvent> getEvents(String petId) {
    return _box.values
        .where((e) => e.petId == petId)
        .toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
  }

  List<PetEvent> getEventsByType(String petId, String type) {
    return _box.values
        .where((e) => e.petId == petId && e.type == type)
        .toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
  }

  Future<void> addEvent(PetEvent event) async {
    await _box.put(event.id, event);
  }

  Future<void> deleteEvent(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteEventsForPet(String petId) async {
    final events = _box.values.where((e) => e.petId == petId).toList();
    for (final event in events) {
      await _box.delete(event.id);
    }
  }

  /// WeightLog -> PetEvent 마이그레이션
  static Future<void> migrateWeightLogs() async {
    final flagBox = await Hive.openBox<bool>('migration_flags');
    if (flagBox.get('weight_log_migrated', defaultValue: false) == true) return;

    final weightLogsBox = Hive.box<WeightLog>('weight_logs');
    final eventBox = Hive.box<PetEvent>('pet_events');

    for (final log in weightLogsBox.values) {
      final event = PetEvent(
        id: log.id,
        petId: log.petId,
        type: PetEventType.weight,
        value: log.weight,
        note: log.note,
        eventDate: log.date,
        createdAt: log.date,
      );
      await eventBox.put(event.id, event);
    }

    await flagBox.put('weight_log_migrated', true);
  }
}
