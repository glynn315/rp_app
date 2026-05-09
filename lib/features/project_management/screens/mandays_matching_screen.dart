import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';
import '../widgets/project_list_shell.dart';

class MandaysMatchingScreen extends ConsumerWidget {
  const MandaysMatchingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mandaysRunsProvider);
    final runs = async.value ?? const <MandaysMatchingRun>[];

    return ProjectListShell(
      title: 'Mandays Matching',
      emptyIcon: Icons.fact_check_outlined,
      emptyMessage:
          'No mandays-matching runs yet. They appear once payroll runs are pulled from TAPS and matched against project scopes.',
      isLoading: async.isLoading,
      error: async.hasError ? async.error : null,
      itemCount: runs.length,
      itemBuilder: (context, i) => _MandaysRunCard(
        run: runs[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MandaysMatchingDetailScreen(run: runs[i]),
          ),
        ),
      ),
      onRefresh: () async {
        ref.invalidate(mandaysRunsProvider);
        await ref.read(mandaysRunsProvider.future);
      },
      subtitle: runs.isEmpty ? null : Text('${runs.length} run(s) on file'),
    );
  }
}

class _MandaysRunCard extends StatelessWidget {
  final MandaysMatchingRun run;
  final VoidCallback onTap;

  const _MandaysRunCard({required this.run, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final qty = NumberFormat('#,##0.##');
    final date = run.dateProcessed != null
        ? DateFormat('MMM d, yyyy').format(run.dateProcessed!)
        : 'Not yet processed';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: onTap,
        child: Container(
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
                      run.documentNo.isEmpty ? 'Run #${run.runId ?? '—'}' : run.documentNo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _DocstatusPill(status: run.docstatus),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
              if (run.tapsRunDocumentNo.isNotEmpty || run.taps != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.xs),
                  child: _TapsLine(run: run),
                ),
              if (run.tapsError != null)
                const Padding(
                  padding: EdgeInsets.only(top: AppDimensions.xs),
                  child: Text(
                    'TAPS DB unavailable — payroll details not enriched.',
                    style: TextStyle(fontSize: 11, color: AppColors.warning),
                  ),
                ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Employees',
                      value: '${run.employeeCount}',
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Matched',
                      value: qty.format(run.totalMatchedQty),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Manual',
                      value: qty.format(run.totalManualQty),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.xs),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Accounted',
                      value: money.format(run.totalAccountedSalary),
                      emphasise: true,
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Unaccounted',
                      value: money.format(run.totalUnaccountedSalary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TapsLine extends StatelessWidget {
  final MandaysMatchingRun run;

  const _TapsLine({required this.run});

  @override
  Widget build(BuildContext context) {
    final tapsDoc = run.taps?['documentno']?.toString() ?? run.tapsRunDocumentNo;
    final processed = run.taps?['date_processed']?.toString() ??
        (run.tapsDateProcessed != null
            ? DateFormat('MMM d, yyyy').format(run.tapsDateProcessed!)
            : '');

    return Row(
      children: [
        const Icon(Icons.link, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            'TAPS · ${tapsDoc.isEmpty ? '—' : tapsDoc}'
            '${processed.isEmpty ? '' : ' · $processed'}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DocstatusPill extends StatelessWidget {
  final String status;

  const _DocstatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final upper = status.toUpperCase();
    final palette = switch (upper) {
      'PR' => (AppColors.success, AppColors.successLight, 'Processed'),
      'DR' => (AppColors.warning, AppColors.warningLight, 'Draft'),
      _ => (AppColors.textSecondary, AppColors.surfaceVariant, upper.isEmpty ? '—' : upper),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.$2,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        palette.$3,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
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
            fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
            color: emphasise ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

/// Drill-in view: per-employee mandays summary for a specific run.
class MandaysMatchingDetailScreen extends ConsumerWidget {
  final MandaysMatchingRun run;

  const MandaysMatchingDetailScreen({super.key, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runId = run.runId;
    if (runId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(run.documentNo.isEmpty ? 'Run' : run.documentNo)),
        body: const Center(child: Text('Run id missing — cannot load detail.')),
      );
    }

    final async = ref.watch(mandaysRunDetailProvider(runId));
    final rows = async.value ?? const <MandaysMatchingEmployeeSummary>[];
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final qty = NumberFormat('#,##0.##');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(run.documentNo.isEmpty ? 'Run #$runId' : run.documentNo),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mandaysRunDetailProvider(runId));
          await ref.read(mandaysRunDetailProvider(runId).future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.lg),
            children: [
              Text(
                'Could not load run detail.\n$e',
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ),
          data: (_) {
            if (rows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.lg),
                children: const [
                  Center(
                    child: Text(
                      'No employee summaries on this run.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppDimensions.md),
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (context, i) {
                final r = rows[i];
                return Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(color: AppColors.neutral100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.fullName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (r.employeeNo.isNotEmpty)
                            Text(
                              r.employeeNo,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              label: 'Matched',
                              value: qty.format(r.totalMatchedQty),
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              label: 'Manual',
                              value: qty.format(r.totalManualQty),
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              label: 'Total',
                              value: qty.format(r.grandTotalQty),
                              emphasise: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.xs),
                      Row(
                        children: [
                          Expanded(
                            child: _Metric(
                              label: 'Accounted',
                              value: money.format(r.totalAccountedSalary),
                              emphasise: true,
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              label: 'Unaccounted',
                              value: money.format(r.totalUnaccountedSalary),
                            ),
                          ),
                          Expanded(
                            child: _Metric(
                              label: 'TAPS Basic',
                              value: money.format(r.tapsBasicSalary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
