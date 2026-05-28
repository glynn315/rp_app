part of 'project_management_models.dart';

/// Header summary for a Mandays-Matching run (rolled-up from per-employee TA
/// summaries, optionally enriched with the linked TAPS payroll-run on DB4).
class MandaysMatchingRun {
  final int? runId;
  final String documentNo;
  final String docstatus;
  final DateTime? dateProcessed;
  final String payrollRun;
  final int? prlTRunId;
  final String tapsRunDocumentNo;
  final DateTime? tapsDateProcessed;
  final int employeeCount;
  final double totalMatchedQty;
  final double totalManualQty;
  final double grandTotalQty;
  final double totalAccountedSalary;
  final double totalUnaccountedSalary;
  final Map<String, dynamic>? taps;
  final String? tapsError;

  const MandaysMatchingRun({
    required this.runId,
    required this.documentNo,
    required this.docstatus,
    required this.dateProcessed,
    required this.payrollRun,
    required this.prlTRunId,
    required this.tapsRunDocumentNo,
    required this.tapsDateProcessed,
    required this.employeeCount,
    required this.totalMatchedQty,
    required this.totalManualQty,
    required this.grandTotalQty,
    required this.totalAccountedSalary,
    required this.totalUnaccountedSalary,
    required this.taps,
    required this.tapsError,
  });

  bool get isProcessed => docstatus == 'PR';

  factory MandaysMatchingRun.fromJson(Map<String, dynamic> j) =>
      MandaysMatchingRun(
        runId: _toIntOrNull(j['run_id']),
        documentNo: _toStr(j['documentno']),
        docstatus: _toStr(j['docstatus']),
        dateProcessed: _parseDate(j['date_processed']),
        payrollRun: _toStr(j['payroll_run']),
        prlTRunId: _toIntOrNull(j['prl_t_run_id']),
        tapsRunDocumentNo: _toStr(j['taps_run_documentno']),
        tapsDateProcessed: _parseDate(j['taps_date_processed']),
        employeeCount: _toIntOrNull(j['employee_count']) ?? 0,
        totalMatchedQty: _toDouble(j['total_matched_qty']),
        totalManualQty: _toDouble(j['total_manual_qty']),
        grandTotalQty: _toDouble(j['grand_total_qty']),
        totalAccountedSalary: _toDouble(j['total_accounted_salary']),
        totalUnaccountedSalary: _toDouble(j['total_unaccounted_salary']),
        taps: j['taps'] is Map
            ? Map<String, dynamic>.from(j['taps'] as Map)
            : null,
        tapsError: j['taps_error']?.toString(),
      );
}

/// Result of POST `/v1/projects/mandays-matching/auto-run`. `runId` is the
/// UUID written across every row of `wbs_i_mandays_auto_match_decisions`
/// for this invocation — surfaced so the operator can later query the audit
/// table by run.
class MandaysAutoRunResult {
  final String runId;
  final bool dryRun;
  final int count;
  final int applyCount;
  final int deferCount;
  final int errorCount;

  const MandaysAutoRunResult({
    required this.runId,
    required this.dryRun,
    required this.count,
    required this.applyCount,
    required this.deferCount,
    required this.errorCount,
  });

  factory MandaysAutoRunResult.fromJson(Map<String, dynamic> j) {
    final summary = j['summary'];
    final s = summary is Map ? Map<String, dynamic>.from(summary) : const {};
    final dr = j['dry_run'];
    return MandaysAutoRunResult(
      runId: _toStr(j['run_id']),
      dryRun: dr == true || dr == 1 || dr == '1',
      count: _toIntOrNull(j['count']) ?? 0,
      applyCount: _toIntOrNull(s['APPLY']) ?? 0,
      deferCount: _toIntOrNull(s['DEFER']) ?? 0,
      errorCount: _toIntOrNull(s['ERROR']) ?? 0,
    );
  }
}

/// Per-employee TA summary inside a Mandays-Matching run.
class MandaysMatchingEmployeeSummary {
  final int? summaryId;
  final int? runId;
  final int? personId;
  final String firstname;
  final String lastname;
  final String employeeNo;
  final double totalManualQty;
  final double totalMatchedQty;
  final double grandTotalQty;
  final double totalAccountedSalary;
  final double totalUnaccountedSalary;
  final double tapsBasicSalary;

  const MandaysMatchingEmployeeSummary({
    required this.summaryId,
    required this.runId,
    required this.personId,
    required this.firstname,
    required this.lastname,
    required this.employeeNo,
    required this.totalManualQty,
    required this.totalMatchedQty,
    required this.grandTotalQty,
    required this.totalAccountedSalary,
    required this.totalUnaccountedSalary,
    required this.tapsBasicSalary,
  });

  String get fullName {
    final parts = [firstname, lastname].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? (employeeNo.isEmpty ? '—' : employeeNo) : parts.join(' ');
  }

  factory MandaysMatchingEmployeeSummary.fromJson(Map<String, dynamic> j) =>
      MandaysMatchingEmployeeSummary(
        summaryId: _toIntOrNull(j['summary_id']),
        runId: _toIntOrNull(j['run_id']),
        personId: _toIntOrNull(j['person_id']),
        firstname: _toStr(j['firstname']),
        lastname: _toStr(j['lastname']),
        employeeNo: _toStr(j['employee_no']),
        totalManualQty: _toDouble(j['total_manual_qty']),
        totalMatchedQty: _toDouble(j['total_matched_qty']),
        grandTotalQty: _toDouble(j['grand_total_qty']),
        totalAccountedSalary: _toDouble(j['total_accounted_salary']),
        totalUnaccountedSalary: _toDouble(j['total_unaccounted_salary']),
        tapsBasicSalary: _toDouble(j['taps_basic_salary']),
      );
}
