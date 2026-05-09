import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';
import '../widgets/project_filter_bar.dart';
import '../widgets/project_list_shell.dart';

class LmcPayoutScreen extends ConsumerWidget {
  const LmcPayoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lmcPayoutListProvider);
    final payouts = async.value ?? const <LmcPayout>[];

    return ProjectListShell(
      title: 'LMC Payout',
      emptyIcon: Icons.payments_outlined,
      emptyMessage:
          'No LMC payouts match the current filters. Adjust filters or pull to refresh.',
      isLoading: async.isLoading,
      error: async.hasError ? async.error : null,
      itemCount: payouts.length,
      itemBuilder: (context, i) => _PayoutCard(
        payout: payouts[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LmcPayoutDetailScreen(payout: payouts[i]),
          ),
        ),
      ),
      onRefresh: () async {
        ref.invalidate(lmcPayoutListProvider);
        await ref.read(lmcPayoutListProvider.future);
      },
      subtitle: payouts.isEmpty
          ? null
          : Text('${payouts.length} payout(s) · latest per scope'),
      header: ProjectFilterBar(
        filterProvider: lmcFilterProvider,
        searchHint: 'Search payout / payee…',
        statusOptions: ProjectFilterBar.lmcDocstatusOptions,
        showDateRange: true,
      ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  final LmcPayout payout;
  final VoidCallback onTap;

  const _PayoutCard({required this.payout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final coverage = _coverageLabel();

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
                      payout.documentNo.isEmpty
                          ? 'Payout #${payout.payoutId ?? '—'}'
                          : payout.documentNo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (payout.isClosed)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.lock,
                          size: 14, color: AppColors.textMuted),
                    ),
                  _DocstatusPill(status: payout.docstatus),
                ],
              ),
              if (payout.payeeName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    payout.payeeName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              if (payout.projectName.isNotEmpty || payout.scopeName.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    [payout.projectName, payout.scopeName]
                        .where((s) => s.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              if (coverage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    coverage,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'Gross',
                      value: money.format(payout.amtTotalPayout),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Tax',
                      value: money.format(payout.amtTotalPayoutTax),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'WTax',
                      value: money.format(payout.amtTotalPayoutWtax),
                    ),
                  ),
                  Expanded(
                    child: _Metric(
                      label: 'Net',
                      value: money.format(payout.amtTotalPayoutNet),
                      emphasise: true,
                    ),
                  ),
                ],
              ),
              if (payout.workaccompPercentage > 0) ...[
                const SizedBox(height: AppDimensions.xs),
                Row(
                  children: [
                    const Icon(Icons.trending_up,
                        size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${payout.workaccompPercentage.toStringAsFixed(1)}% accomplishment at payout',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _coverageLabel() {
    final fmt = DateFormat('MMM d, yyyy');
    if (payout.dateCoverageFrom != null && payout.dateCoverageTo != null) {
      return 'Coverage ${fmt.format(payout.dateCoverageFrom!)} – ${fmt.format(payout.dateCoverageTo!)}';
    }
    if (payout.dateTrans != null) {
      return 'Trans ${fmt.format(payout.dateTrans!)}';
    }
    return '';
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
      'VO' => (AppColors.error, AppColors.errorLight, 'Voided'),
      _ => (
          AppColors.textSecondary,
          AppColors.surfaceVariant,
          upper.isEmpty ? '—' : upper
        ),
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

/// Drill-in: per-stage payout lines for one header.
class LmcPayoutDetailScreen extends ConsumerWidget {
  final LmcPayout payout;

  const LmcPayoutDetailScreen({super.key, required this.payout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = payout.payoutId;
    if (id == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payout')),
        body: const Center(child: Text('Payout id missing — cannot load detail.')),
      );
    }

    final async = ref.watch(lmcPayoutDetailProvider(id));
    final lines = async.value ?? const <LmcPayoutLine>[];
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final qty = NumberFormat('#,##0.##');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          payout.documentNo.isEmpty ? 'Payout #$id' : payout.documentNo,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(lmcPayoutDetailProvider(id));
          await ref.read(lmcPayoutDetailProvider(id).future);
        },
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.lg),
            children: [
              Text(
                'Could not load payout lines.\n$e',
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ),
          data: (_) {
            if (lines.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppDimensions.lg),
                children: [
                  _HeaderSummary(payout: payout, money: money),
                  const SizedBox(height: AppDimensions.lg),
                  const Center(
                    child: Text(
                      'No payout lines on this header.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppDimensions.md),
              itemCount: lines.length + 1,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppDimensions.sm),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _HeaderSummary(payout: payout, money: money);
                }
                final line = lines[i - 1];
                return _LineCard(line: line, money: money, qty: qty);
              },
            );
          },
        ),
      ),
    );
  }
}

class _HeaderSummary extends StatelessWidget {
  final LmcPayout payout;
  final NumberFormat money;

  const _HeaderSummary({required this.payout, required this.money});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            payout.payeeName.isEmpty ? '—' : payout.payeeName,
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (payout.projectName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [payout.projectName, payout.scopeName]
                    .where((s) => s.isNotEmpty)
                    .join(' · '),
                style: TextStyle(
                  color: AppColors.textOnPrimary.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: _HeaderMetric(
                  label: 'Gross',
                  value: money.format(payout.amtTotalPayout),
                ),
              ),
              Expanded(
                child: _HeaderMetric(
                  label: 'Net',
                  value: money.format(payout.amtTotalPayoutNet),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeaderMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textOnPrimary.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _LineCard extends StatelessWidget {
  final LmcPayoutLine line;
  final NumberFormat money;
  final NumberFormat qty;

  const _LineCard({
    required this.line,
    required this.money,
    required this.qty,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (line.lineNo != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(
                    '#${line.lineNo}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              if (line.lineNo != null) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  line.description.isEmpty
                      ? (line.stageName.isEmpty ? '—' : line.stageName)
                      : line.description,
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
          if (line.stageName.isNotEmpty && line.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                line.stageName,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Qty',
                  value:
                      '${qty.format(line.qty)}${line.unit.isEmpty ? '' : ' ${line.unit}'}',
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Cost',
                  value: money.format(line.cost),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Amount',
                  value: money.format(line.amt),
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
                  label: 'Tax',
                  value: money.format(line.amtTax),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'WTax',
                  value: money.format(line.amtWtax),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Net',
                  value: money.format(line.amtNet),
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
