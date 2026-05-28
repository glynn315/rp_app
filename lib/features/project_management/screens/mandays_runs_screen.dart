import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';

/// Processed Mandays-Matching runs browser. Mirrors the web mobile
/// `MandaysRunsScreen`: PR-only filter, debounced search, expandable
/// per-employee summary detail per run.
class MandaysRunsScreen extends ConsumerStatefulWidget {
  const MandaysRunsScreen({super.key});

  @override
  ConsumerState<MandaysRunsScreen> createState() => _MandaysRunsScreenState();
}

class _MandaysRunsScreenState extends ConsumerState<MandaysRunsScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  String _search = '';
  List<MandaysMatchingRun>? _runs;
  bool _loading = false;
  String? _error;

  int? _openRunId;
  List<MandaysMatchingEmployeeSummary> _summaries = const [];
  bool _detailLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(projectManagementApiProvider);
      final token = ref.read(authProvider).token;
      // Report view: processed runs only — explicit docstatus=PR plus a
      // client-side safety net in case the API ignores the filter.
      final res = await api.mandaysMatchingRuns(
        docstatus: 'PR',
        search: _search.isEmpty ? null : _search,
        token: token,
      );
      if (!mounted) return;
      setState(() => _runs = res.where((r) => r.docstatus == 'PR').toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
      _load();
    });
  }

  Future<void> _toggleRun(int? runId) async {
    if (runId == null) return;
    if (_openRunId == runId) {
      setState(() {
        _openRunId = null;
        _summaries = const [];
      });
      return;
    }
    setState(() {
      _openRunId = runId;
      _summaries = const [];
      _detailLoading = true;
    });
    try {
      final api = ref.read(projectManagementApiProvider);
      final token = ref.read(authProvider).token;
      final rows = await api.mandaysMatchingRunDetail(runId, token: token);
      if (!mounted) return;
      setState(() => _summaries = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Mandays runs'),
        actions: [
          IconButton(
            tooltip: 'Auto-match',
            icon: const Icon(Icons.bolt_outlined),
            onPressed: () => context.push('/projects/mandays-matching/auto'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.all(AppDimensions.md),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search document / payroll…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.neutral200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.neutral200),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final runs = _runs;
    if (_loading && runs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && (runs == null || runs.isEmpty)) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        ],
      );
    }
    if (runs == null || runs.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 60),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Text(
                'No runs.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: runs.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) {
        final r = runs[i];
        final isOpen = r.runId != null && _openRunId == r.runId;
        return _RunCard(
          run: r,
          isOpen: isOpen,
          detailLoading: isOpen && _detailLoading,
          summaries: isOpen ? _summaries : const [],
          onToggle: () => _toggleRun(r.runId),
        );
      },
    );
  }
}

class _RunCard extends StatelessWidget {
  final MandaysMatchingRun run;
  final bool isOpen;
  final bool detailLoading;
  final List<MandaysMatchingEmployeeSummary> summaries;
  final VoidCallback onToggle;

  const _RunCard({
    required this.run,
    required this.isOpen,
    required this.detailLoading,
    required this.summaries,
    required this.onToggle,
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          run.documentNo.isEmpty ? '—' : run.documentNo,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: run.isProcessed
                              ? AppColors.successLight
                              : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          run.docstatus,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: run.isProcessed
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        isOpen ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _subline(run),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  // 2x2 stats grid mirroring the web layout.
                  _StatsGrid(run: run, money: money),
                ],
              ),
            ),
          ),
          if (isOpen)
            Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                border: Border(
                  top: BorderSide(color: AppColors.neutral100),
                ),
              ),
              padding: const EdgeInsets.all(AppDimensions.sm),
              child: _DetailBody(
                loading: detailLoading,
                summaries: summaries,
                money: money,
              ),
            ),
        ],
      ),
    );
  }

  String _subline(MandaysMatchingRun r) {
    final parts = <String>[
      'Payroll ${r.payrollRun.isEmpty ? '—' : r.payrollRun}',
      '${r.employeeCount} employees',
      if (r.dateProcessed != null)
        DateFormat('MMM d, y').format(r.dateProcessed!),
    ];
    return parts.join(' · ');
  }
}

class _StatsGrid extends StatelessWidget {
  final MandaysMatchingRun run;
  final NumberFormat money;
  const _StatsGrid({required this.run, required this.money});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _kv(
                'Total qty',
                run.grandTotalQty.toStringAsFixed(2),
              ),
            ),
            Expanded(
              child: _kv(
                'Accounted',
                money.format(run.totalAccountedSalary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _kv(
                'Manual',
                run.totalManualQty.toStringAsFixed(2),
              ),
            ),
            Expanded(
              child: _kv(
                'Unaccounted',
                money.format(run.totalUnaccountedSalary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Row(
        children: [
          Text(
            '$k: ',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}

class _DetailBody extends StatelessWidget {
  final bool loading;
  final List<MandaysMatchingEmployeeSummary> summaries;
  final NumberFormat money;
  const _DetailBody({
    required this.loading,
    required this.summaries,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (summaries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No employee summaries.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }
    return Column(
      children: summaries
          .map(
            (s) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sm,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.fullName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        s.grandTotalQty.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Accounted ${money.format(s.totalAccountedSalary)} · '
                    'Unaccounted ${money.format(s.totalUnaccountedSalary)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
