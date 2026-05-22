import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';
import '../widgets/project_list_shell.dart';
import 'mandays_employee_detail_screen.dart';

/// "Pending Matching" entry — one row per (employee, schedule date) with the
/// derived aggregate status. Mirrors the Mandays Matching list in the desktop
/// client. Tapping a row opens the employee detail screen for matching.
class MandaysPendingScreen extends ConsumerWidget {
  const MandaysPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mandaysPendingProvider);
    final rows = async.value ?? const <MandaysPendingRow>[];
    final filter = ref.watch(mandaysPendingFilterProvider);

    return ProjectListShell(
      title: 'Mandays Matching',
      emptyIcon: Icons.fact_check_outlined,
      emptyMessage:
          'No TA logs in this date range. Adjust the filter or trigger a TAPS sync.',
      isLoading: async.isLoading,
      error: async.hasError ? async.error : null,
      itemCount: rows.length,
      header: _FilterBar(filter: filter, ref: ref),
      subtitle: Text(
        '${rows.length} row(s) · ${DateFormat('MMM d').format(filter.dateFrom)} → '
        '${DateFormat('MMM d, yyyy').format(filter.dateTo)}',
      ),
      onRefresh: () async {
        ref.invalidate(mandaysPendingProvider);
        await ref.read(mandaysPendingProvider.future);
      },
      itemBuilder: (context, i) => _PendingRowCard(
        row: rows[i],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MandaysEmployeeDetailScreen(row: rows[i]),
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatefulWidget {
  final MandaysPendingFilter filter;
  final WidgetRef ref;
  const _FilterBar({required this.filter, required this.ref});

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(text: widget.filter.search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: widget.filter.dateFrom,
        end: widget.filter.dateTo,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      widget.ref
          .read(mandaysPendingFilterProvider.notifier)
          .setRange(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${DateFormat('MMM d').format(widget.filter.dateFrom)} → '
        '${DateFormat('MMM d, yyyy').format(widget.filter.dateTo)}';
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.md, AppDimensions.sm, AppDimensions.md, AppDimensions.sm),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range, size: 16),
                  label: Text(dateLabel,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => _pickRange(context),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              DropdownButton<String?>(
                value: widget.filter.status,
                hint: const Text('All', style: TextStyle(fontSize: 13)),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All')),
                  DropdownMenuItem(
                      value: 'UNMATCHED', child: Text('Unmatched')),
                  DropdownMenuItem(
                      value: 'PREMATCHED', child: Text('Prematched')),
                  DropdownMenuItem(value: 'MATCHED', child: Text('Matched')),
                ],
                onChanged: (v) {
                  widget.ref
                      .read(mandaysPendingFilterProvider.notifier)
                      .setStatus(v);
                },
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search by employee name or number',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                widget.ref
                    .read(mandaysPendingFilterProvider.notifier)
                    .setSearch(v);
              });
            },
          ),
        ],
      ),
    );
  }
}

class _PendingRowCard extends StatelessWidget {
  final MandaysPendingRow row;
  final VoidCallback onTap;
  const _PendingRowCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final qty = NumberFormat('#,##0.##');
    final date = row.dateSchedule == null
        ? '—'
        : DateFormat('EEE · MMM d, yyyy').format(row.dateSchedule!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.fullName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                      if (row.employeeNo.isNotEmpty)
                        Text(
                          row.employeeNo,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                _StatusPill(status: row.aggregateStatus),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Row(
              children: [
                Expanded(
                    child: _Metric(
                        label: 'Total',
                        value: qty.format(row.totalMandays))),
                Expanded(
                    child: _Metric(
                        label: 'Matched',
                        value: qty.format(row.matchedMandays))),
                Expanded(
                  child: _Metric(
                    label: 'Remaining',
                    value: qty.format(row.remainingMandays),
                    emphasise: row.remainingMandays > 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (fg, bg, label) = switch (status) {
      'MATCHED' => (AppColors.success, AppColors.successLight, 'Matched'),
      'PREMATCHED' => (AppColors.warning, AppColors.warningLight, 'Prematched'),
      'PARTIAL' => (AppColors.warning, AppColors.warningLight, 'Partial'),
      'UNMATCHED' => (AppColors.error, AppColors.errorLight, 'Unmatched'),
      _ => (AppColors.textSecondary, AppColors.surfaceVariant,
          status.isEmpty ? '—' : status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
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
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
              color: emphasise ? AppColors.warning : AppColors.textPrimary),
        ),
      ],
    );
  }
}
