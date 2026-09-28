import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../services/alarm_service.dart';

class AlarmDialog extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onMatikan;

  const AlarmDialog({
    super.key,
    required this.task,
    required this.onMatikan,
  });

  @override
  State<AlarmDialog> createState() => _AlarmDialogState();
}

class _AlarmDialogState extends State<AlarmDialog> {
  @override
  void initState() {
    super.initState();
    // Batalkan notifikasi aktif agar suara insistent/loop bawaan sistem berhenti,
    // lalu ambil alih pemutaran suara melalui aplikasi agar konsisten
    AlarmService.batalkanAlarm(widget.task.notificationId);
    AlarmService.putarSuaraAlarm(filePath: widget.task.suaraCustomPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // Menolak tombol back agar alarm tidak di-dismiss tanpa merespon
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.alarm_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            const Text('Alarm!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task.judul,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.task.deskripsi.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.task.deskripsi),
            ],
            const SizedBox(height: 16),
            const Text('Tunda alarm:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [5, 10, 15, 30].map((menit) {
                return OutlinedButton(
                  onPressed: () async {
                    await AlarmService.batalkanAlarm(widget.task.notificationId);
                    await AlarmService.hentikanSuaraAlarm();
                    await AlarmService.snoozeAlarm(widget.task, menit);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text('$menit mnt'),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () async {
              await AlarmService.batalkanAlarm(widget.task.notificationId);
              await AlarmService.hentikanSuaraAlarm();
              widget.onMatikan();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.alarm_off_rounded),
            label: const Text('Matikan'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
