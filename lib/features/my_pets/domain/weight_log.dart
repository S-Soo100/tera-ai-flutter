import 'package:hive/hive.dart';

part 'weight_log.g.dart';

@HiveType(typeId: 1)
class WeightLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String petId;

  @HiveField(2)
  final double weight;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String? note;

  WeightLog({
    required this.id,
    required this.petId,
    required this.weight,
    required this.date,
    this.note,
  });
}
