import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 0)
class TaskModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String judul;

  @HiveField(2)
  String deskripsi;

  @HiveField(3)
  String kategori;

  @HiveField(4)
  String prioritas;

  @HiveField(5)
  DateTime? waktuAlarm;

  @HiveField(6)
  String pengulangan;

  @HiveField(7)
  bool selesai;

  @HiveField(8)
  DateTime tanggalDibuat;

  @HiveField(9)
  bool alarmAktif;

  @HiveField(10)
  int notificationId;

  @HiveField(11)
  String? suaraCustomPath;

  @HiveField(12)
  String? suaraCustomNama;

  TaskModel({
    required this.id,
    required this.judul,
    this.deskripsi = '',
    this.kategori = 'Umum',
    this.prioritas = 'Sedang',
    this.waktuAlarm,
    this.pengulangan = 'Sekali',
    this.selesai = false,
    required this.tanggalDibuat,
    this.alarmAktif = true,
    this.notificationId = 0,
    this.suaraCustomPath,
    this.suaraCustomNama,
  });
}

class Kategori {
  static const List<String> daftar = [
    'Umum',
    'Pekerjaan',
    'Pribadi',
    'Sekolah',
    'Kesehatan',
    'Belanja',
    'Lainnya',
  ];
}

class Prioritas {
  static const String tinggi = 'Tinggi';
  static const String sedang = 'Sedang';
  static const String rendah = 'Rendah';

  static const List<String> daftar = [tinggi, sedang, rendah];
}

class Pengulangan {
  static const String sekali = 'Sekali';
  static const String harian = 'Harian';
  static const String mingguan = 'Mingguan';
  static const String bulanan = 'Bulanan';

  static const List<String> daftar = [sekali, harian, mingguan, bulanan];
}
