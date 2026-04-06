import 'package:hive/hive.dart';

part 'pet.g.dart';

@HiveType(typeId: 0)
class Pet extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String speciesId;

  @HiveField(3)
  String speciesName;

  @HiveField(4)
  String? morph;

  @HiveField(5)
  String sex; // male, female, unknown

  @HiveField(6)
  DateTime? birthDate;

  @HiveField(7)
  DateTime? adoptionDate;

  @HiveField(8)
  double? weight;

  @HiveField(9)
  String? photoPath;

  @HiveField(10)
  String? memo;

  @HiveField(11)
  DateTime createdAt;

  @HiveField(12)
  DateTime updatedAt;

  Pet({
    required this.id,
    required this.name,
    required this.speciesId,
    required this.speciesName,
    this.morph,
    this.sex = 'unknown',
    this.birthDate,
    this.adoptionDate,
    this.weight,
    this.photoPath,
    this.memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get sexDisplay {
    switch (sex) {
      case 'male':
        return '♂ 수컷';
      case 'female':
        return '♀ 암컷';
      default:
        return '미확인';
    }
  }

  String get sexIcon {
    switch (sex) {
      case 'male':
        return '♂';
      case 'female':
        return '♀';
      default:
        return '?';
    }
  }

  String get ageDisplay {
    final ref = birthDate ?? adoptionDate;
    if (ref == null) return '';
    final diff = DateTime.now().difference(ref);
    final months = diff.inDays ~/ 30;
    if (months < 1) return '${diff.inDays}일';
    if (months < 12) return '$months개월';
    final years = months ~/ 12;
    final remaining = months % 12;
    if (remaining == 0) return '$years년';
    return '$years년 $remaining개월';
  }

  String get adoptionDuration {
    if (adoptionDate == null) return '';
    final diff = DateTime.now().difference(adoptionDate!);
    final months = diff.inDays ~/ 30;
    if (months < 1) return '입양 ${diff.inDays}일째';
    if (months < 12) return '입양 $months개월째';
    final years = months ~/ 12;
    return '입양 $years년째';
  }
}
