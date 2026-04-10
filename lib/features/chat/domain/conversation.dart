import 'package:hive/hive.dart';

part 'conversation.g.dart';

@HiveType(typeId: 2)
class Conversation extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final String? petId;

  @HiveField(3)
  final String? speciesId;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  DateTime updatedAt;

  @HiveField(6)
  int messageCount;

  @HiveField(7)
  List<String> tags;

  @HiveField(8)
  bool isArchived;

  Conversation({
    required this.id,
    required this.title,
    this.petId,
    this.speciesId,
    required this.createdAt,
    DateTime? updatedAt,
    this.messageCount = 0,
    List<String>? tags,
    this.isArchived = false,
  })  : updatedAt = updatedAt ?? createdAt,
        tags = tags ?? [];
}
