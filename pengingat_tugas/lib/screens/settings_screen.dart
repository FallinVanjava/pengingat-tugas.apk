import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/theme_provider.dart';
import '../services/alarm_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _izinNotifikasi;
  bool? _izinExactAlarm;
  bool? _izinBaterai;
  bool _canUseBiometricHardware = false;
  bool _isBiometrikUserActive = false;

  @override
  void initState() {
    super.initState();
    _muatStatusIzin();
    _cekBiometrikStatus();
  }

  Future<void> _muatStatusIzin() async {
    final notif = await Permission.notification.isGranted;
    final exact = Platform.isAndroid ? await AlarmService.cekIzinExactAlarm() : true;
    final baterai = Platform.isAndroid ? await Permission.ignoreBatteryOptimizations.isGranted : true;
    if (mounted) {
      setState(() {
        _izinNotifikasi = notif;
        _izinExactAlarm = exact;
        _izinBaterai = baterai;
      });
    }
  }

  Future<void> _cekBiometrikStatus() async {
    final auth = context.read<AuthProvider>();
    final hasHardware = await auth.isBiometrikHardwareAvailable;
    final isActive = await auth.isBiometrikAktifUntukAkunIni;
    if (mounted) {
      setState(() {
        _canUseBiometricHardware = hasHardware;
        _isBiometrikUserActive = isActive;
      });
    }
  }

  Future<void> _mintaIzinBaterai() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (mounted) {
      setState(() => _izinBaterai = status.isGranted);
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Izin baterai diperlukan agar alarm tetap bunyi saat HP sleep. '
              'Buka Pengaturan HP → Baterai → Pengoptimalan Baterai → cari aplikasi ini → pilih "Jangan optimalkan".',
            ),
            duration: Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _mintaIzinExactAlarm() async {
    await AlarmService.bukaSettingExactAlarm();
    await Future.delayed(const Duration(seconds: 1));
    await _muatStatusIzin();
  }

  Future<void> _mintaIzinNotifikasi() async {
    final status = await Permission.notification.request();
    if (mounted) setState(() => _izinNotifikasi = status.isGranted);
  }

  Future<void> _toggleBiometrik(bool val) async {
    final auth = context.read<AuthProvider>();
    await auth.setBiometrikAktif(val);
    await _cekBiometrikStatus();
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final taskProvider = context.read<TaskProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun Anda?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Reset list tugas di provider agar bersih
      taskProvider.clearTasks();
      
      await auth.logout();

      messenger.showSnackBar(
        const SnackBar(content: Text('Anda telah keluar akun')),
      );

      // Pop semua route ke root (yang sekarang sudah berubah menjadi LoginScreen)
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeProvider = context.watch<ThemeProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final authProvider = context.watch<AuthProvider>();
    final username = authProvider.currentUser?.username ?? 'Pengguna';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () async {
              await _muatStatusIzin();
              await _cekBiometrikStatus();
            },
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh status izin',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header Akun ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.person_rounded,
                      color: colorScheme.onPrimaryContainer, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${username[0].toUpperCase()}${username.substring(1)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Akun Lokal Terproteksi',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded, color: Colors.red),
                  tooltip: 'Keluar Akun',
                ),
              ],
            ),
          ),
          const Divider(height: 24),

          _buildSectionTitle(context, 'Tampilan'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Mode Gelap'),
                  subtitle: const Text('Aktifkan tampilan gelap'),
                  secondary: Icon(
                    themeProvider.isDarkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: colorScheme.primary,
                  ),
                  value: themeProvider.isDarkMode,
                  onChanged: (_) => themeProvider.toggleTheme(),
                ),
                if (_canUseBiometricHardware) ...[
                  const Divider(height: 1, indent: 56),
                  SwitchListTile(
                    title: Text(Platform.isIOS ? 'Login Biometrik / Face ID' : 'Login Sidik Jari'),
                    subtitle: Text(Platform.isIOS ? 'Gunakan Face ID / Touch ID untuk login cepat' : 'Gunakan sidik jari untuk login cepat'),
                    secondary: Icon(
                      Platform.isIOS ? Icons.lock_person_rounded : Icons.fingerprint_rounded,
                      color: colorScheme.primary,
                    ),
                    value: _isBiometrikUserActive,
                    onChanged: _toggleBiometrik,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Panel Izin ─────────────────────────────────────────────
          _buildSectionTitle(context, 'Izin Alarm'),
          Card(
            child: Column(
              children: [
                _IzinTile(
                  icon: Icons.notifications_rounded,
                  judul: 'Notifikasi',
                  subjudul: 'Wajib untuk menampilkan alarm',
                  status: _izinNotifikasi,
                  onPerbaiki: _mintaIzinNotifikasi,
                ),
                if (Platform.isAndroid) ...[
                  const Divider(height: 1, indent: 56),
                  _IzinTile(
                    icon: Icons.alarm_rounded,
                    judul: 'Alarm & Pengingat',
                    subjudul: 'Izin exact alarm agar tepat waktu',
                    status: _izinExactAlarm,
                    onPerbaiki: _mintaIzinExactAlarm,
                  ),
                  const Divider(height: 1, indent: 56),
                  _IzinTile(
                    icon: Icons.battery_saver_rounded,
                    judul: 'Pengecualian Baterai',
                    subjudul: 'Mencegah sistem mematikan alarm',
                    status: _izinBaterai,
                    onPerbaiki: _mintaIzinBaterai,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Alarm ──────────────────────────────────────────────────
          _buildSectionTitle(context, 'Alarm'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.volume_up_rounded,
                      color: colorScheme.primary),
                  title: const Text('Test Suara Alarm'),
                  subtitle: const Text('Putar suara alarm default HP'),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await AlarmService.putarSuaraAlarm();
                    Future.delayed(const Duration(seconds: 5), () {
                      AlarmService.hentikanSuaraAlarm();
                    });
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Memutar suara alarm... (berhenti otomatis 5 detik)'),
                        duration: Duration(seconds: 5),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Icon(Icons.alarm_off_rounded,
                      color: Colors.red.shade400),
                  title: const Text('Batalkan Semua Alarm'),
                  subtitle: const Text('Matikan semua alarm yang aktif'),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Batalkan Semua Alarm'),
                        content: const Text(
                            'Apakah Anda yakin ingin membatalkan semua alarm?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(
                                backgroundColor: Colors.red),
                            child: const Text('Ya, Batalkan'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await AlarmService.batalkanSemuaAlarm();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Semua alarm telah dibatalkan'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle(context, 'Statistik'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _StatRow(
                    icon: Icons.task_rounded,
                    label: 'Total Tugas',
                    value: '${taskProvider.tasks.length}',
                    color: colorScheme.primary,
                  ),
                  const Divider(height: 16),
                  _StatRow(
                    icon: Icons.check_circle_rounded,
                    label: 'Tugas Selesai',
                    value: '${taskProvider.tasksSelesai.length}',
                    color: Colors.green.shade400,
                  ),
                  const Divider(height: 16),
                  _StatRow(
                    icon: Icons.pending_rounded,
                    label: 'Belum Selesai',
                    value: '${taskProvider.tasksBelumSelesai.length}',
                    color: Colors.orange.shade400,
                  ),
                  const Divider(height: 16),
                  _StatRow(
                    icon: Icons.alarm_rounded,
                    label: 'Tugas Hari Ini',
                    value: '${taskProvider.tasksHariIni.length}',
                    color: colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildSectionTitle(context, 'Tentang Aplikasi'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.task_alt_rounded,
                          color: colorScheme.onPrimaryContainer,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengingat Tugas',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Versi 1.0.0',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aplikasi pengingat tugas dengan alarm yang membantu Anda mengatur jadwal dan tugas sehari-hari.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.code_rounded,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text(
                        'Dikembangkan oleh',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Fadhil',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _IzinTile extends StatelessWidget {
  final IconData icon;
  final String judul;
  final String subjudul;
  final bool? status;
  final VoidCallback onPerbaiki;

  const _IzinTile({
    required this.icon,
    required this.judul,
    required this.subjudul,
    required this.status,
    required this.onPerbaiki,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final granted = status ?? false;
    final loading = status == null;

    return ListTile(
      leading: Icon(icon,
          color: loading
              ? colorScheme.outline
              : granted
                  ? Colors.green.shade500
                  : Colors.red.shade400),
      title: Text(judul),
      subtitle: Text(subjudul),
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : granted
              ? Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade500, size: 22)
              : FilledButton.tonal(
                  onPressed: onPerbaiki,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade700,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Izinkan', style: TextStyle(fontSize: 12)),
                ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
