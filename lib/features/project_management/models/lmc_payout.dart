part of 'project_management_models.dart';

/// One LMC Payout header — per project-scope per coverage period.
class LmcPayout {
  final int? payoutId;
  final String documentNo;
  final String docstatus;
  final DateTime? dateTrans;
  final DateTime? dateGl;
  final DateTime? dateCoverageFrom;
  final DateTime? dateCoverageTo;
  final double workaccompPercentage;
  final bool isClosed;
  final double amtTotalPayout;
  final double amtTotalPayoutTax;
  final double amtTotalPayoutWtax;
  final double amtTotalPayoutNet;
  final int? projectId;
  final String projectName;
  final String projectDocumentNo;
  final int? scopeId;
  final String scopeName;
  final int? sBpartnerId;
  final String payeeName;

  bool get isProcessed => docstatus == 'PR';

  const LmcPayout({
    required this.payoutId,
    required this.documentNo,
    required this.docstatus,
    required this.dateTrans,
    required this.dateGl,
    required this.dateCoverageFrom,
    required this.dateCoverageTo,
    required this.workaccompPercentage,
    required this.isClosed,
    required this.amtTotalPayout,
    required this.amtTotalPayoutTax,
    required this.amtTotalPayoutWtax,
    required this.amtTotalPayoutNet,
    required this.projectId,
    required this.projectName,
    required this.projectDocumentNo,
    required this.scopeId,
    required this.scopeName,
    required this.sBpartnerId,
    required this.payeeName,
  });

  factory LmcPayout.fromJson(Map<String, dynamic> j) => LmcPayout(
        payoutId: _toIntOrNull(j['payout_id']),
        documentNo: _toStr(j['documentno']),
        docstatus: _toStr(j['docstatus']),
        dateTrans: _parseDate(j['date_trans']),
        dateGl: _parseDate(j['date_gl']),
        dateCoverageFrom: _parseDate(j['date_coverage_from']),
        dateCoverageTo: _parseDate(j['date_coverage_to']),
        workaccompPercentage: _toDouble(j['workaccomp_percentage']),
        isClosed: j['is_closed'] == true ||
            j['is_closed'] == 1 ||
            _toStr(j['is_closed']) == '1',
        amtTotalPayout: _toDouble(j['amt_total_payout']),
        amtTotalPayoutTax: _toDouble(j['amt_total_payout_tax']),
        amtTotalPayoutWtax: _toDouble(j['amt_total_payout_wtax']),
        amtTotalPayoutNet: _toDouble(j['amt_total_payout_net']),
        projectId: _toIntOrNull(j['project_id']),
        projectName: _toStr(j['project_name']),
        projectDocumentNo: _toStr(j['project_documentno']),
        scopeId: _toIntOrNull(j['scope_id']),
        scopeName: _toStr(j['scope_name']),
        sBpartnerId: _toIntOrNull(j['s_bpartner_id']),
        payeeName: _toStr(j['payee_name']),
      );
}

/// One line within an LMC Payout — typically one per project-scope-stage.
class LmcPayoutLine {
  final int? lineId;
  final int? payoutId;
  final int? lineNo;
  final String description;
  final String unit;
  final double qty;
  final double cost;
  final double taxPercentage;
  final double amt;
  final double amtTax;
  final double amtWtax;
  final double amtNet;
  final double amount;
  final double stagePercentage;
  final int? stageId;
  final String stageName;

  const LmcPayoutLine({
    required this.lineId,
    required this.payoutId,
    required this.lineNo,
    required this.description,
    required this.unit,
    required this.qty,
    required this.cost,
    required this.taxPercentage,
    required this.amt,
    required this.amtTax,
    required this.amtWtax,
    required this.amtNet,
    required this.amount,
    required this.stagePercentage,
    required this.stageId,
    required this.stageName,
  });

  factory LmcPayoutLine.fromJson(Map<String, dynamic> j) => LmcPayoutLine(
        lineId: _toIntOrNull(j['line_id']),
        payoutId: _toIntOrNull(j['payout_id']),
        lineNo: _toIntOrNull(j['line_no']),
        description: _toStr(j['description']),
        unit: _toStr(j['unit']),
        qty: _toDouble(j['qty']),
        cost: _toDouble(j['cost']),
        taxPercentage: _toDouble(j['tax_percentage']),
        amt: _toDouble(j['amt']),
        amtTax: _toDouble(j['amt_tax']),
        amtWtax: _toDouble(j['amt_wtax']),
        amtNet: _toDouble(j['amt_net']),
        amount: _toDouble(j['amount']),
        stagePercentage: _toDouble(j['stage_percentage']),
        stageId: _toIntOrNull(j['stage_id']),
        stageName: _toStr(j['stage_name']),
      );
}
