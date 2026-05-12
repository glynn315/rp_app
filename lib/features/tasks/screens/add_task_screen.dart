import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

class AddTaskScreen extends ConsumerStatefulWidget {
  final String? editTaskId;

  const AddTaskScreen({super.key, this.editTaskId});

  @override
  ConsumerState<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends ConsumerState<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  TaskPriority _priority = TaskPriority.medium;
  TaskCategory _category = TaskCategory.general;
  TaskStatus _status = TaskStatus.pending;
  DateTime? _dueDate;
  bool _isRecurring = false;
  RecurrenceType _recurrenceType = RecurrenceType.weekly;

  Task? _editTask;

  @override
  void initState() {
    super.initState();
    if (widget.editTaskId != null) {
      final tasks = ref.read(taskProvider).tasks;
      _editTask = tasks.firstWhere((t) => t.id == widget.editTaskId);
      _titleCtrl.text = _editTask!.title;
      _descCtrl.text = _editTask!.description ?? '';
      _priority = _editTask!.priority;
      _category = _editTask!.category;
      _status = _editTask!.status;
      _dueDate = _editTask!.dueDate;
      _isRecurring = _editTask!.isRecurring;
      _recurrenceType = _editTask!.recurrenceType ?? RecurrenceType.weekly;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(taskProvider.notifier);

    if (_editTask != null) {
      notifier.updateTask(_editTask!.copyWith(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        priority: _priority,
        category: _category,
        status: _status,
        dueDate: _dueDate,
        isRecurring: _isRecurring,
        recurrenceType: _isRecurring ? _recurrenceType : null,
      ));
    } else {
      notifier.addTask(Task(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        priority: _priority,
        status: _status,
        category: _category,
        dueDate: _dueDate,
        isRecurring: _isRecurring,
        recurrenceType: _isRecurring ? _recurrenceType : null,
        createdAt: DateTime.now(),
      ));
    }

    context.pop();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.textOnPrimary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = _editTask != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                title: 'TASK DETAILS',
                child: Column(
                  children: [
                    AppTextField(
                      label: 'Task Title',
                      hint: 'Enter task title',
                      controller: _titleCtrl,
                      prefixIcon: Icons.title,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    AppTextField(
                      label: 'Description (optional)',
                      hint: 'Add more details about this task...',
                      controller: _descCtrl,
                      maxLines: 3,
                      prefixIcon: Icons.notes,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              _Section(
                title: 'CATEGORY & PRIORITY',
                child: Column(
                  children: [
                    AppDropdownField<TaskCategory>(
                      label: 'Category',
                      value: _category,
                      prefixIcon: Icons.folder_outlined,
                      items: TaskCategory.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Priority',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<TaskPriority>(
                          segments: TaskPriority.values
                              .map(
                                (p) => ButtonSegment(
                                  value: p,
                                  label: Text(p.label),
                                ),
                              )
                              .toList(),
                          selected: {_priority},
                          onSelectionChanged: (v) =>
                              setState(() => _priority = v.first),
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.primary,
                            selectedForegroundColor: AppColors.textOnPrimary,
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              _Section(
                title: 'SCHEDULING',
                child: Column(
                  children: [
                    // Due date
                    GestureDetector(
                      onTap: _pickDueDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          border: Border.all(color: AppColors.neutral200),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _dueDate != null
                                    ? DateFormat('EEEE, MMM d, yyyy').format(_dueDate!)
                                    : 'No due date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _dueDate != null
                                      ? AppColors.textPrimary
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            if (_dueDate != null)
                              GestureDetector(
                                onTap: () => setState(() => _dueDate = null),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    // Recurring
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        border: Border.all(color: AppColors.neutral200),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.repeat,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Recurring Task',
                              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                            ),
                          ),
                          Switch(
                            value: _isRecurring,
                            onChanged: (v) => setState(() => _isRecurring = v),
                            activeThumbColor: AppColors.primary,
                            activeTrackColor: AppColors.primary.withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: AppDimensions.sm),
                      AppDropdownField<RecurrenceType>(
                        label: 'Repeat',
                        value: _recurrenceType,
                        prefixIcon: Icons.schedule,
                        items: RecurrenceType.values
                            .map((r) => DropdownMenuItem(value: r, child: Text(r.label)))
                            .toList(),
                        onChanged: (v) => setState(() => _recurrenceType = v!),
                      ),
                    ],
                  ],
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: AppDimensions.md),
                _Section(
                  title: 'STATUS',
                  child: AppDropdownField<TaskStatus>(
                    label: 'Current Status',
                    value: _status,
                    prefixIcon: Icons.flag_outlined,
                    items: TaskStatus.values
                        .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v!),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.xl),
              AppButton(
                label: isEditing ? 'Save Changes' : 'Create Task',
                icon: isEditing ? Icons.save_outlined : Icons.add_task,
                onPressed: _submit,
              ),
              const SizedBox(height: AppDimensions.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          child,
        ],
      ),
    );
  }
}
