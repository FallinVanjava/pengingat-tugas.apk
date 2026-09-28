import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../widgets/task_card.dart';
import '../widgets/alarm_dialog.dart';
import '../services/alarm_service.dart';
import 'add_task_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<TaskProvider>().muatTasks();
      try {
        await Permission.notification.request();
      } catch (_) {}
    });

    // Mendaftarkan callback untuk menampilkan Alarm Dialog saat dipicu
    AlarmService.onAlarmTriggered = (taskId) {
      _tampilkanAlarmDialog(taskId);
    };
  }

  void _tampilkanAlarmDialog(String taskId) {
    if (!mounted) return;
    
    final provider = context.read<TaskProvider>();
    // Cari tugas di DB local
    final task = provider.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => TaskModel(
        id: taskId,
        judul: 'Pengingat Tugas',
        tanggalDibuat: DateTime.now(),
      ),
    );

    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa men-dismiss tanpa klik tombol
      builder: (ctx) => AlarmDialog(
        task: task,
        onMatikan: () {
          // Tandai tugas sebagai selesai jika diinginkan, atau cukup matikan alarmnya
          provider.toggleSelesai(task);
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  final List<Widget> _screens = [
    const _HomeContent(),
    const CalendarScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Kalender',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Pengaturan',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddTaskScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Tugas'),
            )
          : null,
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final provider = context.watch<TaskProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengingat Tugas',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _StatsBadge(
              selesai: provider.tasksSelesai.length,
              total: provider.tasks.length,
            ),
          ),
        ],
      ),
      body: provider.tasks.isEmpty
          ? _EmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                provider.muatTasks();
              },
              child: ListView(
                children: [
                  if (provider.tasksTerlewat.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Terlewat',
                      count: provider.tasksTerlewat.length,
                      icon: Icons.warning_amber_rounded,
                      warna: Colors.red.shade400,
                    ),
                    ...provider.tasksTerlewat.map((task) => TaskCard(
                          task: task,
                          onTap: () => _bukaEditTask(context, task),
                          onToggleSelesai: () =>
                              provider.toggleSelesai(task),
                          onHapus: () => provider.hapusTask(task),
                          onToggleAlarm: () => provider.toggleAlarm(task),
                        )),
                  ],
                  if (provider.tasksHariIni.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Hari Ini',
                      count: provider.tasksHariIni.length,
                      icon: Icons.today_rounded,
                    ),
                    ...provider.tasksHariIni.map((task) => TaskCard(
                          task: task,
                          onTap: () => _bukaEditTask(context, task),
                          onToggleSelesai: () =>
                              provider.toggleSelesai(task),
                          onHapus: () => provider.hapusTask(task),
                          onToggleAlarm: () => provider.toggleAlarm(task),
                        )),
                  ],
                  if (provider.tasksMendatang.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Mendatang',
                      count: provider.tasksMendatang.length,
                      icon: Icons.upcoming_rounded,
                    ),
                    ...provider.tasksMendatang.map((task) => TaskCard(
                          task: task,
                          onTap: () => _bukaEditTask(context, task),
                          onToggleSelesai: () =>
                              provider.toggleSelesai(task),
                          onHapus: () => provider.hapusTask(task),
                          onToggleAlarm: () => provider.toggleAlarm(task),
                        )),
                  ],
                  if (provider.tasksSelesai.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Selesai',
                      count: provider.tasksSelesai.length,
                      icon: Icons.check_circle_rounded,
                      warna: Colors.green,
                    ),
                    ...provider.tasksSelesai.map((task) => TaskCard(
                          task: task,
                          onTap: () => _bukaEditTask(context, task),
                          onToggleSelesai: () =>
                              provider.toggleSelesai(task),
                          onHapus: () => provider.hapusTask(task),
                        )),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  void _bukaEditTask(BuildContext context, TaskModel task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(taskEdit: task),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color? warna;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.icon,
    this.warna,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = warna ?? theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBadge extends StatelessWidget {
  final int selesai;
  final int total;

  const _StatsBadge({required this.selesai, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$selesai/$total',
        style: theme.textTheme.labelMedium?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada tugas',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tekan tombol di bawah untuk membuat tugas pertama Anda',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddTaskScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tambah Tugas'),
            ),
          ],
        ),
      ),
    );
  }
}
