// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_clip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FavoriteClipAdapter extends TypeAdapter<FavoriteClip> {
  @override
  final int typeId = 11;

  @override
  FavoriteClip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoriteClip(
      clipId: fields[0] as String,
      cameraId: fields[1] as String,
      startedAt: fields[2] as DateTime,
      durationSec: fields[3] as double,
      filePath: fields[4] as String,
      sizeBytes: fields[5] as int,
      favoritedAt: fields[6] as DateTime,
      ownerId: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteClip obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.clipId)
      ..writeByte(1)
      ..write(obj.cameraId)
      ..writeByte(2)
      ..write(obj.startedAt)
      ..writeByte(3)
      ..write(obj.durationSec)
      ..writeByte(4)
      ..write(obj.filePath)
      ..writeByte(5)
      ..write(obj.sizeBytes)
      ..writeByte(6)
      ..write(obj.favoritedAt)
      ..writeByte(7)
      ..write(obj.ownerId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteClipAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
