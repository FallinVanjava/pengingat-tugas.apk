import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../services/database_service.dart';
import '../services/alarm_service.dart';

class TaskProvider extends ChangeNotifier {
  static const String _notifSeqKey = 'notification_id_seq';

  List<TaskModel> _tasks = [];
  final Uuid _uuid = const Uuid();

  /// Pesan error/peringatan terakhir (misal alarm gagal dijadwalkan)
  String? _lastError;

  List<TaskModel> get tasks => _tasks;  
  String? get lastError => _lastError;

  void clearError() {
    _lastError = null;
  }

  void clearTasks() {
    _tasks = [];
    _lastError = null;
    notifyListeners();
  }

  /// Menghasilkan ID notifikasi unik berurutan agar tidak pernah tabrakan.
  Future<int> _buatNotificationId() async {
    final prefs = await SharedPreferences.getInstance();
    final seq = (prefs.getInt(_notifSeqKey) ?? 0) + 1;
    await prefs.setInt(_notifSeqKey, seq);
    // Jaga agar tetap dalam rentang aman int32 Android
    return seq % 2000000000;
  }

  List<TaskModel> get tasksBelumSelesai =>
      _tasks.where((t) => !t.selesai).toList();

  List<TaskModel> get tasksSelesai =>
      _tasks.where((t) => t.selesai).toList();

  List<TaskModel> get tasksTerlewat {
    final now = DateTime.now();
    final awalHariIni = DateTime(now.year, now.month, now.day);
    return _tasks.where((t) {
      final tgl = t.waktuAlarm ?? t.tanggalDibuat;
      return tgl.isBefore(awalHariIni) && !t.selesai;
    }).toList()
      ..sort((a, b) {
        final aTime = a.waktuAlarm ?? a.tanggalDibuat;
        final bTime = b.waktuAlarm ?? b.tanggalDibuat;
        return aTime.compareTo(bTime);
      });
  }

  List<TaskModel> get tasksHariIni {
    final now = DateTime.now();
    return _tasks.where((t) {
      final tgl = t.waktuAlarm ?? t.tanggalDibuat;
      return tgl.year == now.year &&
          tgl.month == now.month &&
          tgl.day == now.day &&
          !t.selesai;
    }).toList();
  }

  List<TaskModel> get tasksMendatang {
    final now = DateTime.now();
    final akhirHariIni = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return _tasks.where((t) {
      final tgl = t.waktuAlarm ?? t.tanggalDibuat;
      return tgl.isAfter(akhirHariIni) && !t.selesai;
    }).toList()
      ..sort((a, b) {
        final aTime = a.waktuAlarm ?? a.tanggalDibuat;
        final bTime = b.waktuAlarm ?? b.tanggalDibuat;
        return aTime.compareTo(bTime);
      });
  }

  List<TaskModel> tasksUntukTanggal(DateTime tanggal) {
    return _tasks.where((t) {
      final tgl = t.waktuAlarm ?? t.tanggalDibuat;
      return tgl.year == tanggal.year &&
          tgl.month == tanggal.month &&
          tgl.day == tanggal.day;
    }).toList();
  }

  List<TaskModel> tasksByKategori(String kategori) {
    return _tasks.where((t) => t.kategori == kategori && !t.selesai).toList();
  }

  void muatTasks() {
    try {
      _tasks = DatabaseService.ambilSemuaTask();
      _tasks.sort((a, b) {
        final aTime = a.waktuAlarm ?? a.tanggalDibuat;
        final bTime = b.waktuAlarm ?? b.tanggalDibuat;
        return aTime.compareTo(bTime);
      });
    } catch (_) {
      _tasks = [];
    }
    notifyListeners();
  }

  Future<void> tambahTask({
    required String judul,
    String deskripsi = '',
    String kategori = 'Umum',
    String prioritas = 'Sedang',
    DateTime? waktuAlarm,
    String pengulangan = 'Sekali',
    String? suaraCustomPath,
    String? suaraCustomNama,
  }) async {
    final id = _uuid.v4();
    final notifId = await _buatNotificationId();

    final task = TaskModel(
      id: id,
      judul: judul,
      deskripsi: deskripsi,
      kategori: kategori,
      prioritas: prioritas,
      waktuAlarm: waktuAlarm,
      pengulangan: pengulangan,
      tanggalDibuat: DateTime.now(),
      alarmAktif: waktuAlarm != null,
      notificationId: notifId,
      suaraCustomPath: suaraCustomPath,
      suaraCustomNama: suaraCustomNama,
    );

    // 1. Simpan ke database
    await DatabaseService.tambahTask(task);

    // 2. Refresh UI lebih dulu supaya tugas langsung muncul walaupun
    //    penjadwalan alarm gagal (tidak membuat tombol simpan terlihat mati)
    muatTasks();

    // 3. Jadwalkan alarm secara terpisah dengan penanganan error sendiri
    if (task.waktuAlarm != null) {
      try {
        await AlarmService.jadwalkanAlarm(task);
      } catch (e) {
        debugPrint('Gagal menjadwalkan alarm: $e');
        // Pesan user-friendly: detail teknis tetap dicatat di log (debugPrint),
        // jangan ditampilkan mentah-mentah ke pengguna.
        _lastError = 'Alarm belum bisa dijadwalkan. Cek izin "Alarm & pengingat" '
            'dan notifikasi di pengaturan, lalu matikan-on-kan alarm tugas ini.';
        notifyListeners();
      }
    }
  }

  Future<void> updateTask(TaskModel task) async {
    await DatabaseService.updateTask(task);

    muatTasks();

    if (task.waktuAlarm != null && task.alarmAktif) {
      try {
        await AlarmService.jadwalkanAlarm(task);
      } catch (e) {
        debugPrint('Gagal menjadwalkan alarm: $e');
        _lastError = 'Alarm belum bisa dijadwalkan. Cek izin "Alarm & pengingat" '
            'dan notifikasi di pengaturan, lalu matikan-on-kan alarm tugas ini.';
        notifyListeners();
      }
    } else {
      await AlarmService.batalkanAlarm(task.notificationId);
    }
  }

  Future<void> hapusTask(TaskModel task) async {
    try {
      await AlarmService.batalkanAlarm(task.notificationId);
    } catch (e) {
      debugPrint('Gagal membatalkan alarm saat hapus tugas: $e');
    }
    
    try {
      if (task.isInBox) {
        await task.delete();
      } else {
        await DatabaseService.hapusTask(task.id);
      }
    } catch (e) {
      debugPrint('Error saat menghapus tugas: $e. Melakukan fallback...');
      try {
        await DatabaseService.hapusTask(task.id);
      } catch (_) {}
    }
    
    muatTasks();
  }

  Future<void> toggleSelesai(TaskModel task) async {
    task.selesai = !task.selesai;
    if (task.selesai) {
      await AlarmService.batalkanAlarm(task.notificationId);
    } else if (task.waktuAlarm != null && task.alarmAktif) {
      await AlarmService.jadwalkanAlarm(task);
    }
    await DatabaseService.updateTask(task);
    muatTasks();
  }

  Future<void> toggleAlarm(TaskModel task) async {
    task.alarmAktif = !task.alarmAktif;
    if (task.alarmAktif && task.waktuAlarm != null) {
      await AlarmService.jadwalkanAlarm(task);
    } else {
      await AlarmService.batalkanAlarm(task.notificationId);
    }
    await DatabaseService.updateTask(task);
    muatTasks();
  }

  Map<DateTime, List<TaskModel>> get eventsMap {
    final Map<DateTime, List<TaskModel>> events = {};
    for (final task in _tasks) {
      final date = task.waktuAlarm ?? task.tanggalDibuat;
      final key = DateTime(date.year, date.month, date.day);
      if (events[key] == null) {
        events[key] = [];
      }
      events[key]!.add(task);
    }
    return events;
  }
}
