import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/app_back_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/ipr_models.dart';
import '../services/ipr_api.dart';
import 'ipr_status_pill.dart';

/// One IPR with its lines. Draft IPRs can be posted; individual lines can be
/// closed (with an explanation) or have their qty edited. Mirrors the web
/// mobile IprDetailScreen.
class IprDetailScreen extends ConsumerStatefulWidget {
  final int iprId;
  const IprDetailScreen({super.key, required this.iprId});

  @override
  ConsumerState<IprDetailScreen> createState() => _IprDetailScreenState();
}

class _IprDetailScreenState extends ConsumerState<IprDetailScreen> {
  IprDetail? _detail;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _token => ref.read(authProvider).token;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ref.read(iprApiProvider).getById(widget.iprId, token: _token);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _apply(IprDetail d) => setState(() => _detail = d);

  Future<void> _post() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post IPR?'),
        content: const Text(
            'Posting finalises the requisition (DR → PR). This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Post')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final d = await ref.read(iprApiProvider).post(
            widget.iprId,
            postedBy: ref.read(authProvider).user?.name,
            token: _token,
          );
      if (!mounted) return;
      _apply(d);
      _snack('IPR posted.', AppColors.success);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editQty(IprLine line) async {
    final ctl = TextEditingController(text: _fmt(line.qty));
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit qty — ${line.itemName ?? line.skucode ?? 'line'}'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(labelText: 'Quantity'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctl.text.trim()) ?? line.qty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => _busy = true);
    try {
      final d = await ref
          .read(iprApiProvider)
          .updateLineQty(widget.iprId, line.id, result, token: _token);
      if (!mounted) return;
      _apply(d);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeLine(IprLine line) async {
    final expCtl = TextEditingController(text: line.explanation ?? '');
    final remCtl = TextEditingController(text: line.remarks ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close line'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: expCtl,
              decoration: const InputDecoration(labelText: 'Explanation *'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: remCtl,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Close line')),
        ],
      ),
    );
    if (ok != true) return;
    if (expCtl.text.trim().isEmpty) {
      _snack('Explanation is required to close a line.', AppColors.error);
      return;
    }
    setState(() => _busy = true);
    try {
      final d = await ref.read(iprApiProvider).closeLine(
            widget.iprId,
            line.id,
            explanation: expCtl.text.trim(),
            remarks: remCtl.text.trim().isEmpty ? null : remCtl.text.trim(),
            token: _token,
          );
      if (!mounted) return;
      _apply(d);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message, AppColors.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: c),
    );
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(d?.ipr.documentno ?? 'IPR detail'),
        actions: [
          if (d != null)
            Padding(
              padding: const EdgeInsets.only(right: AppDimensions.md),
              child: Center(child: IprStatusPill(status: d.ipr.docstatus)),
            ),
        ],
      ),
      bottomNavigationBar: (d != null && !d.ipr.isPosted)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.md),
                child: FilledButton.icon(
                  onPressed: _busy ? null : _post,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                  label: const Text('Post IPR'),
                ),
              ),
            )
          : null,
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error)),
              ),
            )
          : _loading || d == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  children: [
                    if (d.ipr.projectName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                        child: Text(d.ipr.projectName!,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary)),
                      ),
                    for (final line in d.lines)
                      _LineCard(
                        line: line,
                        readOnly: d.ipr.isPosted || _busy,
                        fmt: _fmt,
                        onEditQty: () => _editQty(line),
                        onClose: () => _closeLine(line),
                      ),
                  ],
                ),
    );
  }
}

class _LineCard extends StatelessWidget {
  final IprLine line;
  final bool readOnly;
  final String Function(double) fmt;
  final VoidCallback onEditQty;
  final VoidCallback onClose;

  const _LineCard({
    required this.line,
    required this.readOnly,
    required this.fmt,
    required this.onEditQty,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: line.closed ? AppColors.neutral100 : AppColors.neutral100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  line.itemName ?? line.skucode ?? 'Item',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration:
                        line.closed ? TextDecoration.lineThrough : null,
                    color: line.closed
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              if (line.closed)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.lock_outline,
                      size: 16, color: AppColors.textMuted),
                ),
            ],
          ),
          if (line.skucode != null) ...[
            const SizedBox(height: 2),
            Text(line.skucode!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppDimensions.sm),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _stat('Req qty', '${fmt(line.qty)} ${line.unit ?? ''}'),
              if (line.qtyPo != null) _stat('PO', fmt(line.qtyPo!)),
              if (line.qtyOnHand != null)
                _stat('On hand', fmt(line.qtyOnHand!)),
            ],
          ),
          if (line.explanation != null && line.explanation!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reason: ${line.explanation}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ],
          if (!readOnly && !line.closed) ...[
            const SizedBox(height: AppDimensions.sm),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onEditQty,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Qty'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: onClose,
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Close'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text(value,
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
