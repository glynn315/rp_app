part of 'project_management_models.dart';

/// One row in the Pending Matching list — aggregated TA-log totals for an
/// (employee, schedule date) pair, with the derived workflow status.
class MandaysPendingRow {
  final int employeeId;
  final DateTime? dateSchedule;
  final String firstname;
  final String lastname;
  final String employeeNo;
  final double totalMandays;
  final double matchedMandays;
  final double remainingMandays;
  final String aggregateStatus;

  const MandaysPendingRow({
    required this.employeeId,
    required this.dateSchedule,
    required this.firstname,
    required this.lastname,
    required this.employeeNo,
    required this.totalMandays,
    required this.matchedMandays,
    required this.remainingMandays,
    required this.aggregateStatus,
  });

  String get fullName {
    final parts = [firstname, lastname].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? (employeeNo.isEmpty ? '—' : employeeNo) : parts.join(' ');
  }

  factory MandaysPendingRow.fromJson(Map<String, dynamic> j) =>
      MandaysPendingRow(
        employeeId: _toIntOrNull(j['employee_id']) ?? 0,
        dateSchedule: _parseDate(j['date_schedule']),
        firstname: _toStr(j['firstname']),
        lastname: _toStr(j['lastname']),
        employeeNo: _toStr(j['employee_no']),
        totalMandays: _toDouble(j['total_mandays']),
        matchedMandays: _toDouble(j['matched_mandays']),
        remainingMandays: _toDouble(j['remaining_mandays']),
        aggregateStatus: _toStr(j['aggregate_status']).toUpperCase(),
      );
}

/// Single TA-log row pulled from `wip_t_mandays_matching_ta_logs`.
class MandaysTaLog {
  final int talId;
  final DateTime? dateSchedule;
  final String logType;
  final String timeIn;
  final String timeOut;
  final int? minutes;
  final double mandayQty;
  final bool isHoliday;
  final String leaveType;
  final DateTime? datePulled;

  const MandaysTaLog({
    required this.talId,
    required this.dateSchedule,
    required this.logType,
    required this.timeIn,
    required this.timeOut,
    required this.minutes,
    required this.mandayQty,
    required this.isHoliday,
    required this.leaveType,
    required this.datePulled,
  });

  factory MandaysTaLog.fromJson(Map<String, dynamic> j) => MandaysTaLog(
        talId: _toIntOrNull(j['tal_id']) ?? 0,
        dateSchedule: _parseDate(j['date_schedule']),
        logType: _toStr(j['log_type']),
        timeIn: _toStr(j['time_in']),
        timeOut: _toStr(j['time_out']),
        minutes: _toIntOrNull(j['minutes']),
        mandayQty: _toDouble(j['manday_qty']),
        isHoliday: (_toIntOrNull(j['is_holiday']) ?? 0) == 1,
        leaveType: _toStr(j['leave_type']),
        datePulled: _parseDate(j['date_pulled']),
      );
}

/// Existing matching doc shown in the per-employee detail grid.
class MandaysMatchingDoc {
  final int matchingId;
  final String documentNo;
  final String docstatus;
  final String matchStatus;
  final String matchingType;
  final double matchedQty;
  final double der;
  final double accountedSalary;
  final double unaccountedSalary;
  final DateTime? datePrematched;
  final DateTime? dateMatched;
  final String projectName;
  final String stageName;
  final String chargeTo;
  /// Only populated for UNACCOUNTED matchings — the underlying
  /// `wip_t_mandays_matching_unaccounted_line_id`. Needed so the ack screen
  /// can bind a signature to the specific line.
  final int? unaccountedLineId;

  const MandaysMatchingDoc({
    required this.matchingId,
    required this.documentNo,
    required this.docstatus,
    required this.matchStatus,
    required this.matchingType,
    required this.matchedQty,
    required this.der,
    required this.accountedSalary,
    required this.unaccountedSalary,
    required this.datePrematched,
    required this.dateMatched,
    required this.projectName,
    required this.stageName,
    required this.chargeTo,
    required this.unaccountedLineId,
  });

  bool get isDraft => docstatus == 'DR';
  bool get isProcessed => docstatus == 'PR';
  bool get isCancelled => docstatus == 'CA';

  factory MandaysMatchingDoc.fromJson(Map<String, dynamic> j) =>
      MandaysMatchingDoc(
        matchingId: _toIntOrNull(j['matching_id']) ?? 0,
        documentNo: _toStr(j['documentno']),
        docstatus: _toStr(j['docstatus']),
        matchStatus: _toStr(j['match_status']),
        matchingType: _toStr(j['matching_type']),
        matchedQty: _toDouble(j['matched_qty']),
        der: _toDouble(j['der']),
        accountedSalary: _toDouble(j['accounted_salary']),
        unaccountedSalary: _toDouble(j['unaccounted_salary']),
        datePrematched: _parseDate(j['date_prematched']),
        dateMatched: _parseDate(j['date_matched']),
        projectName: _toStr(j['project_name']),
        stageName: _toStr(j['stage_name']),
        chargeTo: _toStr(j['charge_to']),
        unaccountedLineId: _toIntOrNull(j['unaccounted_line_id']),
      );
}

/// Daily Equivalent Rate snapshot for one employee.
class MandaysDer {
  final int? derId;
  final double der;
  final double basicRate;
  final double ecola;
  final double advanceIncentive;
  final double cashBond;
  final DateTime? datePulled;

  const MandaysDer({
    required this.derId,
    required this.der,
    required this.basicRate,
    required this.ecola,
    required this.advanceIncentive,
    required this.cashBond,
    required this.datePulled,
  });

  factory MandaysDer.fromJson(Map<String, dynamic> j) => MandaysDer(
        derId: _toIntOrNull(j['der_id']),
        der: _toDouble(j['der']),
        basicRate: _toDouble(j['basic_rate']),
        ecola: _toDouble(j['ecola']),
        advanceIncentive: _toDouble(j['advance_incentive']),
        cashBond: _toDouble(j['cash_bond']),
        datePulled: _parseDate(j['date_pulled']),
      );
}

/// One row in the Project-Scope-Stage picker dialog.
class MandaysStagePickerRow {
  final int projectId;
  final String projectDocumentNo;
  final String projectName;
  final int scopeId;
  final String scopeName;
  final int stageId;
  final String stageName;
  final double totalLmcBudget;
  final double totalLmcRemaining;

  const MandaysStagePickerRow({
    required this.projectId,
    required this.projectDocumentNo,
    required this.projectName,
    required this.scopeId,
    required this.scopeName,
    required this.stageId,
    required this.stageName,
    required this.totalLmcBudget,
    required this.totalLmcRemaining,
  });

  factory MandaysStagePickerRow.fromJson(Map<String, dynamic> j) =>
      MandaysStagePickerRow(
        projectId: _toIntOrNull(j['project_id']) ?? 0,
        projectDocumentNo: _toStr(j['project_documentno']),
        projectName: _toStr(j['project_name']),
        scopeId: _toIntOrNull(j['scope_id']) ?? 0,
        scopeName: _toStr(j['scope_name']),
        stageId: _toIntOrNull(j['stage_id']) ?? 0,
        stageName: _toStr(j['stage_name']),
        totalLmcBudget: _toDouble(j['total_lmc_budget']),
        totalLmcRemaining: _toDouble(j['total_lmc_remaining']),
      );
}

/// Business-partner picker row (charging / acctpair / unaccounted).
class MandaysBpartnerPickerRow {
  final int bpartnerId;
  final String code;
  final String name;
  final String description;

  const MandaysBpartnerPickerRow({
    required this.bpartnerId,
    required this.code,
    required this.name,
    required this.description,
  });

  factory MandaysBpartnerPickerRow.fromJson(Map<String, dynamic> j) =>
      MandaysBpartnerPickerRow(
        bpartnerId: _toIntOrNull(j['bpartner_id']) ?? 0,
        code: _toStr(j['code']),
        name: _toStr(j['name']),
        description: _toStr(j['description']),
      );
}

/// GL account-pair picker row.
class MandaysAcctPairPickerRow {
  final int acctId;
  final int subacctId;
  final String acctCode;
  final String acctName;
  final String subacctCode;
  final String subacctName;

  const MandaysAcctPairPickerRow({
    required this.acctId,
    required this.subacctId,
    required this.acctCode,
    required this.acctName,
    required this.subacctCode,
    required this.subacctName,
  });

  String get displayLabel =>
      '[$acctCode] $acctName — [$subacctCode] $subacctName';

  factory MandaysAcctPairPickerRow.fromJson(Map<String, dynamic> j) =>
      MandaysAcctPairPickerRow(
        acctId: _toIntOrNull(j['acct_id']) ?? 0,
        subacctId: _toIntOrNull(j['subacct_id']) ?? 0,
        acctCode: _toStr(j['acct_code']),
        acctName: _toStr(j['acct_name']),
        subacctCode: _toStr(j['subacct_code']),
        subacctName: _toStr(j['subacct_name']),
      );
}

/// Result returned by a matching-create / process / cancel call.
class MandaysWriteResult {
  final int matchingId;
  final String docstatus;
  final String? matchStatus;

  const MandaysWriteResult({
    required this.matchingId,
    required this.docstatus,
    required this.matchStatus,
  });

  factory MandaysWriteResult.fromJson(Map<String, dynamic> j) =>
      MandaysWriteResult(
        matchingId: _toIntOrNull(j['matching_id']) ?? 0,
        docstatus: _toStr(j['docstatus']),
        matchStatus: j['match_status']?.toString(),
      );
}

/// One row in the per-(project × scope_stage) accounted-salary report.
class MandaysReportProjectRow {
  final int projectId;
  final String projectName;
  final int stageId;
  final String stageName;
  final double totalMandays;
  final double accountedSalary;

  const MandaysReportProjectRow({
    required this.projectId,
    required this.projectName,
    required this.stageId,
    required this.stageName,
    required this.totalMandays,
    required this.accountedSalary,
  });

  factory MandaysReportProjectRow.fromJson(Map<String, dynamic> j) =>
      MandaysReportProjectRow(
        projectId: _toIntOrNull(j['project_id']) ?? 0,
        projectName: _toStr(j['project_name']),
        stageId: _toIntOrNull(j['stage_id']) ?? 0,
        stageName: _toStr(j['stage_name']),
        totalMandays: _toDouble(j['total_mandays']),
        accountedSalary: _toDouble(j['accounted_salary']),
      );
}

/// One row in the per-contract-type accounted-salary report. BSCSL/PITAI
/// columns may be zero if the underlying schema doesn't expose them yet —
/// callers should check the report's `hasSplitData` flag before showing
/// the breakdown.
class MandaysReportContractTypeRow {
  final int? contractTypeId;
  final String contractTypeName;
  final double totalMandays;
  final double accountedSalary;
  final double accountedSalaryBscsl;
  final double accountedSalaryPitai;

  const MandaysReportContractTypeRow({
    required this.contractTypeId,
    required this.contractTypeName,
    required this.totalMandays,
    required this.accountedSalary,
    required this.accountedSalaryBscsl,
    required this.accountedSalaryPitai,
  });

  factory MandaysReportContractTypeRow.fromJson(Map<String, dynamic> j) =>
      MandaysReportContractTypeRow(
        contractTypeId: _toIntOrNull(j['contract_type_id']),
        contractTypeName: _toStr(j['contract_type_name']),
        totalMandays: _toDouble(j['total_mandays']),
        accountedSalary: _toDouble(j['accounted_salary']),
        accountedSalaryBscsl: _toDouble(j['accounted_salary_bscsl']),
        accountedSalaryPitai: _toDouble(j['accounted_salary_pitai']),
      );
}

/// Wrapper for the contract-type report so the UI can decide whether to
/// render the BSCSL/PITAI columns or hide them.
class MandaysReportContractTypeResult {
  final bool hasSplitData;
  final List<MandaysReportContractTypeRow> rows;

  const MandaysReportContractTypeResult({
    required this.hasSplitData,
    required this.rows,
  });
}

/// Employee acknowledgement of an unaccounted-salary line. Mirrors the
/// backend `wbs_i_mandays_unacctd_salary_acks` row plus a resolved
/// `signature_url` the UI can render directly.
class MandaysUnacctdSalaryAck {
  final int id;
  final int bparPersonId;
  final int unaccountedLineId;
  final double amtUnaccountedSalary;
  final String signaturePath;
  final String? signatureUrl;
  final DateTime? ackDate;
  final bool isCancelled;
  final String? createdBy;
  final String? cancelledBy;
  final DateTime? cancelledAt;

  const MandaysUnacctdSalaryAck({
    required this.id,
    required this.bparPersonId,
    required this.unaccountedLineId,
    required this.amtUnaccountedSalary,
    required this.signaturePath,
    required this.signatureUrl,
    required this.ackDate,
    required this.isCancelled,
    required this.createdBy,
    required this.cancelledBy,
    required this.cancelledAt,
  });

  factory MandaysUnacctdSalaryAck.fromJson(Map<String, dynamic> j) =>
      MandaysUnacctdSalaryAck(
        id: _toIntOrNull(j['id']) ?? 0,
        bparPersonId: _toIntOrNull(j['bpar_i_person_id']) ?? 0,
        unaccountedLineId:
            _toIntOrNull(j['wip_t_mandays_matching_unaccounted_line_id']) ?? 0,
        amtUnaccountedSalary: _toDouble(j['amt_unaccounted_salary']),
        signaturePath: _toStr(j['signature_path']),
        signatureUrl: j['signature_url']?.toString(),
        ackDate: _parseDate(j['ack_date']),
        isCancelled: (_toIntOrNull(j['is_cancelled']) ?? 0) == 1 ||
            j['is_cancelled'] == true,
        createdBy: j['created_by']?.toString(),
        cancelledBy: j['cancelled_by']?.toString(),
        cancelledAt: _parseDate(j['cancelled_at']),
      );
}
