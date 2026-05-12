// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_video.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedVideoAdapter extends TypeAdapter<CachedVideo> {
  @override
  final int typeId = 10;

  @override
  CachedVideo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedVideo(
      clipId: fields[0] as String,
      filePath: fields[1] as String,
      sizeBytes: fields[2] as int,
      downloadedAt: fields[3] as DateTime,
      lastAccessedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedVideo obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.clipId)
      ..writeByte(1)
      ..write(obj.filePath)
      ..writeByte(2)
      ..write(obj.sizeBytes)
      ..writeByte(3)
      ..write(obj.downloadedAt)
      ..writeByte(4)
      ..write(obj.lastAccessedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedVideoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
