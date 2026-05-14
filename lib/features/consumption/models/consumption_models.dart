double _toDouble(dynamic v, [double fallback = 0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? fallback;
}

int? _toIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool _toBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes';
}

String _toStr(dynamic v) => v?.toString() ?? '';

String? _toStrOrNull(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

/// Row in the projects list — merged ERP totals + local draft hints.
class ConsumptionProject {
  final int projectId;
  final String projectName;
  final String? projectType;
  final String? projectStatus;
  final String? categoryName;
  final double consumptionPct;
  final int draftCount;
  final DateTime? lastActivity;

  const ConsumptionProject({
    required this.projectId,
    required this.projectName,
    this.projectType,
    this.projectStatus,
    this.categoryName,
    required this.consumptionPct,
    required this.draftCount,
    this.lastActivity,
  });

  factory ConsumptionProject.fromJson(Map<String, dynamic> j) =>
      ConsumptionProject(
        projectId: _toIntOrNull(j['wip_i_project_id']) ?? 0,
        projectName: _toStr(j['project_name']),
        projectType: _toStrOrNull(j['project_type']),
        projectStatus: _toStrOrNull(j['project_status']),
        categoryName: _toStrOrNull(j['category_name']),
        consumptionPct: _toDouble(j['consumption_pct']),
        draftCount: _toIntOrNull(j['draft_count']) ?? 0,
        lastActivity: _parseDate(j['last_activity']),
      );
}

/// One BOM line — exists both in the ERP `load` response and inside a session.
class ConsumptionLine {
  /// Local session line id (null when freshly loaded from ERP).
  final int? id;
  final int? wipBomlineId;
  final int? nvtSkuId;
  final String? skuCode;
  final String itemDescription;
  final String? unit;
  final double bgtQty;
  final double consumedSoFar;
  final double locQty;
  final String mode; // 'consumed' | 'over_budget'
  final bool isDone;
  final double consumedQty;
  final double excessQty;
  final double overQty;
  final double remainingQty;
  final String? remarks;

  const ConsumptionLine({
    this.id,
    this.wipBomlineId,
    this.nvtSkuId,
    this.skuCode,
    required this.itemDescription,
    this.unit,
    required this.bgtQty,
    this.consumedSoFar = 0,
    this.locQty = 0,
    this.mode = 'consumed',
    this.isDone = false,
    this.consumedQty = 0,
    this.excessQty = 0,
    this.overQty = 0,
    this.remainingQty = 0,
    this.remarks,
  });

  factory ConsumptionLine.fromJson(Map<String, dynamic> j) => ConsumptionLine(
        id: _toIntOrNull(j['id']),
        wipBomlineId: _toIntOrNull(j['wip_t_bomline_id']),
        nvtSkuId: _toIntOrNull(j['nvt_i_sku_id']),
        skuCode: _toStrOrNull(j['sku_code']),
        itemDescription: _toStr(j['item_description']),
        unit: _toStrOrNull(j['unit']),
        bgtQty: _toDouble(j['bgt_qty']),
        consumedSoFar: _toDouble(j['consumed_so_far']),
        locQty: _toDouble(j['loc_qty']),
        mode: _toStrOrNull(j['mode']) ?? 'consumed',
        isDone: _toBool(j['is_done']),
        consumedQty: _toDouble(j['consumed_qty']),
        excessQty: _toDouble(j['excess_qty']),
        overQty: _toDouble(j['over_qty']),
        remainingQty: _toDouble(j['remaining_qty']),
        remarks: _toStrOrNull(j['remarks']),
      );

  /// Payload shape accepted by the store/update endpoints.
  Map<String, dynamic> toRequestJson() => {
        if (wipBomlineId != null) 'wip_t_bomline_id': wipBomlineId,
        if (nvtSkuId != null) 'nvt_i_sku_id': nvtSkuId,
        'item_description': itemDescription,
        if (unit != null) 'unit': unit,
        'bgt_qty': bgtQty,
        'loc_qty': locQty,
        'mode': mode,
        'is_done': isDone,
        'consumed_qty': consumedQty,
        'over_qty': overQty,
        if (remarks != null) 'remarks': remarks,
      };

  ConsumptionLine copyWith({
    double? locQty,
    String? mode,
    bool? isDone,
    double? consumedQty,
    double? overQty,
    String? remarks,
  }) =>
      ConsumptionLine(
        id: id,
        wipBomlineId: wipBomlineId,
        nvtSkuId: nvtSkuId,
        skuCode: skuCode,
        itemDescription: itemDescription,
        unit: unit,
        bgtQty: bgtQty,
        consumedSoFar: consumedSoFar,
        locQty: locQty ?? this.locQty,
        mode: mode ?? this.mode,
        isDone: isDone ?? this.isDone,
        consumedQty: consumedQty ?? this.consumedQty,
        excessQty: excessQty,
        overQty: overQty ?? this.overQty,
        remainingQty: remainingQty,
        remarks: remarks ?? this.remarks,
      );
}

/// Wrapper around the `/consumption/load/{ioId}` response.
class ConsumptionBomBundle {
  final int projectId;
  final String projectName;
  final String projectType; // 'project' | 'cost_of_service'
  final List<ConsumptionLine> lines;

  const ConsumptionBomBundle({
    required this.projectId,
    required this.projectName,
    required this.projectType,
    required this.lines,
  });

  factory ConsumptionBomBundle.fromJson(Map<String, dynamic> j) {
    final rawLines = (j['lines'] as List?) ?? const [];
    return ConsumptionBomBundle(
      projectId: _toIntOrNull(j['wip_i_project_id']) ?? 0,
      projectName: _toStr(j['project_name']),
      projectType: _toStrOrNull(j['project_type']) ?? 'project',
      lines: rawLines
          .map((e) => ConsumptionLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// One historical consumption entry surfaced by `/consumption/by-bomline/{id}`.
class ConsumptionHistoryEntry {
  final int? id;
  final int? sessionId;
  final String itemDescription;
  final String? unit;
  final double consumedQty;
  final double excessQty;
  final double overQty;
  final String? mode;
  final bool isDone;
  final String status; // 'draft' | 'posted' | 'voided'
  final String? postedBy;
  final DateTime? postedAt;
  final String? updatedBy;
  final DateTime? sessionUpdatedAt;
  final String? remarks;

  const ConsumptionHistoryEntry({
    this.id,
    this.sessionId,
    required this.itemDescription,
    this.unit,
    required this.consumedQty,
    required this.excessQty,
    required this.overQty,
    this.mode,
    this.isDone = false,
    required this.status,
    this.postedBy,
    this.postedAt,
    this.updatedBy,
    this.sessionUpdatedAt,
    this.remarks,
  });

  factory ConsumptionHistoryEntry.fromJson(Map<String, dynamic> j) =>
      ConsumptionHistoryEntry(
        id: _toIntOrNull(j['id']),
        sessionId: _toIntOrNull(j['consumption_session_id']),
        itemDescription: _toStr(j['item_description']),
        unit: _toStrOrNull(j['unit']),
        consumedQty: _toDouble(j['consumed_qty']),
        excessQty: _toDouble(j['excess_qty']),
        overQty: _toDouble(j['over_qty']),
        mode: _toStrOrNull(j['mode']),
        isDone: _toBool(j['is_done']),
        status: _toStrOrNull(j['status']) ?? 'draft',
        postedBy: _toStrOrNull(j['posted_by']),
        postedAt: _parseDate(j['posted_at']),
        updatedBy: _toStrOrNull(j['updated_by']) ??
            _toStrOrNull(j['created_by']),
        sessionUpdatedAt: _parseDate(j['session_updated_at']),
        remarks: _toStrOrNull(j['remarks']),
      );
}

/// Aggregated history for one BOM line — totals + individual entries.
class ConsumptionHistory {
  final int wipBomlineId;
  final double totalConsumed;
  final double totalExcess;
  final double totalOver;
  final int entryCount;
  final List<ConsumptionHistoryEntry> entries;

  const ConsumptionHistory({
    required this.wipBomlineId,
    required this.totalConsumed,
    required this.totalExcess,
    required this.totalOver,
    required this.entryCount,
    required this.entries,
  });

  factory ConsumptionHistory.fromJson(Map<String, dynamic> j) {
    final totals = (j['totals'] as Map?) ?? const {};
    final rawLines = (j['lines'] as List?) ?? const [];
    return ConsumptionHistory(
      wipBomlineId: _toIntOrNull(j['wip_t_bomline_id']) ?? 0,
      totalConsumed: _toDouble(totals['consumed_qty']),
      totalExcess: _toDouble(totals['excess_qty']),
      totalOver: _toDouble(totals['over_qty']),
      entryCount: _toIntOrNull(totals['entries']) ?? rawLines.length,
      entries: rawLines
          .map((e) =>
              ConsumptionHistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// A draft or posted session retrieved from the backend.
class ConsumptionSession {
  final int id;
  final int? wipProjectId;
  final String projectType;
  final String completionMode; // 'per_item' | 'entire_order'
  final String status; // 'draft' | 'posted'
  final String? referenceNumber;
  final String? remarks;
  final String? postedBy;
  final DateTime? postedAt;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? updatedAt;
  final List<ConsumptionLine> lines;

  const ConsumptionSession({
    required this.id,
    required this.wipProjectId,
    required this.projectType,
    required this.completionMode,
    required this.status,
    this.referenceNumber,
    this.remarks,
    this.postedBy,
    this.postedAt,
    this.createdBy,
    this.updatedBy,
    this.updatedAt,
    required this.lines,
  });

  bool get isPosted => status == 'posted';

  factory ConsumptionSession.fromJson(Map<String, dynamic> j) {
    final rawLines = (j['lines'] as List?) ?? const [];
    return ConsumptionSession(
      id: _toIntOrNull(j['id']) ?? 0,
      wipProjectId: _toIntOrNull(j['wip_i_project_id']),
      projectType: _toStrOrNull(j['project_type']) ?? 'project',
      completionMode: _toStrOrNull(j['completion_mode']) ?? 'per_item',
      status: _toStrOrNull(j['status']) ?? 'draft',
      referenceNumber: _toStrOrNull(j['reference_number']),
      remarks: _toStrOrNull(j['remarks']),
      postedBy: _toStrOrNull(j['posted_by']),
      postedAt: _parseDate(j['posted_at']),
      createdBy: _toStrOrNull(j['created_by']),
      updatedBy: _toStrOrNull(j['updated_by']),
      updatedAt: _parseDate(j['updated_at']),
      lines: rawLines
          .map((e) => ConsumptionLine.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
