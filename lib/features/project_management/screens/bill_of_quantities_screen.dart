import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../daily_work_report/theme/work_report_colors.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';
import '../widgets/boq_kind_chip.dart';
import '../widgets/project_filter_bar.dart';
import '../widgets/project_list_shell.dart';

class BillOfQuantitiesScreen extends ConsumerWidget {
  const BillOfQuantitiesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(boqListProvider);
    final items = async.value ?? const <BoqItem>[];

    return ProjectListShell(
      title: 'Bill of Quantities',
      emptyIcon: Icons.receipt_long,
      emptyMessage:
          'No BoQ lines found. Make sure projects with BOM/LMC budgets exist on the WIP replica.',
      isLoading: async.isLoading,
      error: async.hasError ? async.error : null,
      itemCount: items.length,
      itemBuilder: (context, i) => _BoqItemCard(item: items[i]),
      onRefresh: () async {
        ref.invalidate(boqListProvider);
        await ref.read(boqListProvider.future);
      },
      subtitle: items.isEmpty
          ? null
          : Text('${items.length} line item(s) · latest budget per stage'),
      header: ProjectFilterBar(
        filterProvider: boqFilterProvider,
        searchHint: 'Search project / scope…',
        kindOptions: ProjectFilterBar.boqKindOptions,
        statusOptions: ProjectFilterBar.boqStatusOptions,
        showDateRange: false,
      ),
    );
  }
}

class _BoqItemCard extends StatelessWidget {
  final BoqItem item;

  const _BoqItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final qty = NumberFormat('#,##0.##');

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
          Row(
            children: [
              BoqKindChip(kind: item.lineKind),
              const SizedBox(width: AppDimensions.xs),
              Expanded(
                child: Text(
                  item.itemLabel.isEmpty ? '—' : item.itemLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (item.isLocked)
                const Padding(
                  padding: EdgeInsets.only(left: AppDimensions.xs),
                  child: Icon(Icons.lock, size: 14, color: AppColors.textMuted),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          Text(
            item.projectName.isEmpty ? '—' : item.projectName,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.scopeName.isNotEmpty || item.stageName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [item.scopeName, item.stageName]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(child: _MetricCol(label: 'Qty', value: qty.format(item.qty))),
              Expanded(child: _MetricCol(label: 'Rate', value: money.format(item.rate))),
              Expanded(
                child: _MetricCol(
                  label: 'Amount',
                  value: money.format(item.amount),
                  emphasise: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.xs),
          const Divider(height: 1),
          const SizedBox(height: AppDimensions.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () =>
                    context.push('/projects/boq/tasks', extra: item),
                icon: const Icon(Icons.checklist_rtl, size: 16),
                label: const Text('Tasks'),
                style: TextButton.styleFrom(
                  foregroundColor: WorkReportColors.midnight,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () =>
                    context.push('/projects/boq/photos', extra: item),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Photos'),
                style: TextButton.styleFrom(
                  foregroundColor: WorkReportColors.midnight,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () =>
                    context.push('/projects/boq/entries', extra: item),
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('Entries'),
                style: TextButton.styleFrom(
                  foregroundColor: WorkReportColors.midnight,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () =>
                    context.push('/projects/boq/log-time', extra: item),
                icon: const Icon(Icons.access_time, size: 16),
                label: const Text('Log time'),
                style: TextButton.styleFrom(
                  foregroundColor: WorkReportColors.terracotta,
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCol extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;

  const _MetricCol({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasise ? 14 : 13,
            fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
            color: emphasise ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
