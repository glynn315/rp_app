import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';
import '../widgets/project_filter_bar.dart';
import '../widgets/project_list_shell.dart';

class WorkInProgressScreen extends ConsumerWidget {
  const WorkInProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wipListProvider);
    final items = async.value ?? const <WipProject>[];

    return ProjectListShell(
      title: 'Work in Progress',
      emptyIcon: Icons.engineering,
      emptyMessage:
          'No projects matching the current filters. Adjust filters or pull to refresh.',
      isLoading: async.isLoading,
      error: async.hasError ? async.error : null,
      itemCount: items.length,
      itemBuilder: (context, i) => _WipProjectCard(project: items[i]),
      onRefresh: () async {
        ref.invalidate(wipListProvider);
        await ref.read(wipListProvider.future);
      },
      subtitle: items.isEmpty
          ? null
          : Text('${items.length} project(s) in progress'),
      header: ProjectFilterBar(
        filterProvider: wipFilterProvider,
        searchHint: 'Search project / IMS…',
        statusOptions: ProjectFilterBar.wipStatusOptions,
        showDateRange: true,
      ),
    );
  }
}

class _WipProjectCard extends StatelessWidget {
  final WipProject project;

  const _WipProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final progress =
        project.weightedProgressPercent.clamp(0, 100).toDouble() / 100.0;

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
              Expanded(
                child: Text(
                  project.projectName.isEmpty ? '—' : project.projectName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusPill(status: project.projectStatus),
            ],
          ),
          if (project.projectDocumentNo.isNotEmpty || project.imsNo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (project.projectDocumentNo.isNotEmpty) project.projectDocumentNo,
                  if (project.imsNo.isNotEmpty) 'IMS ${project.imsNo}',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: AppDimensions.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${project.weightedProgressPercent.toStringAsFixed(1)}% accomplished',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${project.scopeCount} scope(s)',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'BOM Budget',
                  value: money.format(project.totalBomAmount),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'LMC Budget',
                  value: money.format(project.totalLmcAmount),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Total',
                  value: money.format(project.totalAmount),
                  emphasise: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final upper = status.toUpperCase();
    final palette = switch (upper) {
      'COMMENCED' => (AppColors.success, AppColors.successLight),
      'BUDGETING' => (AppColors.warning, AppColors.warningLight),
      'FORCLOSURE' => (AppColors.info, AppColors.infoLight),
      'CLOSED' => (AppColors.textMuted, AppColors.surfaceVariant),
      _ => (AppColors.textSecondary, AppColors.surfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.$2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        upper.isEmpty ? '—' : upper,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: palette.$1,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;

  const _Metric({
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
            fontSize: emphasise ? 13 : 12,
            fontWeight: emphasise ? FontWeight.w600 : FontWeight.w500,
            color: emphasise ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
