import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';

class TaskState {
  final List<Task> tasks;
  final bool isLoading;

  const TaskState({required this.tasks, this.isLoading = false});

  TaskState copyWith({List<Task>? tasks, bool? isLoading}) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class TaskNotifier extends StateNotifier<TaskState> {
  TaskNotifier() : super(const TaskState(tasks: [])) {
    _loadMockData();
  }

  void _loadMockData() {
    final now = DateTime.now();
    state = state.copyWith(tasks: [
      Task(
        id: '1',
        title: 'Prepare Monthly Report',
        description: 'Compile and submit the monthly operations report to management.',
        priority: TaskPriority.high,
        status: TaskStatus.inProgress,
        category: TaskCategory.administrative,
        dueDate: now.add(const Duration(days: 2)),
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      Task(
        id: '2',
        title: 'Equipment Maintenance Check',
        description: 'Perform routine maintenance checks on all floor equipment.',
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        category: TaskCategory.maintenance,
        dueDate: now.add(const Duration(days: 5)),
        isRecurring: true,
        recurrenceType: RecurrenceType.monthly,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Task(
        id: '3',
        title: 'Team Meeting — Q2 Planning',
        description: 'Facilitate Q2 planning session with department heads.',
        priority: TaskPriority.urgent,
        status: TaskStatus.pending,
        category: TaskCategory.operations,
        dueDate: now.add(const Duration(days: 1)),
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Task(
        id: '4',
        title: 'Update Employee Records',
        priority: TaskPriority.low,
        status: TaskStatus.completed,
        category: TaskCategory.administrative,
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      Task(
        id: '5',
        title: 'Daily Stand-up Summary',
        priority: TaskPriority.medium,
        status: TaskStatus.pending,
        category: TaskCategory.general,
        isRecurring: true,
        recurrenceType: RecurrenceType.daily,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ]);
  }

  void addTask(Task task) {
    state = state.copyWith(tasks: [task, ...state.tasks]);
  }

  void updateTask(Task updated) {
    state = state.copyWith(
      tasks: state.tasks.map((t) => t.id == updated.id ? updated : t).toList(),
    );
  }

  void updateStatus(String taskId, TaskStatus newStatus) {
    state = state.copyWith(
      tasks: state.tasks
          .map((t) => t.id == taskId ? t.copyWith(status: newStatus) : t)
          .toList(),
    );
  }

  void deleteTask(String taskId) {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != taskId).toList(),
    );
  }

  List<Task> getByStatus(TaskStatus status) =>
      state.tasks.where((t) => t.status == status).toList();

  List<Task> getRecurring() => state.tasks.where((t) => t.isRecurring).toList();
}

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>(
  (ref) => TaskNotifier(),
);
