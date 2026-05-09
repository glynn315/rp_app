import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../daily_work_report/models/work_report_models.dart';
import '../../daily_work_report/providers/work_report_provider.dart';
import '../../daily_work_report/theme/work_report_colors.dart';
import '../models/project_management_models.dart';
import '../widgets/boq_kind_chip.dart';

/// Full-screen page for managing scope-level task templates of a BOQ line.
class BoqTasksScreen extends ConsumerStatefulWidget {
  final BoqItem? item;

  const BoqTasksScreen({super.key, required this.item});

  @override
  ConsumerState<BoqTasksScreen> createState() => _BoqTasksScreenState();
}

class _BoqTasksScreenState extends ConsumerState<BoqTasksScreen> {
  final TextEditingController _newTaskCtl = TextEditingController();
  List<String> _tasks = const [];
  bool _loading = false;
  bool _saving = false;
  String? _error;

  BoqItem? get _item => widget.item;

  String get _tagType =>
      _item?.scopeId != null ? TagType.wipScope : TagType.wipProject;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadTasks();
    });
  }

  @override
  void dispose() {
    _newTaskCtl.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    if (_item == null) return;
    if (_tagId.isEmpty) {
      setState(() => _error = 'No project or scope is linked to this BOQ.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ref
          .read(lookupProvider.notifier)
          .tasksFor(tagType: _tagType, tagId: _tagId);
      if (!mounted) return;
      setState(() {
        _tasks = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load tasks: $e';
      });
    }
  }

  Future<void> _addTask() async {
    final name = _newTaskCtl.text.trim();
    if (name.isEmpty) return;
    if (_tagId.isEmpty) {
      setState(() => _error = 'No project or scope is linked to this BOQ.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final list = await ref.read(lookupProvider.notifier).createTask(
            tagType: _tagType,
            tagId: _tagId,
            name: name,
          );
      if (!mounted) return;
      _newTaskCtl.clear();
      setState(() {
        _tasks = list;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Failed to add task: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Manage tasks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: _buildSlivers(),
      ),
    );
  }

  List<Widget> _buildSlivers() {
    final item = _item;
    if (item == null) {
      return [
        const SizedBox(height: 64),
        const Icon(Icons.checklist_rtl, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 12),
        const Text(
          'No BOQ line selected',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Open a BOQ line from the Bill of Quantities list and tap “Tasks” to manage its task templates.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
      ];
    }

    return [
      _ScopeHeader(item: item, tagLabel: _tagLabel, tagType: _tagType),
      const SizedBox(height: AppDimensions.md),
      _AddTaskRow(
        controller: _newTaskCtl,
        saving: _saving,
        onSubmit: _addTask,
      ),
      if (_error != null) ...[
        const SizedBox(height: AppDimensions.sm),
        _ErrorBanner(message: _error!),
      ],
      const SizedBox(height: AppDimensions.md),
      const _SectionLabel('EXISTING TASKS'),
      const SizedBox(height: 8),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_tasks.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'No tasks yet — add one above.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
            ),
          ),
        )
      else
        ..._tasks.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TaskRow(name: t),
            )),
      const SizedBox(height: AppDimensions.lg),
    ];
  }
}

class _ScopeHeader extends StatelessWidget {
  final BoqItem item;
  final String tagLabel;
  final String tagType;

  const _ScopeHeader({
    required this.item,
    required this.tagLabel,
    required this.tagType,
  });

  @override
  Widget build(BuildContext context) {
    final headline = item.itemLabel.isNotEmpty
        ? item.itemLabel
        : (tagLabel.isNotEmpty ? tagLabel : 'Untitled BOQ line');

    return Container(
      width: double.infinity,
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
            children: [
              BoqKindChip(kind: item.lineKind),
              const SizedBox(width: AppDimensions.xs),
              Expanded(
                child: Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Scoped to ${TagType.labelFor(tagType)}'
            '${tagLabel.isEmpty ? '' : ' · $tagLabel'}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTaskRow extends StatelessWidget {
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSubmit;

  const _AddTaskRow({
    required this.controller,
    required this.saving,
    required this.onSubmit,
  });

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ADD A TASK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: 'e.g. Concrete pour',
              counterText: '',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: saving ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: WorkReportColors.terracotta,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
            ),
            icon: saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.add, size: 18),
            label: const Text('Add task'),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final String name;

  const _TaskRow({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_box_outlined,
              size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
              message,
              style: const TextStyle(
                  color: WorkReportColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
