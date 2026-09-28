// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskModelAdapter extends TypeAdapter<TaskModel> {
  @override
  final int typeId = 0;

  @override
  TaskModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskModel(
      id: fields[0] as String,
      judul: fields[1] as String,
      deskripsi: fields[2] as String,
      kategori: fields[3] as String,
      prioritas: fields[4] as String,
      waktuAlarm: fields[5] as DateTime?,
      pengulangan: fields[6] as String,
      selesai: fields[7] as bool,
      tanggalDibuat: fields[8] as DateTime,
      alarmAktif: fields[9] as bool,
      notificationId: fields[10] as int,
      suaraCustomPath: fields[11] as String?,
      suaraCustomNama: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, TaskModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.judul)
      ..writeByte(2)
      ..write(obj.deskripsi)
      ..writeByte(3)
      ..write(obj.kategori)
      ..writeByte(4)
      ..write(obj.prioritas)
      ..writeByte(5)
      ..write(obj.waktuAlarm)
      ..writeByte(6)
      ..write(obj.pengulangan)
      ..writeByte(7)
      ..write(obj.selesai)
      ..writeByte(8)
      ..write(obj.tanggalDibuat)
      ..writeByte(9)
      ..write(obj.alarmAktif)
      ..writeByte(10)
      ..write(obj.notificationId)
      ..writeByte(11)
      ..write(obj.suaraCustomPath)
      ..writeByte(12)
      ..write(obj.suaraCustomNama);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
