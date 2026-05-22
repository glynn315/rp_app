import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/project_management_models.dart';
import '../providers/project_management_provider.dart';

/// Captures an employee's signature against an unaccounted-salary line and
/// posts a [MandaysUnacctdSalaryAck] to the backend. The signature is sent
/// as a multipart PNG and stored on the public disk; on success we pop
/// `true` so the caller can refresh its ack list.
///
/// Arguments come through [ModalRoute] settings (so go_router can pass them
/// without a custom transition) but the screen also accepts them directly
/// for unit testability.
class MandaysUnacctdAckScreen extends ConsumerStatefulWidget {
  final int unaccountedLineId;
  /// The signed-in person identity that owns the ack row. Either this OR
  /// [sBpartnerEmployeeId] must be supplied; if only the employee id is
  /// provided the backend two-hops to resolve the person id.
  final int? bparPersonId;
  final int? sBpartnerEmployeeId;
  final double amtUnaccountedSalary;
  final String employeeName;

  const MandaysUnacctdAckScreen({
    super.key,
    required this.unaccountedLineId,
    required this.amtUnaccountedSalary,
    required this.employeeName,
    this.bparPersonId,
    this.sBpartnerEmployeeId,
  }) : assert(bparPersonId != null || sBpartnerEmployeeId != null,
            'Provide bparPersonId or sBpartnerEmployeeId');

  @override
  ConsumerState<MandaysUnacctdAckScreen> createState() =>
      _MandaysUnacctdAckScreenState();
}

class _MandaysUnacctdAckScreenState
    extends ConsumerState<MandaysUnacctdAckScreen> {
  late final SignatureController _sig;
  DateTime _ackDate = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sig = SignatureController(
      penStrokeWidth: 2.2,
      penColor: AppColors.midnight,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _sig.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_sig.isEmpty) {
      setState(() => _error = 'Please sign in the pad before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final Uint8List? png = await _sig.toPngBytes();
      if (png == null || png.isEmpty) {
        throw Exception('Failed to render signature.');
      }
      final api = ref.read(projectManagementApiProvider);
      final auth = ref.read(authProvider);
      await api.createUnacctdAck(
        bparPersonId: widget.bparPersonId,
        sBpartnerEmployeeId: widget.sBpartnerEmployeeId,
        unaccountedLineId: widget.unaccountedLineId,
        amtUnaccountedSalary: widget.amtUnaccountedSalary,
        ackDate: _ackDate,
        signatureBytes: png,
        createdBy: auth.user?.name,
        token: auth.token,
      );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ackDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _ackDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
    final ymd = DateFormat('yyyy-MM-dd');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acknowledge Unaccounted Salary'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.pureWhite,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header card — what is the employee acknowledging?
              Container(
                padding: const EdgeInsets.all(AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.mist,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.employeeName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      'Acknowledging ${money.format(widget.amtUnaccountedSalary)} '
                      'as unaccounted salary',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              // Date row
              InkWell(
                onTap: _saving ? null : _pickDate,
                borderRadius:
                    BorderRadius.circular(AppDimensions.radiusSm),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Acknowledgement date',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  child: Text(ymd.format(_ackDate)),
                ),
              ),
              const SizedBox(height: AppDimensions.md),

              // Signature pad — flex so it expands but stays bounded so
              // toPngBytes() doesn't render an empty surface on small phones.
              const Text('Signature',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.stone),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                    child: Signature(
                      controller: _sig,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : () => _sig.clear(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear'),
                  ),
                  const Spacer(),
                  Text(
                    'Sign with finger or stylus',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.stone),
                  ),
                ],
              ),

              if (_error != null) ...[
                const SizedBox(height: AppDimensions.sm),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 12)),
                ),
              ],

              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save acknowledgement'),
                    ),
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
