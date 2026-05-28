import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

/// Log a daily progress update against an open task. Mirrors the web mobile
/// `DailyUpdateScreen`:
///  - task picker (open tasks only)
///  - report date (defaults to today)
///  - note + optional progress %
///  - image attachments (≤ 2 MB each; rp_app uses image_picker so non-image
///    files aren't supported in the mobile port — flagged inline)
///  - mark-done toggle
class DailyUpdateScreen extends ConsumerStatefulWidget {
  /// Optional preselected task id from the route's `?task=` query param.
  final String? initialTaskId;
  const DailyUpdateScreen({super.key, this.initialTaskId});

  @override
  ConsumerState<DailyUpdateScreen> createState() => _DailyUpdateScreenState();
}

class _DailyUpdateScreenState extends ConsumerState<DailyUpdateScreen> {
  static const _maxAttachMb = 2;

  String? _taskId;
  DateTime _date = DateTime.now();
  final _noteCtrl = TextEditingController();
  final _progressCtrl = TextEditingController();
  bool _markDone = false;
  final List<TaskAttachment> _attachments = [];
  bool _saving = false;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _taskId = widget.initialTaskId;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  List<Task> _openTasks() {
    final all = ref.read(taskProvider).tasks;
    return all
        .where((t) =>
            t.status != TaskStatus.completed &&
            t.status != TaskStatus.cancelled)
        .toList();
  }

  Task? _selectedTask() {
    if (_taskId == null) return null;
    final tasks = ref.read(taskProvider).tasks;
    final match = tasks.where((t) => t.id == _taskId);
    return match.isEmpty ? null : match.first;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > _maxAttachMb * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${picked.name} is over $_maxAttachMb MB.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      final mime = _mimeFor(picked.name);
      final att = TaskAttachment(
        id: 'att-${DateTime.now().millisecondsSinceEpoch}',
        name: picked.name,
        mimeType: mime,
        dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
      );
      if (!mounted) return;
      setState(() => _attachments.add(att));
    } on PlatformException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick image: ${e.message}'),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not read image.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showAttachmentPicker() async {
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (result != null) await _pickImage(result);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_taskId == null || _taskId!.isEmpty) {
      _toast('Select a task to update.', error: true);
      return;
    }
    final note = _noteCtrl.text.trim();
    if (note.isEmpty) {
      _toast('Add a short note about today.', error: true);
      return;
    }
    int? pct;
    if (_progressCtrl.text.trim().isNotEmpty) {
      pct = int.tryParse(_progressCtrl.text.trim());
      if (pct == null || pct < 0 || pct > 100) {
        _toast('Progress must be 0–100.', error: true);
        return;
      }
    }

    final ok = await _confirm(
      title: _markDone ? 'Mark task as done?' : 'Log daily update?',
      message: _confirmMessage(pct),
      confirmLabel: _markDone ? 'Mark done' : 'Save update',
    );
    if (!ok) return;

    setState(() => _saving = true);
    final update = TaskDailyUpdate(
      id: 'upd-${DateTime.now().millisecondsSinceEpoch}',
      date: DateFormat('yyyy-MM-dd').format(_date),
      note: note,
      progress: pct,
      markedDone: _markDone,
      attachments: List<TaskAttachment>.from(_attachments),
      createdAt: DateTime.now(),
    );
    ref.read(taskProvider.notifier).addDailyUpdate(
          _taskId!,
          update,
          markDone: _markDone,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    _toast(_markDone ? 'Task marked done.' : 'Daily update saved.');
    // Pop back to wherever the user came from (Tasks list or task detail).
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/tasks');
    }
  }

  String _confirmMessage(int? pct) {
    final task = _selectedTask();
    final parts = <String>[];
    if (task != null) parts.add(task.title);
    parts.add(DateFormat('MMM d, y').format(_date));
    if (pct != null) parts.add('$pct%');
    if (_markDone) parts.add('marking done');
    return parts.join(' · ');
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  String _mimeFor(String name) {
    final ext = name.toLowerCase().split('.').last;
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      _ => 'image/jpeg',
    };
  }

  @override
  Widget build(BuildContext context) {
    final openTasks = _openTasks();
    final selected = _selectedTask();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('Daily update'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Task picker
            _Section(
              title: 'TASK',
              child: AppDropdownField<String>(
                label: 'Select task',
                value: _taskId != null &&
                        openTasks.any((t) => t.id == _taskId)
                    ? _taskId
                    : null,
                prefixIcon: Icons.task_alt,
                items: openTasks
                    .map((t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(
                            t.dueDate != null
                                ? '${t.title} (due ${DateFormat('MMM d').format(t.dueDate!)})'
                                : t.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _taskId = v),
              ),
            ),
            if (openTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                child: Text(
                  'No open tasks to update. Create one first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.md,
                  vertical: AppDimensions.sm,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neutral100,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Text(
                  _selectedSubline(selected),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.md),
            // Date
            _Section(
              title: 'WHEN',
              child: GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        DateFormat('EEEE, MMM d, y').format(_date),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            // Note + progress
            _Section(
              title: 'PROGRESS',
              child: Column(
                children: [
                  AppTextField(
                    label: 'What did you do today?',
                    hint: 'Progress, blockers, next steps…',
                    controller: _noteCtrl,
                    maxLines: 3,
                    prefixIcon: Icons.notes,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  AppTextField(
                    label: 'Progress % (optional)',
                    hint: '0–100',
                    controller: _progressCtrl,
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.percent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            // Attachments
            _Section(
              title: 'ATTACHMENTS (OPTIONAL)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showAttachmentPicker,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(_attachments.isEmpty
                        ? 'Add image (≤ $_maxAttachMb MB each)'
                        : 'Add another image'),
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.sm),
                    ..._attachments.map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _AttachmentRow(
                          att: a,
                          onRemove: () =>
                              setState(() => _attachments.remove(a)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.md),
            // Mark done toggle
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                border: Border.all(color: AppColors.neutral200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Mark this task as done',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: _markDone,
                    onChanged: (v) => setState(() => _markDone = v),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.xl),
            AppButton(
              label: _saving
                  ? 'Saving…'
                  : _markDone
                      ? 'Save & mark done'
                      : 'Save daily update',
              icon: Icons.save_outlined,
              onPressed: (_saving || openTasks.isEmpty) ? null : _submit,
            ),
            const SizedBox(height: AppDimensions.md),
          ],
        ),
      ),
    );
  }

  String _selectedSubline(Task t) {
    final logged = t.dailyUpdates.length;
    final parts = <String>[
      'Last updates: ${logged == 0 ? 'none yet' : '$logged logged'}',
      if (t.dueDate != null)
        'deadline ${DateFormat('MMM d').format(t.dueDate!)}',
    ];
    return parts.join(' · ');
  }
}

class _AttachmentRow extends StatelessWidget {
  final TaskAttachment att;
  final VoidCallback onRemove;
  const _AttachmentRow({required this.att, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _thumbnail(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              att.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
          TextButton(
            onPressed: onRemove,
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail() {
    try {
      final comma = att.dataUrl.indexOf(',');
      if (comma < 0) return _placeholder();
      final bytes = base64Decode(att.dataUrl.substring(comma + 1));
      return Image.memory(
        Uint8List.fromList(bytes),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _placeholder(),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() => Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        color: AppColors.neutral100,
        child: const Icon(Icons.image_outlined,
            size: 18, color: AppColors.textMuted),
      );
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
