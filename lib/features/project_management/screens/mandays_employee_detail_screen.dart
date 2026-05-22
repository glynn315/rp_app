import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';
import '../widgets/mandays_match_dialogs.dart';

/// Per-employee × per-date matching cockpit. Shows TA logs, the running
/// matched/remaining tally, existing matchings, and the four match-type
/// launchers (Project / Charging / Account Pair / Unaccounted).
class MandaysEmployeeDetailScreen extends ConsumerWidget {
  final MandaysPendingRow row;
  const MandaysEmployeeDetailScreen({super.key, required this.row});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = row.dateSchedule;
    if (date == null) {
      return Scaffold(
        appBar: AppBar(title: Text(row.fullName)),
        body: const Center(
          child: Text('Schedule date missing — cannot load detail.'),
        ),
      );
    }

    final key = MandaysEmployeeDateKey(row.employeeId, date);
    final logsAsync = ref.watch(mandaysTaLogsProvider(key));
    final matchingsAsync = ref.watch(mandaysEmployeeMatchingsProvider(key));
    final derAsync = ref.watch(mandaysEmployeeDerProvider(row.employeeId));

    final logs = logsAsync.value ?? const <MandaysTaLog>[];
    final matchings = matchingsAsync.value ?? const <MandaysMatchingDoc>[];
    final der = derAsync.value;

    final totalMandays = logs.fold<double>(0, (a, l) => a + l.mandayQty);
    final matchedQty = matchings
        .where((m) => m.docstatus != 'CA')
        .fold<double>(0, (a, m) => a + m.matchedQty);
    final remaining = (totalMandays - matchedQty).clamp(0, totalMandays);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(row.fullName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding:
                const EdgeInsets.only(left: AppDimensions.md, bottom: AppDimensions.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                DateFormat('EEE · MMM d, yyyy').format(date),
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textOnPrimary.withValues(alpha: 0.85)),
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mandaysTaLogsProvider(key));
          ref.invalidate(mandaysEmployeeMatchingsProvider(key));
          await Future.wait([
            ref.read(mandaysTaLogsProvider(key).future),
            ref.read(mandaysEmployeeMatchingsProvider(key).future),
          ]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.md),
          children: [
            _SummaryCard(
              totalMandays: totalMandays,
              matchedMandays: matchedQty,
              remainingMandays: remaining.toDouble(),
              der: der,
            ),
            const SizedBox(height: AppDimensions.md),
            _ActionButtons(
              enabled: der != null && remaining > 0,
              onProject: () => _openDialog(
                context,
                ref,
                key,
                (ctx) => showProjectMatchDialog(context, ctx),
                logs,
                der,
                remaining.toDouble(),
              ),
              onCharging: () => _openDialog(
                context,
                ref,
                key,
                (ctx) => showChargingMatchDialog(context, ctx),
                logs,
                der,
                remaining.toDouble(),
              ),
              onAcctPair: () => _openDialog(
                context,
                ref,
                key,
                (ctx) => showAcctPairMatchDialog(context, ctx),
                logs,
                der,
                remaining.toDouble(),
              ),
              onUnaccounted: () => _openDialog(
                context,
                ref,
                key,
                (ctx) => showUnaccountedMatchDialog(context, ctx),
                logs,
                der,
                remaining.toDouble(),
              ),
            ),
            const SizedBox(height: AppDimensions.lg),
            _SectionHeader(
                'Time Attendance Logs',
                trailing: logsAsync.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null),
            if (logsAsync.hasError)
              _ErrorBox(message: logsAsync.error.toString())
            else if (logs.isEmpty)
              const _EmptyBox(
                  message: 'No TA logs synced for this date.'),
            ...logs.map((l) => _TaLogTile(log: l)),
            const SizedBox(height: AppDimensions.lg),
            _SectionHeader('Mandays Matched',
                trailing: matchingsAsync.isLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : null),
            if (matchingsAsync.hasError)
              _ErrorBox(message: matchingsAsync.error.toString())
            else if (matchings.isEmpty)
              const _EmptyBox(
                  message: 'No matching docs yet. Use the buttons above.'),
            ...matchings.map((m) => _MatchingTile(
                  doc: m,
                  employeeId: row.employeeId,
                  employeeName: row.fullName,
                  onProcess: () => _processOrCancel(
                      context, ref, key, m.matchingId, process: true),
                  onCancel: () => _processOrCancel(
                      context, ref, key, m.matchingId, process: false),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _openDialog(
    BuildContext context,
    WidgetRef ref,
    MandaysEmployeeDateKey key,
    Future<bool> Function(MandaysDialogContext) launch,
    List<MandaysTaLog> logs,
    MandaysDer? der,
    double remaining,
  ) async {
    if (der == null) {
      _snack(context, 'No daily equivalent rate found for this employee.');
      return;
    }
    if (logs.isEmpty) {
      _snack(context, 'No TA logs to attach the matching to.');
      return;
    }
    final api = ref.read(projectManagementApiProvider);
    final token = ref.read(authProvider).token;
    final ctx = MandaysDialogContext(
      employeeId: row.employeeId,
      dateSchedule: row.dateSchedule!,
      availableMandays: remaining,
      der: der,
      taLogIds: logs.map((l) => l.talId).toList(),
      api: api,
      token: token,
    );
    final saved = await launch(ctx);
    if (saved && context.mounted) {
      ref.invalidate(mandaysEmployeeMatchingsProvider(key));
      ref.invalidate(mandaysPendingProvider);
      _snack(context, 'Saved as prematched. Forward to the checker.');
    }
  }

  Future<void> _processOrCancel(
    BuildContext context,
    WidgetRef ref,
    MandaysEmployeeDateKey key,
    int matchingId, {
    required bool process,
  }) async {
    final api = ref.read(projectManagementApiProvider);
    final token = ref.read(authProvider).token;
    try {
      if (process) {
        await api.mandaysProcess(matchingId: matchingId, token: token);
      } else {
        await api.mandaysCancel(matchingId: matchingId, token: token);
      }
      if (!context.mounted) return;
      ref.invalidate(mandaysEmployeeMatchingsProvider(key));
      ref.invalidate(mandaysPendingProvider);
      _snack(context, process ? 'Matching processed.' : 'Matching cancelled.');
    } on ApiException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _SummaryCard extends StatelessWidget {
  final double totalMandays;
  final double matchedMandays;
  final double remainingMandays;
  final MandaysDer? der;

  const _SummaryCard({
    required this.totalMandays,
    required this.matchedMandays,
    required this.remainingMandays,
    required this.der,
  });

  @override
  Widget build(BuildContext context) {
    final qty = NumberFormat('#,##0.##');
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _SummaryCell(
                      label: 'Total', value: qty.format(totalMandays))),
              Expanded(
                  child: _SummaryCell(
                      label: 'Matched', value: qty.format(matchedMandays))),
              Expanded(
                child: _SummaryCell(
                  label: 'Remaining',
                  value: qty.format(remainingMandays),
                  emphasise: remainingMandays > 0,
                ),
              ),
            ],
          ),
          const Divider(height: AppDimensions.lg),
          Row(
            children: [
              const Icon(Icons.attach_money,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: AppDimensions.xs),
              const Text('Daily Equivalent Rate',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Text(
                der == null ? '— sync DER from TAPS' : money.format(der!.der),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: der == null
                      ? AppColors.warning
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;
  const _SummaryCell(
      {required this.label, required this.value, this.emphasise = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: emphasise ? AppColors.warning : AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool enabled;
  final VoidCallback onProject;
  final VoidCallback onCharging;
  final VoidCallback onAcctPair;
  final VoidCallback onUnaccounted;

  const _ActionButtons({
    required this.enabled,
    required this.onProject,
    required this.onCharging,
    required this.onAcctPair,
    required this.onUnaccounted,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.sm,
      runSpacing: AppDimensions.sm,
      children: [
        _ActionButton(
            icon: Icons.work,
            label: 'Project',
            onPressed: enabled ? onProject : null),
        _ActionButton(
            icon: Icons.account_balance_wallet,
            label: 'Charging',
            onPressed: enabled ? onCharging : null),
        _ActionButton(
            icon: Icons.compare_arrows,
            label: 'Account Pair',
            onPressed: enabled ? onAcctPair : null),
        _ActionButton(
            icon: Icons.beach_access,
            label: 'Unaccounted',
            onPressed: enabled ? onUnaccounted : null),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _ActionButton(
      {required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.terracotta,
        foregroundColor: AppColors.textOnPrimary,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader(this.title, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.textSecondary),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class _TaLogTile extends StatelessWidget {
  final MandaysTaLog log;
  const _TaLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    final qty = NumberFormat('#,##0.##');
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.xs),
      padding: const EdgeInsets.all(AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Text(
              log.logType.isEmpty ? '—' : log.logType,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              '${log.timeIn.isEmpty ? '—' : log.timeIn}  →  '
              '${log.timeOut.isEmpty ? '—' : log.timeOut}'
              '${log.minutes != null ? '   (${log.minutes} min)' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (log.isHoliday)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.celebration,
                  size: 14, color: AppColors.warning),
            ),
          if (log.leaveType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(log.leaveType,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning)),
            ),
          Text(qty.format(log.mandayQty),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MatchingTile extends StatelessWidget {
  final MandaysMatchingDoc doc;
  final int employeeId;
  final String employeeName;
  final VoidCallback onProcess;
  final VoidCallback onCancel;
  const _MatchingTile({
    required this.doc,
    required this.employeeId,
    required this.employeeName,
    required this.onProcess,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final qty = NumberFormat('#,##0.##');
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final typeLabel = switch (doc.matchingType) {
      'PROJECT' => 'Project',
      'CHARGING' => 'Charging',
      'ACCOUNTPAIR' => 'Account Pair',
      'UNACCOUNTED' => 'Unaccounted',
      _ => doc.matchingType,
    };
    final dest = doc.matchingType == 'PROJECT'
        ? '${doc.projectName} · ${doc.stageName}'
        : doc.chargeTo;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
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
                  doc.documentNo.isEmpty
                      ? '#${doc.matchingId}'
                      : doc.documentNo,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              _DocstatusPill(status: doc.docstatus),
            ],
          ),
          Text(typeLabel,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4)),
          if (dest.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(dest,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                  child: _MiniMetric(
                      label: 'Qty', value: qty.format(doc.matchedQty))),
              Expanded(
                child: _MiniMetric(
                  label: doc.matchingType == 'UNACCOUNTED'
                      ? 'Unaccounted'
                      : 'Accounted',
                  value: money.format(doc.matchingType == 'UNACCOUNTED'
                      ? doc.unaccountedSalary
                      : doc.accountedSalary),
                  emphasise: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              if (doc.isDraft)
                FilledButton.icon(
                  onPressed: onProcess,
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Process'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.textOnPrimary,
                      visualDensity: VisualDensity.compact),
                ),
              if (!doc.isCancelled) ...[
                const SizedBox(width: AppDimensions.sm),
                OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      visualDensity: VisualDensity.compact),
                ),
              ],
              // Acknowledge — only meaningful for unaccounted lines that have
              // actually been written (i.e., we have a line id). DR docs
              // technically expose the id too, but business-side process is to
              // sign AFTER processing, so we only surface it once docstatus=PR.
              if (doc.matchingType == 'UNACCOUNTED' &&
                  doc.isProcessed &&
                  doc.unaccountedLineId != null) ...[
                const SizedBox(width: AppDimensions.sm),
                OutlinedButton.icon(
                  onPressed: () {
                    GoRouter.of(context).push(
                      '/projects/mandays-matching/unaccounted-ack',
                      extra: <String, dynamic>{
                        'unaccounted_line_id': doc.unaccountedLineId,
                        's_bpartner_employee_id': employeeId,
                        'amt_unaccounted_salary': doc.unaccountedSalary,
                        'employee_name': employeeName,
                      },
                    );
                  },
                  icon: const Icon(Icons.draw, size: 14),
                  label: const Text('Acknowledge'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      visualDensity: VisualDensity.compact),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DocstatusPill extends StatelessWidget {
  final String status;
  const _DocstatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final (fg, bg, label) = switch (status) {
      'PR' => (AppColors.success, AppColors.successLight, 'Processed'),
      'DR' => (AppColors.warning, AppColors.warningLight, 'Draft'),
      'CA' => (AppColors.error, AppColors.errorLight, 'Cancelled'),
      _ => (AppColors.textSecondary, AppColors.surfaceVariant,
          status.isEmpty ? '—' : status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.5)),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;
  const _MiniMetric(
      {required this.label, required this.value, this.emphasise = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
                color: emphasise
                    ? AppColors.primary
                    : AppColors.textPrimary)),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppDimensions.sm),
        decoration: BoxDecoration(
          color: AppColors.errorLight,
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        child: Text(message,
            style: const TextStyle(color: AppColors.error, fontSize: 12)),
      );
}

class _EmptyBox extends StatelessWidget {
  final String message;
  const _EmptyBox({required this.message});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppDimensions.md),
        alignment: Alignment.center,
        child: Text(message,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      );
}
