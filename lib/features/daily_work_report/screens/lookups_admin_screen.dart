import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/work_report_models.dart';
import '../providers/work_report_provider.dart';
import '../theme/work_report_colors.dart';

/// Admin screen for managing lookup data (Projects / Job Orders /
/// Departments / Admin Projects) and the per-scope task templates.
///
/// No role gating — all four tabs are visible to all users while we test the
/// UX. To add gating later, wrap the route or hide the entry button.
class LookupsAdminScreen extends ConsumerStatefulWidget {
  const LookupsAdminScreen({super.key});

  @override
  ConsumerState<LookupsAdminScreen> createState() => _LookupsAdminScreenState();
}

class _LookupsAdminScreenState extends ConsumerState<LookupsAdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    TagType.project,
    TagType.jobOrder,
    TagType.department,
    TagType.adminProject,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final t in _tabs) {
        ref.read(lookupsAdminProvider.notifier).load(t);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WorkReportColors.cream,
      appBar: AppBar(
        backgroundColor: WorkReportColors.midnight,
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Projects & Tasks',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: WorkReportColors.stone,
          indicatorColor: WorkReportColors.terracotta,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: _tabs.map((t) => Tab(text: TagType.labelFor(t))).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _LookupTabView(tagType: t)).toList(),
      ),
    );
  }
}

class _LookupTabView extends ConsumerWidget {
  final String tagType;

  const _LookupTabView({required this.tagType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lookupsAdminProvider);
    final items = state.items[tagType] ?? const <LookupAdminItem>[];
    final loading = state.loading[tagType] ?? false;
    final error = state.error[tagType];

    return Stack(
      children: [
        if (loading && items.isEmpty)
          const Center(child: CircularProgressIndicator())
        else
          RefreshIndicator(
            onRefresh: () => ref.read(lookupsAdminProvider.notifier).load(tagType),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: items.length + (items.isEmpty ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Text(
                        error ??
                            'No ${TagType.labelFor(tagType).toLowerCase()}s yet — tap + to add one.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: WorkReportColors.stone),
                      ),
                    ),
                  );
                }
                return _LookupCard(tagType: tagType, item: items[i]);
              },
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add-$tagType',
            backgroundColor: WorkReportColors.terracotta,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: Text('New ${TagType.labelFor(tagType)}'),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final codeCtl = TextEditingController();
    final nameCtl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New ${TagType.labelFor(tagType)}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeCtl,
                autofocus: true,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  hintText: 'e.g. BLK-A-VAULT',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameCtl,
                maxLength: 191,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Block A Vault Construction',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final ok = await ref
          .read(lookupsAdminProvider.notifier)
          .create(tagType, codeCtl.text.trim(), nameCtl.text.trim());
      if (!ok && context.mounted) {
        final msg = ref.read(lookupsAdminProvider).error[tagType] ?? 'Failed to create.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
    codeCtl.dispose();
    nameCtl.dispose();
  }
}

class _LookupCard extends ConsumerStatefulWidget {
  final String tagType;
  final LookupAdminItem item;

  const _LookupCard({required this.tagType, required this.item});

  @override
  ConsumerState<_LookupCard> createState() => _LookupCardState();
}

class _LookupCardState extends ConsumerState<_LookupCard> {
  bool _expanded = false;
  bool _loadingTasks = false;

  Future<void> _toggleExpanded() async {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      final state = ref.read(lookupsAdminProvider);
      final key = LookupsAdminState.taskKey(widget.tagType, widget.item.id);
      if (state.tasks[key] == null) {
        setState(() => _loadingTasks = true);
        await ref
            .read(lookupsAdminProvider.notifier)
            .loadTasks(widget.tagType, widget.item.id);
        if (mounted) setState(() => _loadingTasks = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final state = ref.watch(lookupsAdminProvider);
    final tasks = state.tasks[
            LookupsAdminState.taskKey(widget.tagType, item.id)] ??
        const <String>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.isActive
              ? WorkReportColors.mist
              : WorkReportColors.stone.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _toggleExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isActive
                                    ? WorkReportColors.steel
                                    : WorkReportColors.stone,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.code,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!item.isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: WorkReportColors.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'INACTIVE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: WorkReportColors.danger,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: item.isActive
                                ? WorkReportColors.charcoal
                                : WorkReportColors.stone,
                            decoration: item.isActive
                                ? TextDecoration.none
                                : TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: item.isActive,
                    activeThumbColor: WorkReportColors.terracotta,
                    onChanged: (v) {
                      ref.read(lookupsAdminProvider.notifier).update(
                            widget.tagType,
                            item.id,
                            isActive: v,
                          );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: WorkReportColors.midnight,
                    onPressed: () => _showEditDialog(context),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: WorkReportColors.stone,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              decoration: const BoxDecoration(
                color: WorkReportColors.cream,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TASKS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: WorkReportColors.stone,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_loadingTasks)
                    const LinearProgressIndicator(minHeight: 2)
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ...tasks.map((t) => _TaskAdminChip(
                              label: t,
                              onDelete: () => _confirmRemoveTask(t),
                            )),
                        _AddTaskAdminChip(onTap: _showAddTaskDialog),
                      ],
                    ),
                  if (!_loadingTasks && tasks.isEmpty) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'No tasks yet — tap + to add one.',
                      style: TextStyle(
                        fontSize: 11,
                        color: WorkReportColors.stone,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveTask(String name) async {
    final ok = await ref.read(lookupsAdminProvider.notifier).removeTask(
          widget.tagType,
          widget.item.id,
          name,
        );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove task.')),
      );
    }
  }

  Future<void> _showAddTaskDialog() async {
    final ctl = TextEditingController();
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add task to ${widget.item.name}'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
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
    final ok = await ref
        .read(lookupsAdminProvider.notifier)
        .addTask(widget.tagType, widget.item.id, saved);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add task.')),
      );
    }
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final codeCtl = TextEditingController(text: widget.item.code);
    final nameCtl = TextEditingController(text: widget.item.name);
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit ${TagType.labelFor(widget.tagType)}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: codeCtl,
                maxLength: 64,
                decoration: const InputDecoration(
                  labelText: 'Code',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nameCtl,
                maxLength: 191,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ref.read(lookupsAdminProvider.notifier).update(
            widget.tagType,
            widget.item.id,
            code: codeCtl.text.trim(),
            name: nameCtl.text.trim(),
          );
    }
    codeCtl.dispose();
    nameCtl.dispose();
  }
}

class _TaskAdminChip extends StatelessWidget {
  final String label;
  final VoidCallback onDelete;

  const _TaskAdminChip({required this.label, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: WorkReportColors.terracotta.withValues(alpha: 0.08),
        border: Border.all(color: WorkReportColors.terracotta.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: WorkReportColors.terracotta,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 14, color: WorkReportColors.terracotta),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTaskAdminChip extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTaskAdminChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: WorkReportColors.midnight.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_circle_outline, size: 14, color: WorkReportColors.midnight),
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
