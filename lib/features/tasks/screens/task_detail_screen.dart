import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

/// Task detail view: header card + grouped daily updates timeline.
/// Mirrors the web mobile `TaskDetailScreen` — open tasks expose a
/// "+ Update" affordance that pushes the daily update screen.
class TaskDetailScreen extends ConsumerWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(taskProvider).tasks;
    final task = tasks.where((t) => t.id == taskId).toList();

    if (task.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Task'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppDimensions.lg),
            child: Text(
              'Task not found. It may have been removed.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return _Body(task: task.first);
  }
}

class _Body extends StatelessWidget {
  final Task task;
  const _Body({required this.task});

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.completed;
    final grouped = _groupByDate(task.dailyUpdates);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Task'),
        actions: [
          if (!done)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sm,
                vertical: 10,
              ),
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push('/tasks/daily?task=${task.id}'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.textOnPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(AppDimensions.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: AppColors.neutral100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: done
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                          decoration:
                              done ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    _Chip(label: task.priority.label, color: _priorityColor()),
                  ],
                ),
                if (task.description != null &&
                    task.description!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.sm),
                  Text(
                    task.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip(
                      label: task.status.label,
                      color: _statusColor(task.status),
                    ),
                    if (task.dueDate != null)
                      _Chip(
                        label:
                            'Deadline ${DateFormat('MMM d, y').format(task.dueDate!)}',
                        color: AppColors.steel,
                      ),
                    if (task.isRecurring && task.recurrenceType != null)
                      _Chip(
                        label: '↻ ${task.recurrenceType!.label}',
                        color: AppColors.warning,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          // Updates timeline
          const Text(
            'DAILY UPDATES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          if (grouped.isEmpty)
            _EmptyUpdates(taskId: task.id, allowAdd: !done)
          else
            ...grouped.map((entry) {
              final date = entry.$1;
              final updates = entry.$2;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateHeader(date),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...updates.map(
                      (u) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _UpdateRow(update: u),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// Group updates by their `date` key, most recent date first. Within a day
  /// the original insertion order is preserved.
  static List<(String, List<TaskDailyUpdate>)> _groupByDate(
    List<TaskDailyUpdate> updates,
  ) {
    final byDate = <String, List<TaskDailyUpdate>>{};
    for (final u in updates) {
      byDate.putIfAbsent(u.date, () => []).add(u);
    }
    final keys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final k in keys) (k, byDate[k]!)];
  }

  static String _formatDateHeader(String yyyymmdd) {
    final d = DateTime.tryParse(yyyymmdd);
    if (d == null) return yyyymmdd;
    return DateFormat('EEEE, MMM d, y').format(d);
  }

  Color _priorityColor() => switch (task.priority) {
        TaskPriority.urgent => AppColors.error,
        TaskPriority.high => AppColors.warning,
        TaskPriority.medium => AppColors.info,
        TaskPriority.low => AppColors.textMuted,
      };

  Color _statusColor(TaskStatus s) => switch (s) {
        TaskStatus.pending => AppColors.statusPending,
        TaskStatus.inProgress => AppColors.statusInProgress,
        TaskStatus.completed => AppColors.statusApproved,
        TaskStatus.cancelled => AppColors.statusRejected,
      };
}

class _EmptyUpdates extends StatelessWidget {
  final String taskId;
  final bool allowAdd;
  const _EmptyUpdates({required this.taskId, required this.allowAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: AppColors.neutral200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'No updates yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          if (allowAdd) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => context.push('/tasks/daily?task=$taskId'),
              child: const Text("Log today's progress"),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpdateRow extends StatelessWidget {
  final TaskDailyUpdate update;
  const _UpdateRow({required this.update});

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
            update.note,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (update.progress != null)
                _Chip(
                  label: '${update.progress}%',
                  color: AppColors.info,
                ),
              if (update.markedDone)
                _Chip(
                  label: '✓ Marked done',
                  color: AppColors.success,
                ),
              Text(
                DateFormat('h:mm a').format(update.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          if (update.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: update.attachments
                  .map((a) => _AttachmentChip(att: a))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  final TaskAttachment att;
  const _AttachmentChip({required this.att});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (att.isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _DataUrlImage(dataUrl: att.dataUrl, size: 36),
            )
          else
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'FILE',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              att.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Renders an in-memory data URL (`data:image/...;base64,...`) as an Image.
/// Used so attachments captured during the session can be previewed without
/// touching the filesystem.
class _DataUrlImage extends StatelessWidget {
  final String dataUrl;
  final double size;
  const _DataUrlImage({required this.dataUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    // Best-effort base64 decode. Malformed data URLs fall back to a neutral
    // placeholder so a single bad attachment doesn't poison the screen.
    try {
      final comma = dataUrl.indexOf(',');
      if (comma < 0 || !dataUrl.contains(';base64')) {
        return _placeholder();
      }
      final b64 = dataUrl.substring(comma + 1);
      return Image.memory(
        base64Decode(_padBase64(b64)),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        color: AppColors.neutral100,
        child: const Icon(Icons.image_not_supported_outlined,
            size: 18, color: AppColors.textMuted),
      );
}

String _padBase64(String s) {
  final mod = s.length % 4;
  if (mod == 0) return s;
  return s + ('=' * (4 - mod));
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
