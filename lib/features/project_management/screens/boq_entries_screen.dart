import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../../daily_work_report/services/daily_work_report_api.dart';
import '../../daily_work_report/theme/work_report_colors.dart';
import '../models/project_management_models.dart';
import '../widgets/boq_kind_chip.dart';

/// Lists every work block the current employee has logged against a single
/// BoQ line. Compact rows; tap to expand for photos, AI verdict, and notes.
class BoqEntriesScreen extends ConsumerStatefulWidget {
  final BoqItem? item;

  const BoqEntriesScreen({super.key, required this.item});

  @override
  ConsumerState<BoqEntriesScreen> createState() => _BoqEntriesScreenState();
}

class _BoqEntriesScreenState extends ConsumerState<BoqEntriesScreen> {
  final DailyWorkReportApi _api = DailyWorkReportApi();

  List<Map<String, dynamic>> _entries = const [];
  bool _loading = false;
  String? _error;

  BoqItem? get _item => widget.item;
  String get _boqItemId => _item?.lineId?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final empId = ref.read(authProvider).user?.employeeId ?? '';
    if (empId.isEmpty) {
      setState(() => _error = 'No signed-in employee — log in again.');
      return;
    }
    if (_boqItemId.isEmpty) {
      setState(() => _error = 'This BOQ line has no line_id.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listBoqEntries(
        employeeId: empId,
        boqItemId: _boqItemId,
      );
      if (!mounted) return;
      setState(() {
        _entries = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load entries: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My entries'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.md),
          children: _buildBody(),
        ),
      ),
    );
  }

  List<Widget> _buildBody() {
    final item = _item;
    if (item == null) {
      return const [
        SizedBox(height: 64),
        Icon(Icons.list_alt, size: 56, color: AppColors.textMuted),
        SizedBox(height: 12),
        Text(
          'No BOQ line selected',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ];
    }

    return [
      _ScopeHeader(item: item, count: _entries.length),
      const SizedBox(height: AppDimensions.md),
      if (_error != null) ...[
        _ErrorBanner(message: _error!),
        const SizedBox(height: AppDimensions.sm),
      ],
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_entries.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Center(
            child: Text(
              'No entries logged against this BOQ yet.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted.withValues(alpha: 0.9),
              ),
            ),
          ),
        )
      else
        ..._entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _EntryTile(entry: e),
          ),
        ),
      const SizedBox(height: AppDimensions.lg),
    ];
  }
}

class _ScopeHeader extends StatelessWidget {
  final BoqItem item;
  final int count;

  const _ScopeHeader({required this.item, required this.count});

  @override
  Widget build(BuildContext context) {
    final headline = item.itemLabel.isNotEmpty
        ? item.itemLabel
        : (item.scopeName.isNotEmpty ? item.scopeName : item.projectName);
    final sub = [item.scopeName, item.stageName]
        .where((s) => s.isNotEmpty)
        .join(' · ');

    return Container(
      width: double.infinity,
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
                  headline,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '$count entr${count == 1 ? 'y' : 'ies'} for this BOQ',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatefulWidget {
  final Map<String, dynamic> entry;

  const _EntryTile({required this.entry});

  @override
  State<_EntryTile> createState() => _EntryTileState();
}

class _EntryTileState extends State<_EntryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final reportDate = e['report_date']?.toString();
    final timeIn = e['time_in']?.toString() ?? '';
    final timeOut = e['time_out']?.toString() ?? '';
    final tasks = e['tasks']?.toString() ?? '';
    final verdict = e['ai_verdict']?.toString() ?? '';
    final reportStatus = e['report_status']?.toString() ?? '';
    final isLateMatch = e['is_late_match'] == true;
    final photos = (e['photo_urls'] as List?)?.whereType<String>().toList() ?? const <String>[];
    final summary = _firstLine(tasks);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _fmtDate(reportDate),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$timeIn–$timeOut',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isLateMatch) ...[
                              const SizedBox(width: 6),
                              const _StatusChip(
                                label: 'LATE',
                                color: WorkReportColors.stone,
                              ),
                            ],
                            if (reportStatus.isNotEmpty &&
                                reportStatus != 'submitted') ...[
                              const SizedBox(width: 6),
                              _StatusChip(
                                label: reportStatus.toUpperCase(),
                                color: WorkReportColors.stone,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.isEmpty ? '(no task notes)' : summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            fontStyle: summary.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (verdict.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _VerdictChip(verdict: verdict),
                  ],
                  if (photos.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo,
                            size: 14, color: AppColors.textMuted),
                        const SizedBox(width: 2),
                        Text(
                          '${photos.length}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (tasks.isNotEmpty) ...[
                    const _MiniLabel('TASKS'),
                    const SizedBox(height: 4),
                    Text(
                      tasks,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  if ((e['ai_evaluation']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const _MiniLabel('AI EVALUATION'),
                    const SizedBox(height: 4),
                    Text(
                      e['ai_evaluation'].toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const _MiniLabel('PHOTOS'),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: photos.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            photos[i],
                            width: 120,
                            height: 90,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              width: 120,
                              height: 90,
                              color: AppColors.neutral100,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image,
                                  size: 18, color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _firstLine(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    final nl = t.indexOf('\n');
    return nl < 0 ? t : t.substring(0, nl).trim();
  }

  String _fmtDate(String? ymd) {
    if (ymd == null || ymd.isEmpty) return '—';
    try {
      final d = DateTime.parse(ymd);
      return DateFormat('MMM d, y').format(d);
    } catch (_) {
      return ymd;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _VerdictChip extends StatelessWidget {
  final String verdict;

  const _VerdictChip({required this.verdict});

  @override
  Widget build(BuildContext context) {
    final lc = verdict.toLowerCase();
    final color = switch (lc) {
      'ok' => WorkReportColors.success,
      'retake' => WorkReportColors.danger,
      _ => WorkReportColors.stone,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        lc.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String label;
  const _MiniLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: WorkReportColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 14, color: WorkReportColors.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: WorkReportColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
