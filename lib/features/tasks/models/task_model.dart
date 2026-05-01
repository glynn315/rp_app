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
    );
  }
}
