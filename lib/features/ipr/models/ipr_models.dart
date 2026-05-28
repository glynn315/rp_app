// IPR (Item Purchase Requisition) models — ported from
// rpv-frontend-web/domains/ipr/services/ipr.service.ts.

int? _intN(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

int _int(dynamic v) => _intN(v) ?? 0;

double? _dblN(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double _dbl(dynamic v) => _dblN(v) ?? 0;

String? _strN(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

String _str(dynamic v) => v?.toString() ?? '';

class IprLine {
  final int id;
  final int? wipBomlineId;
  final int? nvtSkuId;
  final String? skucode;
  final String? itemName;
  final String? unit;
  final double qty;
  final double? qtyPo;
  final double? qtyStocktrans;
  final double? qtyOnHand;
  final double? amtCost;
  final int isClosed;
  final int? isAccepted;
  final String? explanation;
  final String? dateClosed;
  final String? remarks;
  final String? dateRequisition;

  const IprLine({
    required this.id,
    this.wipBomlineId,
    this.nvtSkuId,
    this.skucode,
    this.itemName,
    this.unit,
    required this.qty,
    this.qtyPo,
    this.qtyStocktrans,
    this.qtyOnHand,
    this.amtCost,
    required this.isClosed,
    this.isAccepted,
    this.explanation,
    this.dateClosed,
    this.remarks,
    this.dateRequisition,
  });

  bool get closed => isClosed == 1;

  factory IprLine.fromJson(Map<String, dynamic> j) => IprLine(
        id: _int(j['nvt_t_requisitionline_id']),
        wipBomlineId: _intN(j['wip_t_bomline_id']),
        nvtSkuId: _intN(j['nvt_i_sku_id']),
        skucode: _strN(j['skucode']),
        itemName: _strN(j['item_name']),
        unit: _strN(j['unit']),
        qty: _dbl(j['qty']),
        qtyPo: _dblN(j['qty_po']),
        qtyStocktrans: _dblN(j['qty_stocktrans']),
        qtyOnHand: _dblN(j['qty_on_hand']),
        amtCost: _dblN(j['amt_cost']),
        isClosed: _int(j['is_closed']),
        isAccepted: _intN(j['is_accepted']),
        explanation: _strN(j['explanation']),
        dateClosed: _strN(j['date_closed']),
        remarks: _strN(j['remarks']),
        dateRequisition: _strN(j['date_requisition']),
      );
}

class IprHeader {
  final int id;
  final String documentno;
  final String docstatus; // 'DR' | 'PR'
  final String? dateRequisition;
  final int adOrgId;
  final String? documentnoDr;
  final String? documentnoPr;
  final int? wipProjectId;
  final String? projectName;
  final String? projectStatus;

  const IprHeader({
    required this.id,
    required this.documentno,
    required this.docstatus,
    this.dateRequisition,
    required this.adOrgId,
    this.documentnoDr,
    this.documentnoPr,
    this.wipProjectId,
    this.projectName,
    this.projectStatus,
  });

  bool get isPosted => docstatus == 'PR';

  factory IprHeader.fromJson(Map<String, dynamic> j) => IprHeader(
        id: _int(j['nvt_t_requisition_id']),
        documentno: _str(j['documentno']),
        docstatus: _strN(j['docstatus']) ?? 'DR',
        dateRequisition: _strN(j['date_requisition']),
        adOrgId: _int(j['ad_org_id']),
        documentnoDr: _strN(j['documentno_dr']),
        documentnoPr: _strN(j['documentno_pr']),
        wipProjectId: _intN(j['wip_i_project_id']),
        projectName: _strN(j['project_name']),
        projectStatus: _strN(j['project_status']),
      );
}

class IprDetail {
  final IprHeader ipr;
  final List<IprLine> lines;
  const IprDetail({required this.ipr, required this.lines});

  factory IprDetail.fromJson(Map<String, dynamic> j) => IprDetail(
        ipr: IprHeader.fromJson(Map<String, dynamic>.from(j['ipr'] as Map)),
        lines: ((j['lines'] as List?) ?? const [])
            .map((e) => IprLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class IprSummary {
  final int id;
  final String documentno;
  final String docstatus;
  final String? dateRequisition;
  final int adOrgId;
  final int? wipProjectId;
  final String? projectName;
  final String? projectStatus;
  final int lineCount;

  const IprSummary({
    required this.id,
    required this.documentno,
    required this.docstatus,
    this.dateRequisition,
    required this.adOrgId,
    this.wipProjectId,
    this.projectName,
    this.projectStatus,
    required this.lineCount,
  });

  bool get isPosted => docstatus == 'PR';

  factory IprSummary.fromJson(Map<String, dynamic> j) => IprSummary(
        id: _int(j['nvt_t_requisition_id']),
        documentno: _str(j['documentno']),
        docstatus: _strN(j['docstatus']) ?? 'DR',
        dateRequisition: _strN(j['date_requisition']),
        adOrgId: _int(j['ad_org_id']),
        wipProjectId: _intN(j['wip_i_project_id']),
        projectName: _strN(j['project_name']),
        projectStatus: _strN(j['project_status']),
        lineCount: _int(j['line_count']),
      );
}

class IprMeta {
  final int total;
  final int page;
  final int perPage;
  final int lastPage;
  const IprMeta({
    required this.total,
    required this.page,
    required this.perPage,
    required this.lastPage,
  });

  bool get hasMore => page < lastPage;

  factory IprMeta.fromJson(Map<String, dynamic> j) => IprMeta(
        total: _int(j['total']),
        page: _intN(j['page']) ?? 1,
        perPage: _intN(j['per_page']) ?? 20,
        lastPage: _intN(j['last_page']) ?? 1,
      );
}

class IprListResponse {
  final List<IprSummary> data;
  final IprMeta meta;
  const IprListResponse({required this.data, required this.meta});
}

class EligibleProject {
  final int wipProjectId;
  final String projectName;
  final String projectStatus;
  final int adOrgId;
  final int linesToReq;

  const EligibleProject({
    required this.wipProjectId,
    required this.projectName,
    required this.projectStatus,
    required this.adOrgId,
    required this.linesToReq,
  });

  factory EligibleProject.fromJson(Map<String, dynamic> j) => EligibleProject(
        wipProjectId: _int(j['wip_i_project_id']),
        projectName: _str(j['project_name']),
        projectStatus: _str(j['project_status']),
        adOrgId: _int(j['ad_org_id']),
        linesToReq: _int(j['lines_to_req']),
      );
}

class IprMonitoringRow {
  final int requisitionId;
  final String iprDocumentno;
  final String iprStatus;
  final String? projectName;
  final String? projectStatus;
  final int? poId;
  final String? poDocumentno;
  final String? poStatus;
  final String? dateOrdered;
  final int? supplierId;
  final String? supplierName;
  final String? makerName;
  final int linesCovered;
  final double? qtyOrdered;
  final double? qtyReceived;
  final double? lineAmt;

  const IprMonitoringRow({
    required this.requisitionId,
    required this.iprDocumentno,
    required this.iprStatus,
    this.projectName,
    this.projectStatus,
    this.poId,
    this.poDocumentno,
    this.poStatus,
    this.dateOrdered,
    this.supplierId,
    this.supplierName,
    this.makerName,
    required this.linesCovered,
    this.qtyOrdered,
    this.qtyReceived,
    this.lineAmt,
  });

  factory IprMonitoringRow.fromJson(Map<String, dynamic> j) => IprMonitoringRow(
        requisitionId: _int(j['nvt_t_requisition_id']),
        iprDocumentno: _str(j['ipr_documentno']),
        iprStatus: _strN(j['ipr_status']) ?? 'DR',
        projectName: _strN(j['project_name']),
        projectStatus: _strN(j['project_status']),
        poId: _intN(j['nvt_t_po_id']),
        poDocumentno: _strN(j['po_documentno']),
        poStatus: _strN(j['po_status']),
        dateOrdered: _strN(j['date_ordered']),
        supplierId: _intN(j['supplier_id']),
        supplierName: _strN(j['supplier_name']),
        makerName: _strN(j['maker_name']),
        linesCovered: _int(j['lines_covered']),
        qtyOrdered: _dblN(j['qty_ordered']),
        qtyReceived: _dblN(j['qty_received']),
        lineAmt: _dblN(j['line_amt']),
      );
}

class IprMonitoringFilters {
  final List<({int id, String name})> suppliers;
  final List<String> makers;
  const IprMonitoringFilters({required this.suppliers, required this.makers});

  factory IprMonitoringFilters.fromJson(Map<String, dynamic> j) {
    final sup = ((j['suppliers'] as List?) ?? const [])
        .map((e) => (
              id: _int((e as Map)['id']),
              name: _str(e['name']),
            ))
        .toList();
    final mk = ((j['makers'] as List?) ?? const [])
        .map((e) => _str((e as Map)['name']))
        .where((s) => s.isNotEmpty)
        .toList();
    return IprMonitoringFilters(suppliers: sup, makers: mk);
  }
}
