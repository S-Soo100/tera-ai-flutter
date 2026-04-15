import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'pet_event.g.dart';

class PetEventType {
  static const feeding = 'feeding';
  static const shedding = 'shedding';
  static const weight = 'weight';
  static const healthCheck = 'health_check';
  static const note = 'note';

  static const all = [feeding, shedding, weight, healthCheck, note];

  static String label(String type) {
    switch (type) {
      case feeding:
        return '급여';
      case shedding:
        return '탈피';
      case weight:
        return '체중';
      case healthCheck:
        return '건강 체크';
      case note:
        return '메모';
      default:
        return type;
    }
  }

  static IconData icon(String type) {
    switch (type) {
      case feeding:
        return Icons.restaurant;
      case shedding:
        return Icons.autorenew;
      case weight:
        return Icons.monitor_weight_outlined;
      case healthCheck:
        return Icons.health_and_safety;
      case note:
        return Icons.note_alt_outlined;
      default:
        return Icons.event;
    }
  }

  static Color color(String type, ColorScheme colorScheme) {
    switch (type) {
      case feeding:
        return Colors.green;
      case shedding:
        return Colors.orange;
      case weight:
        return colorScheme.primary;
      case healthCheck:
        return Colors.red;
      case note:
        return colorScheme.onSurfaceVariant;
      default:
        return colorScheme.onSurface;
    }
  }
}

@HiveType(typeId: 4)
class PetEvent extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String petId;

  @HiveField(2)
  final String type;

  @HiveField(3)
  final double? value;

  @HiveField(4)
  final String? title;

  @HiveField(5)
  final String? note;

  @HiveField(6)
  final DateTime eventDate;

  @HiveField(7)
  final DateTime createdAt;

  PetEvent({
    required this.id,
    required this.petId,
    required this.type,
    this.value,
    this.title,
    this.note,
    required this.eventDate,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
