// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'knowledge_entry.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class KnowledgeEntryAdapter extends TypeAdapter<KnowledgeEntry> {
  @override
  final int typeId = 4;

  @override
  KnowledgeEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return KnowledgeEntry(
      id: fields[0] as String,
      question: fields[1] as String,
      answer: fields[2] as String,
      speciesId: fields[3] as String,
      category: fields[4] as String,
      keywords: (fields[5] as List).cast<String>(),
      createdAt: fields[6] as DateTime,
      useCount: fields[7] as int,
      confidence: fields[8] as double,
      sourceConversationId: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, KnowledgeEntry obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.question)
      ..writeByte(2)
      ..write(obj.answer)
      ..writeByte(3)
      ..write(obj.speciesId)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.keywords)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.useCount)
      ..writeByte(8)
      ..write(obj.confidence)
      ..writeByte(9)
      ..write(obj.sourceConversationId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KnowledgeEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
