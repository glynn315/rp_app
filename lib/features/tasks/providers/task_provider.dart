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
  // Starts with an empty task list. Real data should arrive via addTask /
  // an API-backed load method once the tasks endpoint is wired up.
  TaskNotifier() : super(const TaskState(tasks: []));

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
