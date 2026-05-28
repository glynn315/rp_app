import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';

/// Fires the LMC auto-match resolver over a date window. Mirrors the web
/// mobile `MandaysAutoRunScreen` — dry-run by default, copy run_id action,
/// APPLY/DEFER/ERROR tile breakdown, advanced minutes-per-manday override.
class MandaysAutoRunScreen extends ConsumerStatefulWidget {
  const MandaysAutoRunScreen({super.key});

  @override
  ConsumerState<MandaysAutoRunScreen> createState() =>
      _MandaysAutoRunScreenState();
}

class _MandaysAutoRunScreenState extends ConsumerState<MandaysAutoRunScreen> {
  static const _defaultMpm = 480; // 8h in minutes
  static const _ymd = 'yyyy-MM-dd';

  late DateTime _dateFrom;
  late DateTime _dateTo;
  bool _dryRun = true;
  bool _showAdvanced = false;
  final _mpmCtrl = TextEditingController(text: '$_defaultMpm');

  bool _running = false;
  String? _error;
  MandaysAutoRunResult? _result;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateTo = DateTime(now.year, now.month, now.day);
    _dateFrom = _dateTo.subtract(const Duration(days: 30));
  }

  @override
  void dispose() {
    _mpmCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
  }

  Future<void> _onRun() async {
    setState(() {
      _error = null;
      _result = null;
    });
    if (_dateFrom.isAfter(_dateTo)) {
      setState(() => _error = 'Start date must be on or before end date.');
      return;
    }
    if (!_dryRun) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Live run — confirm'),
          content: Text(
            'This will create MDM-PRJ matching docs (posted directly to PR) '
            'for every APPLY decision between '
            '${DateFormat(_ymd).format(_dateFrom)} and '
            '${DateFormat(_ymd).format(_dateTo)}.\n\nProceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run live'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final mpm = int.tryParse(_mpmCtrl.text.trim()) ?? _defaultMpm;
    setState(() => _running = true);
    try {
      final api = ref.read(projectManagementApiProvider);
      final token = ref.read(authProvider).token;
      final r = await api.mandaysAutoRun(
        dateFrom: DateFormat(_ymd).format(_dateFrom),
        dateTo: DateFormat(_ymd).format(_dateTo),
        dryRun: _dryRun,
        minutesPerManday: mpm == _defaultMpm ? null : mpm,
        token: token,
      );
      if (!mounted) return;
      setState(() => _result = r);
      // Invalidate the runs list so users navigating to /projects/mandays-runs
      // after a live run see the freshly-created PR doc.
      if (!_dryRun) ref.invalidate(mandaysRunsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _copyRunId() async {
    final id = _result?.runId;
    if (id == null || id.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
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
        title: const Text('Auto-match (LMC)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.md),
        children: [
          _windowCard(),
          if (_result != null) ...[
            const SizedBox(height: AppDimensions.md),
            _resultCard(_result!),
          ],
        ],
      ),
    );
  }

  Widget _windowCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Window',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'FROM',
                  value: _dateFrom,
                  onTap: () async {
                    final picked = await _pickDate(_dateFrom);
                    if (picked != null) setState(() => _dateFrom = picked);
                  },
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: _DateField(
                  label: 'TO',
                  value: _dateTo,
                  onTap: () async {
                    final picked = await _pickDate(_dateTo);
                    if (picked != null) setState(() => _dateTo = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          // Dry-run toggle
          Row(
            children: [
              Checkbox(
                value: _dryRun,
                onChanged: (v) => setState(() => _dryRun = v ?? true),
                activeColor: AppColors.primary,
              ),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Dry run ',
                        style: TextStyle(fontSize: 13),
                      ),
                      TextSpan(
                        text: '(no writes — preview only)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Advanced toggle
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _showAdvanced = !_showAdvanced),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _showAdvanced ? 'Hide advanced' : 'Advanced settings',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          if (_showAdvanced) ...[
            const SizedBox(height: AppDimensions.sm),
            TextField(
              controller: _mpmCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Minutes per manday',
                helperText:
                    'Default 480 (8h). Converts TAPS minutes → manday qty.',
                isDense: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: AppDimensions.md),
          ElevatedButton.icon(
            onPressed: _running ? null : _onRun,
            icon: Icon(_dryRun ? Icons.preview_outlined : Icons.bolt),
            label: Text(
              _running
                  ? 'Running…'
                  : _dryRun
                      ? 'Run dry-run'
                      : 'Run live (posts PR docs)',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _dryRun ? AppColors.steel : AppColors.error,
              foregroundColor: AppColors.textOnPrimary,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppDimensions.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: AppDimensions.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _resultCard(MandaysAutoRunResult r) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.dryRun ? 'Dry-run complete' : 'Live run complete',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${r.count} decision${r.count == 1 ? '' : 's'} persisted to '
                      'wbs_i_mandays_auto_match_decisions',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _copyRunId,
                icon: Icon(_copied ? Icons.check : Icons.copy, size: 14),
                label: Text(_copied ? 'Copied' : 'Copy run_id'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          SelectableText(
            r.runId,
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'APPLY',
                  value: r.applyCount,
                  tone: r.dryRun ? _Tone.neutral : _Tone.success,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  label: 'DEFER',
                  value: r.deferCount,
                  tone: _Tone.warning,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StatTile(
                  label: 'ERROR',
                  value: r.errorCount,
                  tone: _Tone.danger,
                ),
              ),
            ],
          ),
          if (r.dryRun && r.applyCount > 0) ...[
            const SizedBox(height: AppDimensions.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.md,
                vertical: AppDimensions.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                '${r.applyCount} decision${r.applyCount == 1 ? '' : 's'} would '
                'create MDM-PRJ docs. Re-run with dry-run off to write them '
                'as DR.',
                style: const TextStyle(fontSize: 11, color: AppColors.warning),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
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
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, y').format(value),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _Tone { success, warning, danger, neutral }

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final _Tone tone;
  const _StatTile({
    required this.label,
    required this.value,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (tone) {
      _Tone.success => (AppColors.successLight, AppColors.success),
      _Tone.warning => (AppColors.warningLight, AppColors.warning),
      _Tone.danger => (AppColors.errorLight, AppColors.error),
      _Tone.neutral => (AppColors.neutral100, AppColors.textPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.sm,
        vertical: AppDimensions.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: fg,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
