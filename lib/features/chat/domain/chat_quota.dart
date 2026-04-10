import 'package:hive/hive.dart';

part 'chat_quota.g.dart';

@HiveType(typeId: 5)
class ChatQuota extends HiveObject {
  @HiveField(0)
  final String date; // "2026-04-10"

  @HiveField(1)
  int messageCount;

  ChatQuota({
    required this.date,
    this.messageCount = 0,
  });
}
