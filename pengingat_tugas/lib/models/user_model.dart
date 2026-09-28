import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 1)
class UserModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String username;

  @HiveField(2)
  String passwordHash;

  @HiveField(3)
  DateTime tanggalDibuat;

  @HiveField(4)
  bool biometrikAktif;

  UserModel({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.tanggalDibuat,
    this.biometrikAktif = false,
  });
}
