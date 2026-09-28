import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback onTap;
  final VoidCallback onToggleSelesai;
  final VoidCallback onHapus;
  final VoidCallback? onToggleAlarm;

  const TaskCard({
    super.key,
    required this.task,
    required this.onTap,
    required this.onToggleSelesai,
    required this.onHapus,
    this.onToggleAlarm,
  });

  Color _warnaPrioritas(BuildContext context) {
    switch (task.prioritas) {
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

  IconData _ikonKategori() {
    switch (task.kategori) {
      case 'Pekerjaan':
        return Icons.work_rounded;
      case 'Pribadi':
        return Icons.person_rounded;
      case 'Sekolah':
        return Icons.school_rounded;
      case 'Kesehatan':
        return Icons.favorite_rounded;
      case 'Belanja':
        return Icons.shopping_cart_rounded;
      default:
        return Icons.task_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final warnaPrioritas = _warnaPrioritas(context);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Hapus Tugas'),
            content: Text('Hapus "${task.judul}"?'),
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
      },
      onDismissed: (_) => onHapus(),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: warnaPrioritas,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Center(
                    child: Checkbox(
                      value: task.selesai,
                      onChanged: (_) => onToggleSelesai(),
                      activeColor: colorScheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          task.judul,
                          style: theme.textTheme.titleSmall?.copyWith(
                            decoration: task.selesai
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.selesai
                                ? colorScheme.onSurface.withValues(alpha: 0.5)
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (task.deskripsi.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.deskripsi,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_ikonKategori(),
                                    size: 13,
                                    color: colorScheme.primary.withValues(alpha: 0.8)),
                                const SizedBox(width: 4),
                                Text(
                                  task.kategori,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.primary.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            if (task.waktuAlarm != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    task.alarmAktif
                                        ? Icons.alarm_rounded
                                        : Icons.alarm_off_rounded,
                                    size: 13,
                                    color: task.alarmAktif
                                        ? colorScheme.secondary
                                        : colorScheme.onSurface.withValues(alpha: 0.4),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd MMM, HH:mm', 'id_ID')
                                        .format(task.waktuAlarm!),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: task.alarmAktif
                                        ? colorScheme.secondary
                                        : colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            if (task.pengulangan != 'Sekali' &&
                                task.waktuAlarm != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.repeat_rounded,
                                      size: 13,
                                      color: colorScheme.tertiary.withValues(alpha: 0.8)),
                                  const SizedBox(width: 2),
                                  Text(
                                    task.pengulangan,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.tertiary.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onToggleAlarm != null && task.waktuAlarm != null)
                    Center(
                      child: IconButton(
                        onPressed: onToggleAlarm,
                        icon: Icon(
                          task.alarmAktif
                              ? Icons.alarm_rounded
                              : Icons.alarm_off_rounded,
                          color: task.alarmAktif
                              ? colorScheme.primary
                              : colorScheme.onSurface.withValues(alpha: 0.3),
                        ),
                        iconSize: 22,
                        tooltip: task.alarmAktif ? 'Nonaktifkan Alarm' : 'Aktifkan Alarm',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
