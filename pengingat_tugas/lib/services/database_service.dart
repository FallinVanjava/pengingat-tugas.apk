import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/task_model.dart';
import '../models/user_model.dart';

class DatabaseService {
  static const String _usersBoxName = 'users';
  static Box<UserModel>? _usersBox;
  static Box<TaskModel>? _tasksBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Register Adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TaskModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(UserModelAdapter());
    }

    _usersBox = await Hive.openBox<UserModel>(_usersBoxName);
  }

  // ── Database User/Akun ─────────────────────────────────────────────────────

  static Box<UserModel> get usersBox {
    if (_usersBox == null || !_usersBox!.isOpen) {
      throw Exception('Database User belum diinisialisasi');
    }
    return _usersBox!;
  }

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static Future<UserModel> daftarUser(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    
    // Validasi duplikasi
    final exists = usersBox.values.any((u) => u.username == cleanUsername);
    if (exists) {
      throw Exception('Username "$username" sudah digunakan');
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final user = UserModel(
      id: id,
      username: cleanUsername,
      passwordHash: hashPassword(password),
      tanggalDibuat: DateTime.now(),
    );

    await usersBox.put(id, user);
    return user;
  }

  static UserModel? verifikasiUser(String username, String password) {
    final cleanUsername = username.trim().toLowerCase();
    final hash = hashPassword(password);

    try {
      return usersBox.values.firstWhere(
        (u) => u.username == cleanUsername && u.passwordHash == hash,
      );
    } catch (_) {
      return null;
    }
  }

  static UserModel? ambilUserById(String id) {
    return usersBox.get(id);
  }

  static Future<void> updateUser(UserModel user) async {
    await usersBox.put(user.id, user);
  }

  // ── Database Tugas (Isolated per-User) ──────────────────────────────────────

  /// Membuka box tugas khusus untuk user yang sedang aktif
  static Future<void> initUserSession(String userId) async {
    // Tutup box user sebelumnya jika ada
    if (_tasksBox != null && _tasksBox!.isOpen) {
      await _tasksBox!.close();
    }
    _tasksBox = await Hive.openBox<TaskModel>('tasks_$userId');
  }

  static Future<void> closeUserSession() async {
    if (_tasksBox != null && _tasksBox!.isOpen) {
      await _tasksBox!.close();
      _tasksBox = null;
    }
  }

  static Box<TaskModel> get tasksBox {
    if (_tasksBox == null || !_tasksBox!.isOpen) {
      throw Exception('Silakan login terlebih dahulu untuk mengakses tugas');
    }
    return _tasksBox!;
  }

  static Future<void> tambahTask(TaskModel task) async {
    await tasksBox.put(task.id, task);
  }

  static Future<void> updateTask(TaskModel task) async {
    await tasksBox.put(task.id, task);
  }

  static Future<void> hapusTask(String id) async {
    await tasksBox.delete(id);
  }

  static List<TaskModel> ambilSemuaTask() {
    return tasksBox.values.toList();
  }

  static TaskModel? ambilTaskById(String id) {
    return tasksBox.get(id);
  }
}
