import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  static const String _sessionKey = 'logged_in_user_id';
  static const String _biometrikUsernameKey = 'biometrik_saved_username';

  final LocalAuthentication _localAuth = LocalAuthentication();
  UserModel? _currentUser;
  bool _isLoading = true;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  /// Inisialisasi awal — cek apakah ada sesi login aktif
  Future<void> initSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_sessionKey);

      if (savedId != null) {
        final user = DatabaseService.ambilUserById(savedId);
        if (user != null) {
          _currentUser = user;
          await DatabaseService.initUserSession(user.id);
        } else {
          await prefs.remove(_sessionKey);
        }
      }
    } catch (e) {
      debugPrint('Gagal inisialisasi sesi auth: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String username, String password) async {
    final user = DatabaseService.verifikasiUser(username, password);
    if (user == null) {
      throw Exception('Username atau password salah');
    }

    _currentUser = user;
    await DatabaseService.initUserSession(user.id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, user.id);
    // Simpan username terakhir yang berhasil masuk (untuk keperluan biometrik)
    await prefs.setString(_biometrikUsernameKey, user.username);

    notifyListeners();
  }

  Future<void> register(String username, String password) async {
    if (username.trim().length < 3) {
      throw Exception('Username minimal 3 karakter');
    }
    if (password.length < 4) {
      throw Exception('Password minimal 4 karakter');
    }

    final user = await DatabaseService.daftarUser(username, password);
    
    // Auto-login setelah daftar
    _currentUser = user;
    await DatabaseService.initUserSession(user.id);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, user.id);
    await prefs.setString(_biometrikUsernameKey, user.username);

    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    await DatabaseService.closeUserSession();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);

    notifyListeners();
  }

  // ── Biometrik (Sidik Jari / Face Unlock) ───────────────────────────────────

  /// Cek apakah perangkat mendukung autentikasi biometrik
  Future<bool> get isBiometrikHardwareAvailable async {
    try {
      final canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      return canAuthenticate;
    } catch (_) {
      return false;
    }
  }

  /// Cek apakah biometrik aktif untuk user spesifik yang terdaftar di HP ini
  Future<bool> get isBiometrikAktifUntukAkunIni async {
    if (!await isBiometrikHardwareAvailable) return false;
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString(_biometrikUsernameKey);
    if (savedUsername == null) return false;

    // Cari user di database
    try {
      final user = DatabaseService.usersBox.values.firstWhere(
        (u) => u.username == savedUsername,
      );
      return user.biometrikAktif;
    } catch (_) {
      return false;
    }
  }

  /// Set status keaktifan biometrik (untuk di halaman Pengaturan)
  Future<void> setBiometrikAktif(bool aktif) async {
    if (_currentUser == null) return;
    _currentUser!.biometrikAktif = aktif;
    await DatabaseService.updateUser(_currentUser!);
    notifyListeners();
  }

  /// Jalankan autentikasi biometrik lalu login otomatis
  Future<bool> loginDenganBiometrik() async {
    if (!await isBiometrikAktifUntukAkunIni) return false;

    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString(_biometrikUsernameKey);
    if (savedUsername == null) return false;

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Pindai sidik jari atau Face ID untuk masuk ke akun Anda',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        // Cari user yang bersangkutan
        final user = DatabaseService.usersBox.values.firstWhere(
          (u) => u.username == savedUsername,
        );
        _currentUser = user;
        await DatabaseService.initUserSession(user.id);
        await prefs.setString(_sessionKey, user.id);
        notifyListeners();
        return true;
      }
    } on PlatformException catch (e) {
      debugPrint('Error autentikasi biometrik: $e');
    }
    return false;
  }
}
