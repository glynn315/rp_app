import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/hangs_models.dart';
import '../providers/hr_provider.dart';

/// Browse "hang" intervals — TAPS time the employee didn't log work
/// against. Mirrors the web mobile `HangsScreen`: 7-day cursor pages,
/// prev/next pagination, per-day grouping with total minutes.
class HangsScreen extends ConsumerStatefulWidget {
  const HangsScreen({super.key});

  @override
  ConsumerState<HangsScreen> createState() => _HangsScreenState();
}

class _HangsScreenState extends ConsumerState<HangsScreen> {
  static const _daysPerPage = 7;

  // Cursor stack so the user can page back. Index 0 is always `null` (the
  // first page). When `goNext` succeeds we push the response's `nextCursor`
  // so prev can replay it.
  final List<String?> _pageCursors = [null];
  int _pageIndex = 0;

  List<HangRowItem> _items = const [];
  String? _nextCursor;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch(null);
  }

  Future<void> _fetch(String? beforeDate) async {
    final user = ref.read(authProvider).user;
    final id = user?.id;
    final code = user?.employeeId;
    if (id == null || id.isEmpty || code == null || code.isEmpty) {
      setState(() {
        _items = const [];
        _hasMore = false;
        _nextCursor = null;
        _error =
            'Missing employee identifiers on signed-in user. Please sign out and back in.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(hrApiProvider);
      final page = await api.listHangs(
        sBpartnerEmployeeId: id,
        employeeCode: code,
        days: _daysPerPage,
        beforeDate: beforeDate,
        token: ref.read(authProvider).token,
      );
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goNext() {
    if (!_hasMore || _nextCursor == null || _loading) return;
    final trimmed = _pageCursors.sublist(0, _pageIndex + 1);
    setState(() {
      _pageCursors
        ..clear()
        ..addAll([...trimmed, _nextCursor]);
      _pageIndex = _pageIndex + 1;
    });
    _fetch(_nextCursor);
  }

  void _goPrev() {
    if (_pageIndex == 0 || _loading) return;
    final newIndex = _pageIndex - 1;
    setState(() => _pageIndex = newIndex);
    _fetch(_pageCursors[newIndex]);
  }

  Future<void> _refresh() async {
    setState(() {
      _pageCursors
        ..clear()
        ..add(null);
      _pageIndex = 0;
    });
    await _fetch(null);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDay(_items);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Hangs'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _buildBody(grouped),
      ),
    );
  }

  Widget _buildBody(List<_DayBucket> grouped) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          const SizedBox(height: 40),
          _ErrorCard(message: _error!),
        ],
      );
    }
    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.md),
        children: const [
          SizedBox(height: 40),
          _EmptyState(
            icon: Icons.hourglass_empty,
            title: 'Nothing hanging',
            body:
                'Every TAPS minute on this page is backed by a logged task. Nice work.',
          ),
        ],
      );
    }

    final showPaginator = _pageIndex > 0 || _hasMore;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: grouped.length + (showPaginator ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, i) {
        if (i >= grouped.length) {
          return _Paginator(
            pageIndex: _pageIndex,
            hasMore: _hasMore,
            disabled: _loading,
            onPrev: _goPrev,
            onNext: _goNext,
          );
        }
        return _DayBucketView(bucket: grouped[i]);
      },
    );
  }

  List<_DayBucket> _groupByDay(List<HangRowItem> rows) {
    final map = <String, List<HangRowItem>>{};
    for (final r in rows) {
      map.putIfAbsent(r.date, () => []).add(r);
    }
    return map.entries
        .map((e) => _DayBucket(date: e.key, rows: e.value))
        .toList();
  }
}

class _DayBucket {
  final String date;
  final List<HangRowItem> rows;
  const _DayBucket({required this.date, required this.rows});

  int get totalMinutes => rows.fold(0, (s, r) => s + r.minutes);
}

class _DayBucketView extends StatelessWidget {
  final _DayBucket bucket;
  const _DayBucketView({required this.bucket});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _formatDayHeader(bucket.date),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${_fmtHm(bucket.totalMinutes)} total',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...bucket.rows.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _HangRow(row: r),
          ),
        ),
      ],
    );
  }

  String _formatDayHeader(String iso) {
    if (iso.isEmpty) return 'Unknown date';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('EEE, MMM d, y').format(d);
  }
}

class _HangRow extends StatelessWidget {
  final HangRowItem row;
  const _HangRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final (Color periodBg, Color periodFg) = switch (row.period) {
      'AM' => (AppColors.successLight, AppColors.success),
      'PM' => (AppColors.info.withValues(alpha: 0.12), AppColors.info),
      _ => (AppColors.warningLight, AppColors.warning),
    };
    final (Color kindBg, Color kindFg) = row.isNoTaps
        ? (AppColors.warningLight, AppColors.warning)
        : (AppColors.neutral100, AppColors.textMuted);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: periodBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        row.period,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: periodFg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${row.timeIn}–${row.timeOut}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  row.isNoTaps
                      ? 'DWR claims this time but no TAPS data yet'
                      : 'Clocked in, no logged task',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtHm(row.minutes),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: kindBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.hourglass_bottom, size: 10, color: kindFg),
                const SizedBox(width: 4),
                Text(
                  row.isNoTaps ? 'No TAPS' : 'Hang',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: kindFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Paginator extends StatelessWidget {
  final int pageIndex;
  final bool hasMore;
  final bool disabled;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _Paginator({
    required this.pageIndex,
    required this.hasMore,
    required this.disabled,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed:
                pageIndex == 0 || disabled ? null : onPrev,
            icon: const Icon(Icons.chevron_left, size: 16),
            label: const Text('Previous'),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Page ${pageIndex + 1}${!hasMore && pageIndex > 0 ? ' · last' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          TextButton.icon(
            onPressed: !hasMore || disabled ? null : onNext,
            icon: const Icon(Icons.chevron_right, size: 16),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.neutral100,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(icon, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline,
              size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtHm(int mins) {
  final m = mins < 0 ? 0 : mins;
  final h = m ~/ 60;
  final r = m % 60;
  if (h == 0 && r == 0) return '0h';
  if (r == 0) return '${h}h';
  if (h == 0) return '${r}m';
  return '${h}h ${r}m';
}
