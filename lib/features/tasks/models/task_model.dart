enum TaskStatus { pending, inProgress, completed, cancelled }

enum TaskPriority { low, medium, high, urgent }

enum TaskCategory { general, project, maintenance, administrative, operations }

enum RecurrenceType { daily, weekly, monthly }

extension TaskStatusX on TaskStatus {
  String get label => switch (this) {
        TaskStatus.pending => 'Pending',
        TaskStatus.inProgress => 'In Progress',
        TaskStatus.completed => 'Completed',
        TaskStatus.cancelled => 'Cancelled',
      };
}

extension TaskPriorityX on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
        TaskPriority.urgent => 'Urgent',
      };
}

extension TaskCategoryX on TaskCategory {
  String get label => switch (this) {
        TaskCategory.general => 'General',
        TaskCategory.project => 'Project',
        TaskCategory.maintenance => 'Maintenance',
        TaskCategory.administrative => 'Administrative',
        TaskCategory.operations => 'Operations',
      };
}

extension RecurrenceTypeX on RecurrenceType {
  String get label => switch (this) {
        RecurrenceType.daily => 'Daily',
        RecurrenceType.weekly => 'Weekly',
        RecurrenceType.monthly => 'Monthly',
      };
}

/// Image attachment captured for a daily update. Stored as a data URL so the
/// in-memory state can survive route changes without depending on a file
/// path that may be sandboxed.
class TaskAttachment {
  final String id;
  final String name;
  final String mimeType;
  final String dataUrl;

  const TaskAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.dataUrl,
  });

  bool get isImage => mimeType.startsWith('image/');
}

/// One progress entry against a task. `date` is the report date (yyyy-MM-dd
/// for grouping), `createdAt` is when it was actually logged.
class TaskDailyUpdate {
  final String id;
  final String date; // yyyy-MM-dd — groups display by day
  final String note;
  final int? progress; // 0–100; null when not provided
  final bool markedDone;
  final List<TaskAttachment> attachments;
  final DateTime createdAt;

  const TaskDailyUpdate({
    required this.id,
    required this.date,
    required this.note,
    this.progress,
    this.markedDone = false,
    this.attachments = const [],
    required this.createdAt,
  });
}

class Task {
  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final TaskCategory category;
  final DateTime? dueDate;
  final bool isRecurring;
  final RecurrenceType? recurrenceType;
  final DateTime createdAt;
  final String? assignedTo;
  final List<TaskDailyUpdate> dailyUpdates;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    required this.category,
    this.dueDate,
    this.isRecurring = false,
    this.recurrenceType,
    required this.createdAt,
    this.assignedTo,
    this.dailyUpdates = const [],
  });

  Task copyWith({
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    TaskCategory? category,
    DateTime? dueDate,
    bool? isRecurring,
    RecurrenceType? recurrenceType,
    String? assignedTo,
    List<TaskDailyUpdate>? dailyUpdates,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      createdAt: createdAt,
      assignedTo: assignedTo ?? this.assignedTo,
      dailyUpdates: dailyUpdates ?? this.dailyUpdates,
    );
  }
}
