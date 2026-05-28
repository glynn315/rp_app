import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/consumption_models.dart';
import '../providers/consumption_provider.dart';

/// Side-by-side reconciliation of a posted consumption session against the
/// ERP rows it produced. Mirrors the web mobile `ConsumptionErpVerifyScreen`:
///  - summary chips for each match status
///  - ERP doc header (when posted)
///  - per-line comparison cards (Local vs ERP)
class ConsumptionErpVerifyScreen extends ConsumerWidget {
  final int sessionId;
  const ConsumptionErpVerifyScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(consumptionErpVerifyProvider(sessionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('ERP verify'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(consumptionErpVerifyProvider(sessionId));
          await ref.read(consumptionErpVerifyProvider(sessionId).future);
        },
        child: async.when(
          loading: () => const _CenterFill(
            child: CircularProgressIndicator(),
          ),
          error: (err, _) => _CenterFill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Text(
                err.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
          data: (r) => _Content(result: r),
        ),
      ),
    );
  }
}

class _CenterFill extends StatelessWidget {
  final Widget child;
  const _CenterFill({required this.child});
  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Center(child: child),
        ],
      );
}

class _Content extends StatelessWidget {
  final ErpVerifyResult result;
  const _Content({required this.result});

  @override
  Widget build(BuildContext context) {
    final summaryChips = _summaryChips(result.summary);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.md,
        AppDimensions.xl,
      ),
      children: [
        // Header card — session id, ERP doc info, posted-by.
        Container(
          padding: const EdgeInsets.all(AppDimensions.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.neutral100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session #${result.sessionId} · ${result.sessionStatus}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (result.erpDocumentNo != null) ...[
                const SizedBox(height: 4),
                Text(
                  'ERP doc ${result.erpDocumentNo}'
                  '${result.erpConsumptionId != null ? ' · ID ${result.erpConsumptionId}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              if (result.postedBy != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Posted by ${result.postedBy}'
                  '${result.postedAt != null ? ' · ${_fmtDate(result.postedAt!)}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (summaryChips.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.sm),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: summaryChips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) => summaryChips[i],
            ),
          ),
        ],
        const SizedBox(height: AppDimensions.md),
        if (result.lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'No lines to verify.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...result.lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                child: _LineCard(line: l),
              )),
      ],
    );
  }

  static List<Widget> _summaryChips(ErpVerifySummary s) {
    final entries = <(String, int, _Tone)>[
      ('Matched', s.matched, _Tone.success),
      ('Qty diff', s.qtyMismatch, _Tone.warning),
      ('Missing on ERP', s.missingOnErp, _Tone.danger),
      ('Missing locally', s.missingLocally, _Tone.danger),
      ('Not posted', s.notPosted, _Tone.neutral),
    ].where((e) => e.$2 > 0).toList();
    return entries
        .map((e) => _SummaryChip(label: e.$1, count: e.$2, tone: e.$3))
        .toList();
  }
}

class _LineCard extends StatelessWidget {
  final ErpVerifyLine line;
  const _LineCard({required this.line});

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(line.matchStatus);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: _toneBorder(tone)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.md,
              AppDimensions.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.itemDescription ?? 'SKU ${line.skuId ?? '—'}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (line.unit != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Unit · ${line.unit}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(
                  label: _labelFor(line.matchStatus),
                  tone: tone,
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.neutral100),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Side(
                    label: 'Local',
                    value: line.local != null
                        ? _fmtQty(line.local!.consumedQty)
                        : '—',
                    sub: line.local != null
                        ? 'Over ${_fmtQty(line.local!.overQty)}'
                        : null,
                  ),
                ),
                Container(width: 1, color: AppColors.neutral100),
                Expanded(
                  child: _Side(
                    label: 'ERP',
                    value:
                        line.erp != null ? _fmtQty(line.erp!.qty) : '—',
                    sub: line.erp != null
                        ? 'Cost ${_fmtMoney(line.erp!.cost)} · Amt ${_fmtMoney(line.erp!.amtTotal)}'
                        : null,
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

class _Side extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  const _Side({required this.label, required this.value, this.sub});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md,
        vertical: AppDimensions.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final _Tone tone;
  const _SummaryChip({
    required this.label,
    required this.count,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = _toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label · $count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final _Tone tone;
  const _StatusChip({required this.label, required this.tone});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = _toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }
}

enum _Tone { success, warning, danger, neutral }

_Tone _toneFor(String matchStatus) => switch (matchStatus) {
      'matched' => _Tone.success,
      'qty_mismatch' => _Tone.warning,
      'missing_on_erp' => _Tone.danger,
      'missing_locally' => _Tone.danger,
      _ => _Tone.neutral,
    };

String _labelFor(String matchStatus) => switch (matchStatus) {
      'matched' => 'MATCHED',
      'qty_mismatch' => 'QTY DIFF',
      'missing_on_erp' => 'MISSING ON ERP',
      'missing_locally' => 'MISSING LOCALLY',
      _ => 'NOT POSTED',
    };

(Color, Color) _toneColors(_Tone t) => switch (t) {
      _Tone.success => (AppColors.successLight, AppColors.success),
      _Tone.warning => (AppColors.warningLight, AppColors.warning),
      _Tone.danger => (AppColors.errorLight, AppColors.error),
      _Tone.neutral => (AppColors.neutral100, AppColors.textMuted),
    };

Color _toneBorder(_Tone t) => switch (t) {
      _Tone.success => AppColors.success.withValues(alpha: 0.3),
      _Tone.warning => AppColors.warning.withValues(alpha: 0.3),
      _Tone.danger => AppColors.error.withValues(alpha: 0.3),
      _Tone.neutral => AppColors.neutral100,
    };

String _fmtQty(double v) {
  if (!v.isFinite) return '0';
  return v == v.truncateToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2);
}

String _fmtMoney(double v) {
  if (!v.isFinite) return '0.00';
  return v.toStringAsFixed(2);
}

String _fmtDate(DateTime d) => DateFormat('MMM d, y · h:mm a').format(d);
