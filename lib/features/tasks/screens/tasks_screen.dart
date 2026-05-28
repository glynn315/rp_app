import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/home_screen.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../services/task_notify_service.dart';
import '../widgets/task_card.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _syncing = false;

  static const _tabs = ['All', 'Pending', 'In Progress', 'Done', 'Recurring'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  /// Render the pending-task report as an image and post it to Discord.
  Future<void> _syncToDiscord() async {
    if (_syncing) return;
    final auth = ref.read(authProvider);
    final tasks = ref.read(taskProvider).tasks;
    setState(() => _syncing = true);
    final ok = await TaskNotifyService().syncReport(
      ownerId: auth.user?.employeeId ?? auth.user?.name ?? '',
      ownerName: auth.user?.name ?? 'Unknown',
      tasks: tasks,
      token: auth.token,
    );
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Task report posted to Discord.'
            : 'Could not post the report to Discord.'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);
    final notifier = ref.read(taskProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open menu',
          onPressed: HomeScreen.openDrawer,
        ),
        title: const Text('Tasks'),
        actions: [
          IconButton(
            tooltip: 'Log daily update',
            onPressed: () => context.push('/tasks/daily'),
            icon: const Icon(Icons.edit_note),
          ),
          IconButton(
            tooltip: 'Post report to Discord',
            onPressed: _syncing ? null : _syncToDiscord,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: AppColors.primary,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.secondary,
              unselectedLabelColor: AppColors.textOnPrimary.withValues(alpha: 0.6),
              indicatorColor: AppColors.secondary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tasks/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 3,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All tab: completed/cancelled sink to the bottom, each group
          // sorted by createdAt desc (latest activity first). Mirrors the
          // web TasksScreen ordering.
          _TaskList(tasks: _sortedAll(taskState.tasks), notifier: notifier),
          _TaskList(
            tasks: _sortedByDateDesc(
                taskState.tasks.where((t) => t.status == TaskStatus.pending)),
            notifier: notifier,
          ),
          _TaskList(
            tasks: _sortedByDateDesc(taskState.tasks
                .where((t) => t.status == TaskStatus.inProgress)),
            notifier: notifier,
          ),
          _TaskList(
            tasks: _sortedByDateDesc(taskState.tasks
                .where((t) => t.status == TaskStatus.completed)),
            notifier: notifier,
          ),
          _TaskList(
            tasks: _sortedByDateDesc(
                taskState.tasks.where((t) => t.isRecurring)),
            notifier: notifier,
          ),
        ],
      ),
    );
  }
}

/// Newest-first by createdAt. When the model picks up `dailyUpdates`, swap
/// this to fall back to the latest update's timestamp.
List<Task> _sortedByDateDesc(Iterable<Task> tasks) {
  final out = tasks.toList();
  out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return out;
}

/// All-tab order: active first (pending / in-progress), then
/// completed/cancelled below. Within each group, newest activity first.
List<Task> _sortedAll(Iterable<Task> tasks) {
  int rank(Task t) =>
      t.status == TaskStatus.completed || t.status == TaskStatus.cancelled
          ? 1
          : 0;
  final out = tasks.toList();
  out.sort((a, b) {
    final r = rank(a) - rank(b);
    if (r != 0) return r;
    return b.createdAt.compareTo(a.createdAt);
  });
  return out;
}

class _TaskList extends StatelessWidget {
  final List<Task> tasks;
  final TaskNotifier notifier;

  const _TaskList({required this.tasks, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 56,
              color: AppColors.neutral300,
            ),
            const SizedBox(height: AppDimensions.md),
            const Text(
              'No tasks here',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap + to create a new task',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return TaskCard(
          task: task,
          onTap: () => context.push('/tasks/${task.id}'),
          onStatusChanged: () => _showStatusSheet(context, task),
          onDelete: () => _confirmDelete(context, task.id),
        );
      },
    );
  }

  void _showStatusSheet(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLg)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Update status',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ...TaskStatus.values
                .where((s) => s != TaskStatus.cancelled)
                .map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _statusColor(s),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(s.label),
                    selected: task.status == s,
                    selectedColor: AppColors.primary,
                    onTap: () {
                      notifier.updateStatus(task.id, s);
                      Navigator.pop(context);
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String taskId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              notifier.deleteTask(taskId);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(TaskStatus s) => switch (s) {
        TaskStatus.pending => AppColors.statusPending,
        TaskStatus.inProgress => AppColors.statusInProgress,
        TaskStatus.completed => AppColors.statusApproved,
        TaskStatus.cancelled => AppColors.statusRejected,
      };
}
