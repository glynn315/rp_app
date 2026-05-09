part of 'project_management_models.dart';

/// One ongoing project (Work-in-Progress) with weighted accomplishment %
/// and budgeted totals.
class WipProject {
  final int? projectId;
  final String projectName;
  final String projectDocumentNo;
  final String projectStatus;
  final String imsNo;
  final DateTime? dateStartActual;
  final DateTime? dateEndActual;
  final int scopeCount;
  final double totalScopePercentage;
  final double weightedProgressPercent;
  final double totalBomAmount;
  final double totalLmcAmount;

  double get totalAmount => totalBomAmount + totalLmcAmount;

  const WipProject({
    required this.projectId,
    required this.projectName,
    required this.projectDocumentNo,
    required this.projectStatus,
    required this.imsNo,
    required this.dateStartActual,
    required this.dateEndActual,
    required this.scopeCount,
    required this.totalScopePercentage,
    required this.weightedProgressPercent,
    required this.totalBomAmount,
    required this.totalLmcAmount,
  });

  factory WipProject.fromJson(Map<String, dynamic> j) => WipProject(
        projectId: _toIntOrNull(j['project_id']),
        projectName: _toStr(j['project_name']),
        projectDocumentNo: _toStr(j['project_documentno']),
        projectStatus: _toStr(j['project_status']),
        imsNo: _toStr(j['ims_no']),
        dateStartActual: _parseDate(j['date_start_actual']),
        dateEndActual: _parseDate(j['date_end_actual']),
        scopeCount: _toIntOrNull(j['scope_count']) ?? 0,
        totalScopePercentage: _toDouble(j['total_scope_percentage']),
        weightedProgressPercent: _toDouble(j['weighted_progress_percent']),
        totalBomAmount: _toDouble(j['total_bom_amount']),
        totalLmcAmount: _toDouble(j['total_lmc_amount']),
      );
}
