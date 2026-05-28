import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/taps_sync_models.dart';
import '../providers/hr_provider.dart';

/// Browse the signed-in employee's TAPS punches grouped by day. Mirrors
/// the web mobile `TapsSyncScreen`: matched-only by default with a
/// "Matched / All punches" segmented filter, cursor-paginated by day.
class TapsSyncScreen extends ConsumerStatefulWidget {
  const TapsSyncScreen({super.key});

  @override
  ConsumerState<TapsSyncScreen> createState() => _TapsSyncScreenState();
}

class _TapsSyncScreenState extends ConsumerState<TapsSyncScreen> {
  static const _daysPerPage = 30;

  final List<TapsRawLog> _items = [];
  String? _cursor;
  bool _hasMore = false;
  bool _includeUnmatched = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    final user = ref.read(authProvider).user;
    final id = user?.id;
    if (id == null || id.isEmpty) {
      setState(() {
        _items.clear();
        _hasMore = false;
        _cursor = null;
        _error =
            'Missing employee id on signed-in user. Please sign out and back in.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(hrApiProvider);
      final page = await api.listTapsSync(
        sBpartnerEmployeeId: id,
        days: _daysPerPage,
        includeUnmatched: _includeUnmatched,
        token: ref.read(authProvider).token,
      );
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final user = ref.read(authProvider).user;
    final id = user?.id;
    if (id == null || _cursor == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final api = ref.read(hrApiProvider);
      final page = await api.listTapsSync(
        sBpartnerEmployeeId: id,
        days: _daysPerPage,
        beforeDate: _cursor,
        includeUnmatched: _includeUnmatched,
        token: ref.read(authProvider).token,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _cursor = page.nextCursor;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _setIncludeUnmatched(bool v) {
    if (_includeUnmatched == v) return;
    setState(() {
      _includeUnmatched = v;
      _items.clear();
      _cursor = null;
      _hasMore = false;
    });
    _loadFirst();
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
        title: const Text('Taps sync'),
      ),
      body: Column(
        children: [
          _FilterStrip(
            includeUnmatched: _includeUnmatched,
            onChanged: _setIncludeUnmatched,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFirst,
              child: _buildBody(grouped),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<_DayGroup> grouped) {
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
        children: [
          const SizedBox(height: 40),
          _EmptyState(
            icon: Icons.access_time,
            title: _includeUnmatched ? 'No tap logs' : 'No matched taps yet',
            body: _includeUnmatched
                ? 'No taps found for your account in this range.'
                : 'Switch to "All punches" to also surface raw punches the matcher hasn\'t paired yet.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.md),
      itemCount: grouped.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppDimensions.md),
      itemBuilder: (context, i) {
        if (i >= grouped.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
            child: OutlinedButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: Text(_loadingMore ? 'Loading…' : 'Load more'),
            ),
          );
        }
        return _DayGroupView(group: grouped[i]);
      },
    );
  }

  List<_DayGroup> _groupByDay(List<TapsRawLog> rows) {
    final map = <String, List<TapsRawLog>>{};
    for (final r in rows) {
      final key = r.dayKey.isEmpty ? 'unknown' : r.dayKey;
      map.putIfAbsent(key, () => []).add(r);
    }
    return map.entries
        .map((e) => _DayGroup(date: e.key, rows: e.value))
        .toList();
  }
}

class _DayGroup {
  final String date;
  final List<TapsRawLog> rows;
  const _DayGroup({required this.date, required this.rows});
}

class _FilterStrip extends StatelessWidget {
  final bool includeUnmatched;
  final ValueChanged<bool> onChanged;
  const _FilterStrip({
    required this.includeUnmatched,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.sm,
        AppDimensions.md,
        AppDimensions.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SHOW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SegmentButton(
                  label: 'Matched',
                  selected: !includeUnmatched,
                  onTap: () => onChanged(false),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _SegmentButton(
                  label: 'All punches',
                  selected: includeUnmatched,
                  onTap: () => onChanged(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.neutral100,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                selected ? AppColors.textOnPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DayGroupView extends StatelessWidget {
  final _DayGroup group;
  const _DayGroupView({required this.group});

  @override
  Widget build(BuildContext context) {
    final inCount = group.rows.where((r) => r.logType == 'IN').length;
    final outCount = group.rows.where((r) => r.logType == 'OUT').length;
    final total = group.rows.length;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _formatDayHeader(group.date),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '$total tap${total == 1 ? '' : 's'} · $inCount in · $outCount out',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ...group.rows.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _TapRow(row: r),
          ),
        ),
      ],
    );
  }

  String _formatDayHeader(String iso) {
    if (iso.isEmpty || iso == 'unknown') return 'Unknown date';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat('EEE, MMM d, y').format(d);
  }
}

class _TapRow extends StatelessWidget {
  final TapsRawLog row;
  const _TapRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final (Color badgeBg, Color badgeFg) = switch (row.logType) {
      'IN' => (AppColors.successLight, AppColors.success),
      'OUT' => (AppColors.info.withValues(alpha: 0.12), AppColors.info),
      _ => (AppColors.neutral100, AppColors.textMuted),
    };
    return Container(
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Text(
              row.logType.isEmpty ? '—' : row.logType,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: badgeFg,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.timeOfDay.isEmpty ? '—' : row.timeOfDay,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (row.isOvertime) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'OT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AppColors.warning,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: row.isMatched
                  ? AppColors.successLight
                  : AppColors.errorLight,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  row.isMatched ? Icons.check : Icons.close,
                  size: 10,
                  color: row.isMatched ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                Text(
                  row.isMatched ? 'Matched' : 'Unmatched',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color:
                        row.isMatched ? AppColors.success : AppColors.error,
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
        border: Border.all(
          color: AppColors.neutral200,
          style: BorderStyle.solid,
        ),
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
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
