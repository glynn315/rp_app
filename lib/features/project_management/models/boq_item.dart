part of 'project_management_models.dart';

/// One Bill-of-Quantities line (BOM material, labor, or misc cost) anchored
/// to a project / scope / stage.
class BoqItem {
  final String lineKind;
  final int? lineId;
  final int? projectId;
  final String projectName;
  final String projectDocumentNo;
  final String projectStatus;
  final int? scopeId;
  final String scopeName;
  final int? stageId;
  final String stageName;
  final String itemLabel;
  final double qty;
  final double rate;
  final double amount;
  final String docstatus;
  final bool isLocked;

  const BoqItem({
    required this.lineKind,
    required this.lineId,
    required this.projectId,
    required this.projectName,
    required this.projectDocumentNo,
    required this.projectStatus,
    required this.scopeId,
    required this.scopeName,
    required this.stageId,
    required this.stageName,
    required this.itemLabel,
    required this.qty,
    required this.rate,
    required this.amount,
    required this.docstatus,
    required this.isLocked,
  });

  factory BoqItem.fromJson(Map<String, dynamic> j) => BoqItem(
        lineKind: _toStr(j['line_kind']).isEmpty ? 'BOM' : _toStr(j['line_kind']),
        lineId: _toIntOrNull(j['line_id']),
        projectId: _toIntOrNull(j['project_id']),
        projectName: _toStr(j['project_name']),
        projectDocumentNo: _toStr(j['project_documentno']),
        projectStatus: _toStr(j['project_status']),
        scopeId: _toIntOrNull(j['scope_id']),
        scopeName: _toStr(j['scope_name']),
        stageId: _toIntOrNull(j['stage_id']),
        stageName: _toStr(j['stage_name']),
        itemLabel: _toStr(j['item_label']),
        qty: _toDouble(j['qty']),
        rate: _toDouble(j['rate']),
        amount: _toDouble(j['amount']),
        docstatus: _toStr(j['docstatus']),
        isLocked: j['is_locked'] == true ||
            j['is_locked'] == 1 ||
            _toStr(j['is_locked']) == '1',
      );
}
