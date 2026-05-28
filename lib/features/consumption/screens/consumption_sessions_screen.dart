import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/consumption_models.dart';
import '../providers/consumption_provider.dart';

/// Browse local consumption sessions across every project. Mirrors the web
/// mobile `ConsumptionSessionsScreen`: status tabs (All/Draft/Posted/Voided),
/// debounced free-text search, and `meta.last_page`-driven "Show more".
class ConsumptionSessionsScreen extends ConsumerStatefulWidget {
  const ConsumptionSessionsScreen({super.key});

  @override
  ConsumerState<ConsumptionSessionsScreen> createState() =>
      _ConsumptionSessionsScreenState();
}

class _ConsumptionSessionsScreenState
    extends ConsumerState<ConsumptionSessionsScreen> {
  static const _statusFilters = <_StatusOption>[
    _StatusOption(value: null, label: 'All'),
    _StatusOption(value: 'draft', label: 'Draft'),
    _StatusOption(value: 'posted', label: 'Posted'),
    _StatusOption(value: 'voided', label: 'Voided'),
  ];
  static const _perPage = 20;

  String? _status;
  String _search = '';
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  final List<ConsumptionSessionsPage> _pages = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(consumptionApiProvider);
      final page = await api.listSessions(
        status: _status,
        search: _search.isEmpty ? null : _search,
        page: 1,
        perPage: _perPage,
      );
      if (!mounted) return;
      setState(() {
        _pages
          ..clear()
          ..add(page);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pages.clear();
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final last = _pages.isNotEmpty ? _pages.last : null;
    if (last == null || !last.hasMore || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final api = ref.read(consumptionApiProvider);
      final next = await api.listSessions(
        status: _status,
        search: _search.isEmpty ? null : _search,
        page: last.page + 1,
        perPage: last.perPage,
      );
      if (!mounted) return;
      setState(() => _pages.add(next));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = value.trim());
      _loadFirstPage();
    });
  }

  void _setStatus(String? value) {
    if (_status == value) return;
    setState(() => _status = value);
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    final items = _pages.expand((p) => p.items).toList();
    final last = _pages.isNotEmpty ? _pages.last : null;
    final hasMore = last?.hasMore ?? false;
    final total = last?.total ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Sessions'),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.sm,
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by reference or doc no…',
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
                const SizedBox(height: AppDimensions.sm),
                Row(
                  children: _statusFilters
                      .map(
                        (f) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: _StatusTab(
                              label: f.label,
                              selected: _status == f.value,
                              onTap: () => _setStatus(f.value),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFirstPage,
              child: _buildBody(items, hasMore, total),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    List<ConsumptionSessionSummary> items,
    bool hasMore,
    int total,
  ) {
    if (_loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 60),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
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
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 60),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Text(
                'No sessions match the current filter.',
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
      itemCount: items.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.sm),
      itemBuilder: (context, i) {
        if (i >= items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
            child: OutlinedButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: Text(
                _loadingMore
                    ? 'Loading…'
                    : 'Show more (${items.length} of $total)',
              ),
            ),
          );
        }
        return _SessionRow(session: items[i]);
      },
    );
  }
}

class _StatusOption {
  final String? value;
  final String label;
  const _StatusOption({required this.value, required this.label});
}

class _StatusTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final ConsumptionSessionSummary session;
  const _SessionRow({required this.session});

  @override
  Widget build(BuildContext context) {
    final dateText = _relative(session.updatedAt ?? session.createdAt);
    return InkWell(
      onTap: () => context.push('/consumption/sessions/${session.id}'),
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
                  child: Text(
                    session.projectName ??
                        session.referenceNumber ??
                        'Session #${session.id}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _StatusPill(status: session.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _subline(session),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'Consumed '),
                        TextSpan(
                          text: _fmtQty(session.totalConsumedQty),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (session.totalOverQty > 0) ...[
                          const TextSpan(text: ' · Over '),
                          TextSpan(
                            text: _fmtQty(session.totalOverQty),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (dateText.isNotEmpty)
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
            // Posted sessions can be cross-checked against the ERP — surface
            // the link inline so users don't have to drill into the session.
            if (session.isPosted) ...[
              const SizedBox(height: AppDimensions.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => context.push(
                    '/consumption/sessions/${session.id}/erp-verify',
                  ),
                  icon: const Icon(Icons.fact_check_outlined, size: 16),
                  label: const Text('Verify against ERP'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _subline(ConsumptionSessionSummary s) {
    final parts = <String>[];
    if (s.erpDocumentNo != null) parts.add(s.erpDocumentNo!);
    if (s.referenceNumber != null &&
        s.referenceNumber != s.erpDocumentNo) {
      parts.add('Ref ${s.referenceNumber}');
    }
    parts.add('${s.linesCount} line${s.linesCount == 1 ? '' : 's'}');
    return parts.join(' · ');
  }

  String _fmtQty(double v) {
    if (!v.isFinite) return '0';
    return v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  String _relative(DateTime? d) {
    if (d == null) return '';
    return DateFormat('MMM d, y').format(d);
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (status) {
      'posted' => (AppColors.successLight, AppColors.success),
      'voided' => (AppColors.neutral100, AppColors.textMuted),
      _ => (AppColors.warningLight, AppColors.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: fg,
        ),
      ),
    );
  }
}
