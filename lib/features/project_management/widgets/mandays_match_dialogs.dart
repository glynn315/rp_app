import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/project_management_models.dart';
import '../services/project_management_api.dart';
import 'mandays_pickers.dart';

/// Shared context every matching dialog needs.
class MandaysDialogContext {
  final int employeeId;
  final DateTime dateSchedule;
  final double availableMandays;
  final MandaysDer der;
  final List<int> taLogIds;
  final ProjectManagementApi api;
  final String? token;

  const MandaysDialogContext({
    required this.employeeId,
    required this.dateSchedule,
    required this.availableMandays,
    required this.der,
    required this.taLogIds,
    required this.api,
    required this.token,
  });
}

/// Returns true if a save succeeded so the caller can refresh.
Future<bool> showProjectMatchDialog(
        BuildContext context, MandaysDialogContext ctx) =>
    _showMatchDialog(context, ctx, _ProjectDialog(ctx: ctx));

Future<bool> showChargingMatchDialog(
        BuildContext context, MandaysDialogContext ctx) =>
    _showMatchDialog(context, ctx, _ChargingDialog(ctx: ctx));

Future<bool> showAcctPairMatchDialog(
        BuildContext context, MandaysDialogContext ctx) =>
    _showMatchDialog(context, ctx, _AcctPairDialog(ctx: ctx));

Future<bool> showUnaccountedMatchDialog(
        BuildContext context, MandaysDialogContext ctx) =>
    _showMatchDialog(context, ctx, _UnaccountedDialog(ctx: ctx));

Future<bool> _showMatchDialog(
    BuildContext context, MandaysDialogContext ctx, Widget child) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(child: child),
  );
  return ok == true;
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppDimensions.sm),
        child: Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.terracotta),
        ),
      );
}

/// Small helper: a labelled value row with monospace-ish trailing number.
class _LabeledValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;
  const _LabeledValue(
      {required this.label, required this.value, this.emphasise = false});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 13,
              fontWeight: emphasise ? FontWeight.w700 : FontWeight.w500,
              color: emphasise ? AppColors.primary : AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// Header & footer shared across all four type-specific dialogs.
class _DialogShell extends StatelessWidget {
  final String title;
  final String docDraftLabel;
  final MandaysDialogContext ctx;
  final double matchedQty;
  final String? saveError;
  final bool saving;
  final List<Widget> body;
  final VoidCallback? onSave;
  final VoidCallback onCancel;

  const _DialogShell({
    required this.title,
    required this.docDraftLabel,
    required this.ctx,
    required this.matchedQty,
    required this.saveError,
    required this.saving,
    required this.body,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    final qty = NumberFormat('#,##0.##');
    final accountedSalary = matchedQty * ctx.der.der;
    final remainingQty =
        (ctx.availableMandays - matchedQty).clamp(0, ctx.availableMandays);

    return SizedBox(
      width: 640,
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.md),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: AppDimensions.sm),
              _SectionTitle('Available'),
              _LabeledValue(
                  label: 'Available Mandays',
                  value: qty.format(ctx.availableMandays)),
              _LabeledValue(
                  label: 'Daily Equivalent Rate',
                  value: money.format(ctx.der.der)),
              ...body,
              const Divider(height: AppDimensions.lg),
              _SectionTitle('Summary'),
              _LabeledValue(
                  label: 'Document No (draft)', value: docDraftLabel),
              _LabeledValue(
                  label: 'Match Mandays', value: qty.format(matchedQty)),
              _LabeledValue(
                  label: 'Accounted Salary',
                  value: money.format(accountedSalary),
                  emphasise: true),
              _LabeledValue(
                  label: 'Remaining Mandays Qty',
                  value: qty.format(remainingQty)),
              if (saveError != null) ...[
                const SizedBox(height: AppDimensions.sm),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(saveError!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12)),
                ),
              ],
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  TextButton(
                    onPressed: saving ? null : onCancel,
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: saving ? null : onSave,
                    icon: saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textOnPrimary))
                        : const Icon(Icons.save, size: 16),
                    label: const Text('Save (Prematch)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PROJECT dialog
// ---------------------------------------------------------------------------

class _ProjectDialog extends StatefulWidget {
  final MandaysDialogContext ctx;
  const _ProjectDialog({required this.ctx});
  @override
  State<_ProjectDialog> createState() => _ProjectDialogState();
}

class _ProjectDialogState extends State<_ProjectDialog> {
  MandaysStagePickerRow? _stage;
  final _qtyCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _explanationCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;

  Future<void> _pickStage() async {
    final picked = await pickProjectStage(
      context,
      widget.ctx.api,
      token: widget.ctx.token,
    );
    if (picked != null && mounted) setState(() => _stage = picked);
  }

  Future<void> _save() async {
    if (_stage == null) {
      setState(() => _saveError = 'Select a project / stage first.');
      return;
    }
    if (_qty <= 0 || _qty > widget.ctx.availableMandays) {
      setState(() => _saveError = 'Match quantity must be between 0 and '
          '${widget.ctx.availableMandays.toStringAsFixed(2)}.');
      return;
    }
    final accountedSalary = _qty * widget.ctx.der.der;
    if (accountedSalary > _stage!.totalLmcRemaining) {
      setState(() => _saveError =
          'Accounted salary (₱${accountedSalary.toStringAsFixed(2)}) '
          'exceeds remaining LMC budget '
          '(₱${_stage!.totalLmcRemaining.toStringAsFixed(2)}).');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.ctx.api.mandaysCreateProject(
        employeeId: widget.ctx.employeeId,
        dateSchedule: widget.ctx.dateSchedule,
        stageId: _stage!.stageId,
        matchedMandaysQty: _qty,
        taLogIds: widget.ctx.taLogIds,
        explanation: _explanationCtrl.text.trim(),
        token: widget.ctx.token,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_PH', symbol: '₱');
    return _DialogShell(
      title: 'Project Matching',
      docDraftLabel: 'MDM-PRJ (auto-generated on save)',
      ctx: widget.ctx,
      matchedQty: _qty,
      saveError: _saveError,
      saving: _saving,
      onCancel: () => Navigator.of(context).pop(false),
      onSave: _save,
      body: [
        _SectionTitle('Project Information'),
        InkWell(
          onTap: _pickStage,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Project · Scope · Stage [F4]',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            child: Text(
              _stage == null
                  ? 'Tap to select'
                  : '${_stage!.projectName} — ${_stage!.scopeName} / ${_stage!.stageName}',
              style: TextStyle(
                  color: _stage == null
                      ? AppColors.textMuted
                      : AppColors.textPrimary),
            ),
          ),
        ),
        if (_stage != null) ...[
          const SizedBox(height: AppDimensions.xs),
          _LabeledValue(
              label: 'LMC Budget Total',
              value: money.format(_stage!.totalLmcBudget)),
          _LabeledValue(
              label: 'LMC Remaining',
              value: money.format(_stage!.totalLmcRemaining),
              emphasise: true),
        ],
        _SectionTitle('Allocation'),
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText:
                'Match Mandays (max ${widget.ctx.availableMandays.toStringAsFixed(2)})',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppDimensions.sm),
        TextField(
          controller: _explanationCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Explanation (optional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CHARGING dialog
// ---------------------------------------------------------------------------

class _ChargingDialog extends StatefulWidget {
  final MandaysDialogContext ctx;
  const _ChargingDialog({required this.ctx});
  @override
  State<_ChargingDialog> createState() => _ChargingDialogState();
}

class _ChargingDialogState extends State<_ChargingDialog> {
  MandaysBpartnerPickerRow? _bp;
  MandaysAcctPairPickerRow? _acctPair;
  final _qtyCtrl = TextEditingController();
  final _explanationCtrl = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _explanationCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;

  Future<void> _save() async {
    if (_bp == null || _acctPair == null) {
      setState(() => _saveError = 'Pick a Business Partner and Account Pair.');
      return;
    }
    if (_qty <= 0 || _qty > widget.ctx.availableMandays) {
      setState(() => _saveError = 'Match quantity out of range.');
      return;
    }
    if (_explanationCtrl.text.trim().isEmpty) {
      setState(() => _saveError = 'Explanation is required for Charging.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.ctx.api.mandaysCreateCharging(
        employeeId: widget.ctx.employeeId,
        dateSchedule: widget.ctx.dateSchedule,
        bpartnerId: _bp!.bpartnerId,
        acctPairId: _acctPair!.subacctId,
        matchedMandaysQty: _qty,
        taLogIds: widget.ctx.taLogIds,
        explanation: _explanationCtrl.text.trim(),
        token: widget.ctx.token,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'Charging Matching',
      docDraftLabel: 'MDM-CHRG (auto-generated on save)',
      ctx: widget.ctx,
      matchedQty: _qty,
      saveError: _saveError,
      saving: _saving,
      onCancel: () => Navigator.of(context).pop(false),
      onSave: _save,
      body: [
        _SectionTitle('Accountable Business Partner'),
        _PickerField(
          label: 'Business Unit / Person [F4]',
          value: _bp?.name,
          onTap: () async {
            final r = await pickBpartner(context, widget.ctx.api,
                token: widget.ctx.token);
            if (r != null && mounted) setState(() => _bp = r);
          },
        ),
        const SizedBox(height: AppDimensions.sm),
        _PickerField(
          label: 'Account Pair [F4]',
          value: _acctPair?.displayLabel,
          onTap: () async {
            final r = await pickAcctPair(context, widget.ctx.api,
                token: widget.ctx.token);
            if (r != null && mounted) setState(() => _acctPair = r);
          },
        ),
        _SectionTitle('Allocation'),
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText:
                'Match Mandays (max ${widget.ctx.availableMandays.toStringAsFixed(2)})',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppDimensions.sm),
        TextField(
          controller: _explanationCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Explanation (required)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// ACCOUNT PAIR dialog
// ---------------------------------------------------------------------------

class _AcctPairDialog extends StatefulWidget {
  final MandaysDialogContext ctx;
  const _AcctPairDialog({required this.ctx});
  @override
  State<_AcctPairDialog> createState() => _AcctPairDialogState();
}

class _AcctPairDialogState extends State<_AcctPairDialog> {
  MandaysBpartnerPickerRow? _bp;
  MandaysAcctPairPickerRow? _acctPair;
  final _qtyCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;

  Future<void> _save() async {
    if (_bp == null || _acctPair == null) {
      setState(() => _saveError = 'Pick a Business Partner and Account Pair.');
      return;
    }
    if (_qty <= 0 || _qty > widget.ctx.availableMandays) {
      setState(() => _saveError = 'Match quantity out of range.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.ctx.api.mandaysCreateAcctpair(
        employeeId: widget.ctx.employeeId,
        dateSchedule: widget.ctx.dateSchedule,
        bpartnerId: _bp!.bpartnerId,
        acctPairId: _acctPair!.subacctId,
        matchedMandaysQty: _qty,
        taLogIds: widget.ctx.taLogIds,
        description: _descCtrl.text.trim(),
        token: widget.ctx.token,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'Account Pair Matching',
      docDraftLabel: 'MDM-ACPR (auto-generated on save)',
      ctx: widget.ctx,
      matchedQty: _qty,
      saveError: _saveError,
      saving: _saving,
      onCancel: () => Navigator.of(context).pop(false),
      onSave: _save,
      body: [
        _SectionTitle('Accountable Business Partner'),
        _PickerField(
          label: 'Business Partner [F4]',
          value: _bp?.name,
          onTap: () async {
            final r = await pickBpartner(context, widget.ctx.api,
                token: widget.ctx.token);
            if (r != null && mounted) setState(() => _bp = r);
          },
        ),
        const SizedBox(height: AppDimensions.sm),
        _PickerField(
          label: 'Account Pair [F4]',
          value: _acctPair?.displayLabel,
          onTap: () async {
            final r = await pickAcctPair(context, widget.ctx.api,
                token: widget.ctx.token);
            if (r != null && mounted) setState(() => _acctPair = r);
          },
        ),
        _SectionTitle('Allocation'),
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText:
                'Match Mandays (max ${widget.ctx.availableMandays.toStringAsFixed(2)})',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppDimensions.sm),
        TextField(
          controller: _descCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// UNACCOUNTED dialog
// ---------------------------------------------------------------------------

class _UnaccountedDialog extends StatefulWidget {
  final MandaysDialogContext ctx;
  const _UnaccountedDialog({required this.ctx});
  @override
  State<_UnaccountedDialog> createState() => _UnaccountedDialogState();
}

class _UnaccountedDialogState extends State<_UnaccountedDialog> {
  MandaysBpartnerPickerRow? _bp;
  final _qtyCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  bool _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;

  Future<void> _save() async {
    if (_bp == null) {
      setState(() => _saveError = 'Pick a Business Partner.');
      return;
    }
    if (_qty <= 0 || _qty > widget.ctx.availableMandays) {
      setState(() => _saveError = 'Match quantity out of range.');
      return;
    }
    if (_remarksCtrl.text.trim().isEmpty) {
      setState(() => _saveError = 'Remarks are required for Unaccounted.');
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.ctx.api.mandaysCreateUnaccounted(
        employeeId: widget.ctx.employeeId,
        dateSchedule: widget.ctx.dateSchedule,
        bpartnerId: _bp!.bpartnerId,
        matchedMandaysQty: _qty,
        taLogIds: widget.ctx.taLogIds,
        remarks: _remarksCtrl.text.trim(),
        token: widget.ctx.token,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      title: 'Unaccounted Matching',
      docDraftLabel: 'MDM-UNCTD (auto-generated on save)',
      ctx: widget.ctx,
      matchedQty: _qty,
      saveError: _saveError,
      saving: _saving,
      onCancel: () => Navigator.of(context).pop(false),
      onSave: _save,
      body: [
        _SectionTitle('Accountable Business Partner'),
        _PickerField(
          label: 'Business Partner [F4]',
          value: _bp?.name,
          onTap: () async {
            final r = await pickBpartner(context, widget.ctx.api,
                token: widget.ctx.token);
            if (r != null && mounted) setState(() => _bp = r);
          },
        ),
        _SectionTitle('Allocation'),
        TextField(
          controller: _qtyCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            labelText:
                'Match Mandays (max ${widget.ctx.availableMandays.toStringAsFixed(2)})',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppDimensions.sm),
        TextField(
          controller: _remarksCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Remarks (required — VL/SIL/BL etc.)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(
          value == null || value!.isEmpty ? 'Tap to select' : value!,
          style: TextStyle(
              color: value == null || value!.isEmpty
                  ? AppColors.textMuted
                  : AppColors.textPrimary),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
