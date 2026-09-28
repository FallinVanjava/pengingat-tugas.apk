import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../services/alarm_service.dart';

class AddTaskScreen extends StatefulWidget {
  final TaskModel? taskEdit;
  final DateTime? initialDate;

  const AddTaskScreen({super.key, this.taskEdit, this.initialDate});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _judulController = TextEditingController();
  final _deskripsiController = TextEditingController();

  String _kategori = 'Umum';
  String _prioritas = 'Sedang';
  String _pengulangan = 'Sekali';
  DateTime? _waktuAlarm;
  bool _alarmAktif = true;
  String? _suaraCustomPath;
  String? _suaraCustomNama;
  bool _sedangPreview = false;
  bool _sedangMenyimpan = false;

  bool get _isEdit => widget.taskEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final task = widget.taskEdit!;
      _judulController.text = task.judul;
      _deskripsiController.text = task.deskripsi;
      _kategori = task.kategori;
      _prioritas = task.prioritas;
      _pengulangan = task.pengulangan;
      _waktuAlarm = task.waktuAlarm;
      _alarmAktif = task.alarmAktif;
      _suaraCustomPath = task.suaraCustomPath;
      _suaraCustomNama = task.suaraCustomNama;
    } else if (widget.initialDate != null) {
      final now = DateTime.now();
      _waktuAlarm = DateTime(
        widget.initialDate!.year,
        widget.initialDate!.month,
        widget.initialDate!.day,
        now.hour,
        now.minute,
      );
    }
  }

  @override
  void dispose() {
    _judulController.dispose();
    _deskripsiController.dispose();
    // Hentikan preview jika layar ditutup
    if (_sedangPreview) AlarmService.hentikanSuaraAlarm();
    super.dispose();
  }

  Future<void> _pilihWaktu() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _waktuAlarm ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('id', 'ID'),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_waktuAlarm ?? now),
    );

    if (time == null || !mounted) return;

    var picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // Jika waktu yang dipilih sudah lewat hari ini (untuk tugas sekali),
    // otomatis geser ke hari berikutnya agar alarm pasti terjadwal.
    final messenger = ScaffoldMessenger.of(context);
    if (picked.isBefore(DateTime.now()) && _pengulangan == 'Sekali') {
      picked = picked.add(const Duration(days: 1));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Waktu sudah lewat — alarm digeser ke besok, '
            '${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(picked)}',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    setState(() => _waktuAlarm = picked);
  }

  Future<void> _togglePreviewSuara() async {
    if (_sedangPreview) {
      await AlarmService.hentikanSuaraAlarm();
      if (mounted) setState(() => _sedangPreview = false);
    } else {
      // Set state dulu supaya tombol langsung berubah jadi stop
      if (mounted) setState(() => _sedangPreview = true);
      try {
        await AlarmService.putarSuaraAlarm(filePath: _suaraCustomPath);
      } catch (_) {
        if (mounted) setState(() => _sedangPreview = false);
      }
    }
  }

  Future<void> _pilihSuaraAlarm() async {
    // Hentikan preview dulu jika sedang berjalan
    if (_sedangPreview) {
      await AlarmService.hentikanSuaraAlarm();
      if (mounted) setState(() => _sedangPreview = false);
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) return;

      final file = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = p.basename(file.path);

      final soundsDir = Directory('${appDir.path}/custom_sounds');
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      final savedFile = await file.copy('${soundsDir.path}/$fileName');

      setState(() {
        _suaraCustomPath = savedFile.path;
        _suaraCustomNama = result.files.single.name;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Suara alarm diset: $_suaraCustomNama'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat file audio: $e'),
          ),
        );
      }
    }
  }

  void _hapusSuaraCustom() {
    if (_sedangPreview) {
      AlarmService.hentikanSuaraAlarm();
      _sedangPreview = false;
    }
    setState(() {
      _suaraCustomPath = null;
      _suaraCustomNama = null;
    });
  }

  Color _warnaPrioritas(String p) {
    switch (p) {
      case 'Tinggi':
        return Colors.red.shade400;
      case 'Sedang':
        return Colors.orange.shade400;
      case 'Rendah':
        return Colors.green.shade400;
      default:
        return Colors.blue.shade400;
    }
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate() || _sedangMenyimpan) return;

    setState(() => _sedangMenyimpan = true);
    final provider = context.read<TaskProvider>();
    final messenger = ScaffoldMessenger.of(context);

    // Hentikan preview sebelum keluar
    if (_sedangPreview) {
      await AlarmService.hentikanSuaraAlarm();
      _sedangPreview = false;
    }

    if (_waktuAlarm != null) {
      try {
        final notifGranted = await Permission.notification.isGranted;
        if (!notifGranted) {
          final status = await Permission.notification.request();
          if (!status.isGranted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Izin notifikasi ditolak. Alarm tidak akan bisa ditampilkan!'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        if (Platform.isAndroid) {
          final exactStatus = await Permission.scheduleExactAlarm.status;
          if (!exactStatus.isGranted && mounted) {
            final setExact = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Izin Alarm Tepat Waktu'),
                content: const Text(
                  'Aplikasi membutuhkan izin "Alarm & Pengingat" agar alarm dapat berbunyi tepat waktu. Buka pengaturan untuk mengaktifkannya?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Batal'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Buka Pengaturan'),
                  ),
                ],
              ),
            );

            if (setExact == true) {
              await Permission.scheduleExactAlarm.request();
              await Future.delayed(const Duration(milliseconds: 500));
            }
          }
        }
      } catch (_) {}
    }

    try {
      if (_isEdit) {
        final task = widget.taskEdit!;
        task.judul = _judulController.text.trim();
        task.deskripsi = _deskripsiController.text.trim();
        task.kategori = _kategori;
        task.prioritas = _prioritas;
        task.pengulangan = _pengulangan;
        task.waktuAlarm = _waktuAlarm;
        task.alarmAktif = _alarmAktif && _waktuAlarm != null;
        task.suaraCustomPath = _suaraCustomPath;
        task.suaraCustomNama = _suaraCustomNama;
        await provider.updateTask(task);
      } else {
        await provider.tambahTask(
          judul: _judulController.text.trim(),
          deskripsi: _deskripsiController.text.trim(),
          kategori: _kategori,
          prioritas: _prioritas,
          waktuAlarm: _waktuAlarm,
          pengulangan: _pengulangan,
          suaraCustomPath: _suaraCustomPath,
          suaraCustomNama: _suaraCustomNama,
        );
      }

      if (provider.lastError != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(provider.lastError!),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
        provider.clearError();
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan tugas: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _sedangMenyimpan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Tugas' : 'Tambah Tugas'),
        actions: [
          if (_isEdit)
            IconButton(
              onPressed: () async {
                final provider = context.read<TaskProvider>();
                final navigator = Navigator.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Hapus Tugas'),
                    content: const Text('Yakin ingin menghapus tugas ini?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await provider.hapusTask(widget.taskEdit!);
                  navigator.pop();
                }
              },
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _judulController,
              decoration: InputDecoration(
                labelText: 'Judul Tugas *',
                prefixIcon: const Icon(Icons.title_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Judul wajib diisi' : null,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _deskripsiController,
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                prefixIcon: const Icon(Icons.description_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            _buildLabel('Kategori', Icons.folder_rounded),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Kategori.daftar.map((k) {
                final selected = _kategori == k;
                return FilterChip(
                  label: Text(k),
                  selected: selected,
                  onSelected: (_) => setState(() => _kategori = k),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _buildLabel('Prioritas', Icons.flag_rounded),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Prioritas.daftar.map((p) {
                final selected = _prioritas == p;
                return ChoiceChip(
                  label: Text(p),
                  selected: selected,
                  onSelected: (_) => setState(() => _prioritas = p),
                  selectedColor: _warnaPrioritas(p).withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    color: selected ? _warnaPrioritas(p) : null,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            _buildLabel('Alarm', Icons.alarm_rounded),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    InkWell(
                      onTap: _pilihWaktu,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color:
                                  colorScheme.outline.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _waktuAlarm != null
                                    ? DateFormat(
                                            'EEEE, dd MMMM yyyy - HH:mm',
                                            'id_ID')
                                        .format(_waktuAlarm!)
                                    : 'Pilih tanggal & waktu alarm',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: _waktuAlarm != null
                                      ? colorScheme.onSurface
                                      : colorScheme.onSurface
                                          .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            if (_waktuAlarm != null)
                              IconButton(
                                onPressed: () =>
                                    setState(() => _waktuAlarm = null),
                                icon: const Icon(Icons.close_rounded),
                                iconSize: 18,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_waktuAlarm != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded,
                              size: 18),
                          const SizedBox(width: 8),
                          const Text('Aktifkan alarm'),
                          const Spacer(),
                          Switch(
                            value: _alarmAktif,
                            onChanged: (v) =>
                                setState(() => _alarmAktif = v),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // ── Nada Alarm ──────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.my_library_music_rounded,
                                    size: 18, color: colorScheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Nada Alarm',
                                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      Text(
                                        _suaraCustomNama ?? 'Suara default HP',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _togglePreviewSuara,
                                  icon: Icon(
                                    _sedangPreview
                                        ? Icons.stop_circle_rounded
                                        : Icons.play_circle_rounded,
                                    size: 18,
                                    color: _sedangPreview
                                        ? Colors.red.shade400
                                        : colorScheme.primary,
                                  ),
                                  label: Text(
                                    _sedangPreview ? 'Stop Preview' : 'Cek Suara',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: _pilihSuaraAlarm,
                                  icon: const Icon(Icons.audio_file_rounded, size: 16),
                                  label: const Text('Pilih Audio', style: TextStyle(fontSize: 12)),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                                if (_suaraCustomPath != null)
                                  IconButton(
                                    onPressed: _hapusSuaraCustom,
                                    tooltip: 'Reset ke default',
                                    icon: const Icon(Icons.delete_outline_rounded,
                                        color: Colors.red, size: 18),
                                    padding: const EdgeInsets.all(4),
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_waktuAlarm != null) ...[
              _buildLabel('Pengulangan', Icons.repeat_rounded),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: Pengulangan.daftar.map((p) {
                  final selected = _pengulangan == p;
                  return FilterChip(
                    label: Text(p),
                    selected: selected,
                    onSelected: (_) =>
                        setState(() => _pengulangan = p),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _sedangMenyimpan ? null : _simpan,
              icon: _sedangMenyimpan
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isEdit ? Icons.save_rounded : Icons.add_task_rounded),
              label: Text(_sedangMenyimpan
                  ? 'Menyimpan...'
                  : (_isEdit ? 'Simpan Perubahan' : 'Tambah Tugas')),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
