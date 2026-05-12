// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatMessageAdapter extends TypeAdapter<ChatMessage> {
  @override
  final int typeId = 3;

  @override
  ChatMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatMessage(
      id: fields[0] as String,
      conversationId: fields[1] as String,
      role: fields[2] as String,
      content: fields[3] as String,
      createdAt: fields[4] as DateTime,
      tokenCount: fields[5] as int?,
      fromCache: fields[6] as bool,
      knowledgeEntryId: fields[7] as String?,
      citationIds: (fields[8] as List).cast<String>(),
      sourceType: fields[9] as String?,
      webSources: (fields[10] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatMessage obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.conversationId)
      ..writeByte(2)
      ..write(obj.role)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.tokenCount)
      ..writeByte(6)
      ..write(obj.fromCache)
      ..writeByte(7)
      ..write(obj.knowledgeEntryId)
      ..writeByte(8)
      ..write(obj.citationIds)
      ..writeByte(9)
      ..write(obj.sourceType)
      ..writeByte(10)
      ..write(obj.webSources);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
