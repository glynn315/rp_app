import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';

/// Accounted-salary period reports — mirrors the legacy AppSheet PDFs
/// `accountedsalaryperprojectscopeperperiod.pdf` and
/// `accountedsalarypercontracttype.<type>.pdf`. Two tabs: per-project and
/// per-contract-type. Date range defaults to the current month.
class MandaysReportsScreen extends ConsumerStatefulWidget {
  const MandaysReportsScreen({super.key});

  @override
  ConsumerState<MandaysReportsScreen> createState() =>
      _MandaysReportsScreenState();
}

class _MandaysReportsScreenState extends ConsumerState<MandaysReportsScreen> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  int _tab = 0;
  bool _loading = false;
  String? _error;

  List<MandaysReportProjectRow> _project = const [];
  MandaysReportContractTypeResult? _contract;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(projectManagementApiProvider);
      final token = ref.read(authProvider).token;
      if (_tab == 0) {
        final rows = await api.reportAccountedSalaryPerProject(
            dateFrom: _from, dateTo: _to, token: token);
        if (!mounted) return;
        setState(() => _project = rows);
      } else {
        final res = await api.reportAccountedSalaryPerContractType(
            dateFrom: _from, dateTo: _to, token: token);
        if (!mounted) return;
        setState(() => _contract = res);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: _to,
    );
    if (picked != null) {
      setState(() => _from = picked);
      _load();
    }
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: _from,
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _to = picked);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ymd = DateFormat('MMM d, yyyy');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounted-Salary Reports'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.pureWhite,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter strip — date range + segmented tab.
            Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _pickFrom,
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text('From ${ymd.format(_from)}'),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : _pickTo,
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text('To ${ymd.format(_to)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Per Project')),
                      ButtonSegment(value: 1, label: Text('Per Contract Type')),
                    ],
                    selected: {_tab},
                    onSelectionChanged: (s) {
                      setState(() => _tab = s.first);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorBox(message: _error!, onRetry: _load)
                      : _tab == 0
                          ? _ProjectReport(rows: _project)
                          : _ContractTypeReport(result: _contract),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectReport extends StatelessWidget {
  final List<MandaysReportProjectRow> rows;
  const _ProjectReport({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No accounted salary in this period.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final qty = NumberFormat('#,##0.##');
    final totalSalary =
        rows.fold<double>(0, (a, r) => a + r.accountedSalary);
    final totalDays = rows.fold<double>(0, (a, r) => a + r.totalMandays);
    return Column(
      children: [
        _TotalsBar(items: [
          ('Total mandays', qty.format(totalDays)),
          ('Total accounted', money.format(totalSalary)),
          ('Lines', rows.length.toString()),
        ]),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final r = rows[i];
              return Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.mist),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.projectName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(r.stageName,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                            child: Text('${qty.format(r.totalMandays)} mandays',
                                style: const TextStyle(fontSize: 12))),
                        Text(money.format(r.accountedSalary),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.terracotta)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContractTypeReport extends StatelessWidget {
  final MandaysReportContractTypeResult? result;
  const _ContractTypeReport({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null || result!.rows.isEmpty) {
      return const Center(
        child: Text(
          'No accounted salary in this period.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final r = result!;
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final qty = NumberFormat('#,##0.##');
    final totalSalary =
        r.rows.fold<double>(0, (a, x) => a + x.accountedSalary);
    final totalDays = r.rows.fold<double>(0, (a, x) => a + x.totalMandays);
    return Column(
      children: [
        _TotalsBar(items: [
          ('Total mandays', qty.format(totalDays)),
          ('Total accounted', money.format(totalSalary)),
          ('Types', r.rows.length.toString()),
        ]),
        if (!r.hasSplitData)
          Container(
            margin: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: 4),
            padding: const EdgeInsets.all(AppDimensions.sm),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: const Text(
              'BSCSL/PITAI split not available on the current schema — '
              'showing totals only.',
              style: TextStyle(fontSize: 11, color: AppColors.warning),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            itemCount: r.rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final row = r.rows[i];
              return Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.mist),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.contractTypeName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                            child: Text('${qty.format(row.totalMandays)} mandays',
                                style: const TextStyle(fontSize: 12))),
                        Text(money.format(row.accountedSalary),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.terracotta)),
                      ],
                    ),
                    if (r.hasSplitData) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniLabel(
                              label: 'BSCSL',
                              value: money.format(row.accountedSalaryBscsl),
                            ),
                          ),
                          Expanded(
                            child: _MiniLabel(
                              label: 'PITAI',
                              value: money.format(row.accountedSalaryPitai),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String label;
  final String value;
  const _MiniLabel({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                letterSpacing: 0.4)),
        Text(value,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TotalsBar extends StatelessWidget {
  final List<(String, String)> items;
  const _TotalsBar({required this.items});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      decoration: const BoxDecoration(
        color: AppColors.mist,
        border: Border(
          bottom: BorderSide(color: AppColors.mist),
        ),
      ),
      child: Row(
        children: [
          for (final it in items)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.$1,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.4)),
                  Text(it.$2,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 32),
            const SizedBox(height: AppDimensions.sm),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: AppDimensions.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
