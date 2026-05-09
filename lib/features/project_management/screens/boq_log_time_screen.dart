import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../daily_work_report/models/work_report_models.dart';
import '../../daily_work_report/providers/work_report_provider.dart';
import '../../daily_work_report/theme/work_report_colors.dart';
import '../models/project_management_models.dart';
import '../widgets/boq_kind_chip.dart';

/// Full-screen page for logging a work-block against a BOQ line.
class BoqLogTimeScreen extends ConsumerStatefulWidget {
  final BoqItem? item;

  const BoqLogTimeScreen({super.key, required this.item});

  @override
  ConsumerState<BoqLogTimeScreen> createState() => _BoqLogTimeScreenState();
}

class _BoqLogTimeScreenState extends ConsumerState<BoqLogTimeScreen> {
  final TextEditingController _timeInCtl = TextEditingController();
  final TextEditingController _timeOutCtl = TextEditingController();
  final TextEditingController _tasksCtl = TextEditingController();
  String? _error;

  List<String> _taskTemplates = const [];
  bool _loadingTasks = false;

  BoqItem? get _item => widget.item;

  String get _tagType =>
      _item?.scopeId != null ? TagType.jobOrder : TagType.project;
  String get _tagId =>
      (_item?.scopeId ?? _item?.projectId)?.toString() ?? '';
  String get _tagLabel {
    final i = _item;
    if (i == null) return '';
    return i.scopeName.isNotEmpty ? i.scopeName : i.projectName;
  }

  @override
  void initState() {
    super.initState();
    if (_item == null) return;
    // Defensive: any failure inside suggestTimes (e.g. malformed block in
    // workReportProvider state) must not break initState — fall back to
    // canonical defaults so the form always renders.
    String inDefault = '08:00';
    String outDefault = '11:00';
    try {
      final suggest = ref.read(workReportProvider.notifier).suggestTimes();
      if (suggest.timeIn.isNotEmpty) inDefault = suggest.timeIn;
      if (suggest.timeOut.isNotEmpty) outDefault = suggest.timeOut;
    } catch (_) {
      // Keep canonical defaults.
    }
    _timeInCtl.text = inDefault;
    _timeOutCtl.text = outDefault;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTasks();
    });
  }

  @override
  void dispose() {
    _timeInCtl.dispose();
    _timeOutCtl.dispose();
    _tasksCtl.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    if (_tagId.isEmpty) return;
    setState(() => _loadingTasks = true);
    try {
      final list = await ref
          .read(lookupProvider.notifier)
          .tasksFor(tagType: _tagType, tagId: _tagId);
      if (!mounted) return;
      setState(() {
        _taskTemplates = list;
        _loadingTasks = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _taskTemplates = const [];
        _loadingTasks = false;
      });
    }
  }

  void _appendTaskLine(String task) {
    final current = _tasksCtl.text;
    final line = '• $task';
    final lines = current.split('\n');
    final existingIdx = lines.indexWhere(
      (l) => l.trim().toLowerCase() == line.toLowerCase(),
    );
    if (existingIdx >= 0) {
      lines.removeAt(existingIdx);
      _tasksCtl.text = lines.where((l) => l.isNotEmpty).join('\n');
    } else {
      final next = current.trim().isEmpty ? line : '$current\n$line';
      _tasksCtl.text = next;
    }
    _tasksCtl.selection = TextSelection.fromPosition(
      TextPosition(offset: _tasksCtl.text.length),
    );
    setState(() {});
  }

  Future<void> _showAddTaskDialog() async {
    if (_tagId.isEmpty) return;
    final ctl = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add task to $_tagLabel'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          maxLength: 120,
          decoration: const InputDecoration(
            hintText: 'e.g. Concrete pour',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (saved == null || saved.isEmpty) return;

    setState(() => _loadingTasks = true);
    try {
      final list = await ref.read(lookupProvider.notifier).createTask(
            tagType: _tagType,
            tagId: _tagId,
            name: saved,
          );
      if (!mounted) return;
      setState(() {
        _taskTemplates = list;
        _loadingTasks = false;
      });
      _appendTaskLine(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTasks = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add task: $e')),
      );
    }
  }

  Future<void> _pickTime(TextEditingController ctl) async {
    final parts = ctl.text.split(':');
    final initial = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 8,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : const TimeOfDay(hour: 8, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null && mounted) {
      ctl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {});
    }
  }

  void _trySubmit() {
    if (_timeInCtl.text.isEmpty || _timeOutCtl.text.isEmpty) {
      setState(() => _error = 'Pick both time in and time out.');
      return;
    }
    if (_tasksCtl.text.trim().isEmpty) {
      setState(() => _error = 'Tasks description is required.');
      return;
    }
    final block = WorkBlock(
      localId: UniqueId.next(),
      tagType: _tagType,
      tagId: _tagId,
      tagLabel: _tagLabel,
      timeIn: _timeInCtl.text,
      timeOut: _timeOutCtl.text,
      tasks: _tasksCtl.text.trim(),
    );
    final err = ref.read(workReportProvider.notifier).validateBlock(block);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    ref.read(workReportProvider.notifier).addBlock(block);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Block added — $_tagLabel  ${_timeInCtl.text}–${_timeOutCtl.text}'),
        backgroundColor: WorkReportColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow,
      appBar: AppBar(
        title: const Text('Log work time'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      // ABSOLUTE-MINIMUM TEST: if you see RED below the appbar, the body is
      // rendering and our previous Column was the bug. If you still see only
      // YELLOW, the body widget itself isn't being inserted — that's a hot-
      // reload staleness issue and requires a real `flutter run` restart.
      body: Container(
        color: Colors.red,
        alignment: Alignment.center,
        child: const Text(
          'BUILD v4 — body is rendering',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, BoqItem item) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    // SingleChildScrollView + Column rather than ListView. ListView relies on
    // a viewport cache that can collapse to zero on a repush, leaving the
    // children un-painted while the layout itself looks fine — see the
    // first-visit-OK / second-visit-blank reproduction. SingleChildScrollView
    // paints its child eagerly so this code path is bulletproof.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.neutral100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BoqKindChip(kind: item.lineKind),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.itemLabel.isNotEmpty
                          ? item.itemLabel
                          : (item.projectName.isNotEmpty
                              ? item.projectName
                              : 'Untitled BOQ line'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (item.projectName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.projectName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (item.scopeName.isNotEmpty || item.stageName.isNotEmpty)
                Text(
                  [item.scopeName, item.stageName]
                      .where((s) => s.isNotEmpty)
                      .join(' · '),
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              const SizedBox(height: 6),
              Text(
                money.format(item.amount),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppDimensions.md),
        Row(
          children: [
            Expanded(
              child: _TimeField(
                label: 'Time in',
                controller: _timeInCtl,
                onTap: () => _pickTime(_timeInCtl),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeField(
                label: 'Time out',
                controller: _timeOutCtl,
                onTap: () => _pickTime(_timeOutCtl),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.md),
        if (_loadingTasks)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else ...[
          Text(
            _taskTemplates.isEmpty
                ? 'NO TASKS YET — TAP + TO ADD'
                : 'COMMON TASKS — TAP TO ADD',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: WorkReportColors.stone,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._taskTemplates.map(
                (t) => _TaskChip(label: t, onTap: () => _appendTaskLine(t)),
              ),
              _AddTaskChip(onTap: _showAddTaskDialog),
            ],
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _tasksCtl,
          minLines: 4,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Tasks',
            hintText: 'Tap chips above or type your own…',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: WorkReportColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    size: 14, color: WorkReportColors.danger),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: WorkReportColors.danger, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.md),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: WorkReportColors.terracotta,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _trySubmit,
                child: const Text(
                  'Add block',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.lg),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onTap;

  const _TimeField({
    required this.label,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // GestureDetector + AbsorbPointer so the TextField never sees the tap;
    // tap always opens the time picker. (TextField(readOnly:true, onTap:…) is
    // unreliable across Flutter versions — first tap focuses, only the second
    // fires onTap.)
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.access_time, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }
}

class _TaskChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TaskChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: WorkReportColors.terracotta.withValues(alpha: 0.08),
          border: Border.all(
            color: WorkReportColors.terracotta.withValues(alpha: 0.4),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 14, color: WorkReportColors.terracotta),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: WorkReportColors.terracotta,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTaskChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTaskChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: WorkReportColors.midnight.withValues(alpha: 0.5),
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_circle_outline,
                size: 14, color: WorkReportColors.midnight),
            SizedBox(width: 4),
            Text(
              'New task',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: WorkReportColors.midnight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissingItemMessage extends StatelessWidget {
  const _MissingItemMessage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.access_time, size: 56, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No BOQ line selected',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Open a BOQ line from the Bill of Quantities list and tap “Log time” to record a work-block against it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
