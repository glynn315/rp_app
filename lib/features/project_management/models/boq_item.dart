part of 'project_management_models.dart';

/// One Bill-of-Quantities entry, rolled up to (project, scope). The amount is
/// the sum of every BOM and LMC line under any stage of this scope; there is
/// no longer a per-line breakdown surfaced to the app.
class BoqItem {
  final int? projectId;
  final String projectName;
  final String projectDocumentNo;
  final String projectStatus;
  final int? scopeId;
  final String scopeName;
  final double amount;

  const BoqItem({
    required this.projectId,
    required this.projectName,
    required this.projectDocumentNo,
    required this.projectStatus,
    required this.scopeId,
    required this.scopeName,
    required this.amount,
  });

  factory BoqItem.fromJson(Map<String, dynamic> j) => BoqItem(
        projectId: _toIntOrNull(j['project_id']),
        projectName: _toStr(j['project_name']),
        projectDocumentNo: _toStr(j['project_documentno']),
        projectStatus: _toStr(j['project_status']),
        scopeId: _toIntOrNull(j['scope_id']),
        scopeName: _toStr(j['scope_name']),
        amount: _toDouble(j['amount']),
      );
}
