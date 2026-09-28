import 'package:flutter_test/flutter_test.dart';
import 'package:pengingat_tugas/models/task_model.dart';
import 'package:pengingat_tugas/models/user_model.dart';
import 'package:pengingat_tugas/services/database_service.dart';

void main() {
  group('Model & Logic Tests', () {
    test('TaskModel creation and defaults', () {
      final task = TaskModel(
        id: '123',
        judul: 'Belajar Flutter',
        tanggalDibuat: DateTime(2026, 1, 1),
      );

      expect(task.id, '123');
      expect(task.judul, 'Belajar Flutter');
      expect(task.kategori, 'Umum');
      expect(task.prioritas, 'Sedang');
      expect(task.pengulangan, 'Sekali');
      expect(task.selesai, false);
      expect(task.alarmAktif, true);
    });

    test('UserModel creation and hashing', () {
      final hash1 = DatabaseService.hashPassword('rahasia123');
      final hash2 = DatabaseService.hashPassword('rahasia123');
      final hash3 = DatabaseService.hashPassword('berbeda');

      expect(hash1, hash2);
      expect(hash1, isNot(equals(hash3)));

      final user = UserModel(
        id: 'u1',
        username: 'fadhil',
        passwordHash: hash1,
        tanggalDibuat: DateTime(2026, 1, 1),
        biometrikAktif: true,
      );

      expect(user.username, 'fadhil');
      expect(user.biometrikAktif, true);
    });

    test('Category and Priority constants', () {
      expect(Kategori.daftar, contains('Pekerjaan'));
      expect(Kategori.daftar, contains('Sekolah'));
      expect(Prioritas.daftar, contains(Prioritas.tinggi));
      expect(Prioritas.daftar, contains(Prioritas.sedang));
      expect(Prioritas.daftar, contains(Prioritas.rendah));
      expect(Pengulangan.daftar, contains(Pengulangan.harian));
    });
  });
}
