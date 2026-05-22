import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../daily_work_report/theme/work_report_colors.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';
import '../widgets/boq_project_group.dart';
import '../widgets/project_filter_bar.dart';
import '../widgets/project_list_shell.dart';

class BillOfQuantitiesScreen extends ConsumerStatefulWidget {
  const BillOfQuantitiesScreen({super.key});

  @override
  ConsumerState<BillOfQuantitiesScreen> createState() =>
      _BillOfQuantitiesScreenState();
}

class _BillOfQuantitiesScreenState
    extends ConsumerState<BillOfQuantitiesScreen> {
  /// Accordion: at most one project expanded at a time. `null` when collapsed.
  int? _expandedProjectId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(boqListProvider);
    final items = async.value ?? const <BoqItem>[];
    final groups = groupBoqByProject(items);

    return ProjectListShell(
      title: 'Bill of Quantities',
      emptyIcon: Icons.receipt_long,
      emptyMessage:
          'No projects found. Make sure projects with BOM/LMC budgets exist on the WIP replica.',
      isLoading: async.isLoading,
      error: async.hasError ? async.error : null,
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        final isExpanded = _expandedProjectId == g.projectId;
        return _BoqProjectCard(
          group: g,
          isExpanded: isExpanded,
          onHeaderTap: () => setState(() {
            _expandedProjectId = isExpanded ? null : g.projectId;
          }),
        );
      },
      onRefresh: () async {
        ref.invalidate(boqListProvider);
        await ref.read(boqListProvider.future);
      },
      subtitle: groups.isEmpty
          ? null
          : Text('${groups.length} project(s) · tap to expand scopes'),
      header: ProjectFilterBar(
        filterProvider: boqFilterProvider,
        searchHint: 'Search project / scope…',
        statusOptions: ProjectFilterBar.boqStatusOptions,
        showDateRange: false,
      ),
    );
  }
}

class _BoqProjectCard extends StatelessWidget {
  final BoqProjectGroup group;
  final bool isExpanded;
  final VoidCallback onHeaderTap;

  const _BoqProjectCard({
    required this.group,
    required this.isExpanded,
    required this.onHeaderTap,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.projectName.isEmpty ? '—' : group.projectName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${group.scopes.length} scope${group.scopes.length == 1 ? '' : 's'}'
                          '${group.projectDocumentNo.isEmpty ? '' : ' · ${group.projectDocumentNo}'}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money.format(group.totalAmount),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.xs),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 22,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            for (final s in group.scopes) _ScopeRow(item: s, money: money),
        ],
      ),
    );
  }
}

class _ScopeRow extends StatelessWidget {
  final BoqItem item;
  final NumberFormat money;

  const _ScopeRow({required this.item, required this.money});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.neutral100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.scopeName.isEmpty ? '—' : item.scopeName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                money.format(item.amount),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              _ActionButton(
                icon: Icons.checklist_rtl,
                label: 'Tasks',
                onPressed: () =>
                    context.push('/projects/boq/tasks', extra: item),
              ),
              _ActionButton(
                icon: Icons.image_outlined,
                label: 'Photos',
                onPressed: () =>
                    context.push('/projects/boq/photos', extra: item),
              ),
              _ActionButton(
                icon: Icons.list_alt,
                label: 'Entries',
                onPressed: () =>
                    context.push('/projects/boq/entries', extra: item),
              ),
              _ActionButton(
                icon: Icons.access_time,
                label: 'Log time',
                color: WorkReportColors.terracotta,
                onPressed: () =>
                    context.push('/projects/boq/log-time', extra: item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color ?? WorkReportColors.midnight,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
