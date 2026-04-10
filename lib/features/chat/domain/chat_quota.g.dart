// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_quota.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatQuotaAdapter extends TypeAdapter<ChatQuota> {
  @override
  final int typeId = 5;

  @override
  ChatQuota read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatQuota(
      date: fields[0] as String,
      messageCount: fields[1] as int,
    );
  }

  @override
  void write(BinaryWriter writer, ChatQuota obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.messageCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatQuotaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
