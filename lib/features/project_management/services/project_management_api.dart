import '../../../core/api/api_client.dart';
import '../models/project_management_models.dart';

/// Thin wrapper over [ApiClient] for the `/v1/projects/*` endpoints
/// (Bill of Quantities, Work in Progress, Mandays Matching).
class ProjectManagementApi {
  final ApiClient _api;

  ProjectManagementApi({ApiClient? client}) : _api = client ?? ApiClient();

  Future<List<BoqItem>> boqList({
    int? projectId,
    int? scopeId,
    String? status,
    List<int>? categoryIds,
    String? search,
    bool latestOnly = true,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (projectId != null) qs['project_id'] = projectId.toString();
    if (scopeId != null) qs['scope_id'] = scopeId.toString();
    if (status != null && status.isNotEmpty) qs['status'] = status;
    if (categoryIds != null && categoryIds.isNotEmpty) {
      qs['category_id'] = categoryIds.join(',');
    }
    if (search != null && search.isNotEmpty) qs['q'] = search;
    if (!latestOnly) qs['latest_only'] = '0';

    final res = await _api.get('/v1/projects/boq${_qs(qs)}', token: token);
    return _mapList(res, BoqItem.fromJson);
  }

  Future<List<WipProject>> wipList({
    String? status,
    int? projectId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (status != null && status.isNotEmpty) qs['status'] = status;
    if (projectId != null) qs['project_id'] = projectId.toString();
    if (dateFrom != null) qs['date_from'] = _ymd(dateFrom);
    if (dateTo != null) qs['date_to'] = _ymd(dateTo);
    if (search != null && search.isNotEmpty) qs['q'] = search;

    final res = await _api.get('/v1/projects/wip${_qs(qs)}', token: token);
    return _mapList(res, WipProject.fromJson);
  }

  Future<List<LmcPayout>> lmcPayoutList({
    String? docstatus,
    bool? isClosed,
    int? projectId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    bool latestOnly = true,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (docstatus != null && docstatus.isNotEmpty) qs['docstatus'] = docstatus;
    if (isClosed != null) qs['is_closed'] = isClosed ? '1' : '0';
    if (projectId != null) qs['project_id'] = projectId.toString();
    if (dateFrom != null) qs['date_from'] = _ymd(dateFrom);
    if (dateTo != null) qs['date_to'] = _ymd(dateTo);
    if (search != null && search.isNotEmpty) qs['q'] = search;
    if (!latestOnly) qs['latest_only'] = '0';

    final res = await _api.get('/v1/projects/lmc-payout${_qs(qs)}', token: token);
    return _mapList(res, LmcPayout.fromJson);
  }

  Future<List<ProjectLookup>> projectLookup({
    String? search,
    String? status,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (search != null && search.isNotEmpty) qs['q'] = search;
    if (status != null && status.isNotEmpty) qs['status'] = status;

    final res = await _api.get('/v1/projects/lookup${_qs(qs)}', token: token);
    return _mapList(res, ProjectLookup.fromJson);
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<LmcPayoutLine>> lmcPayoutDetail(
    int payoutId, {
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/projects/lmc-payout/$payoutId',
      token: token,
    );
    return _mapList(res, LmcPayoutLine.fromJson);
  }

  Future<List<MandaysMatchingRun>> mandaysMatchingRuns({
    String? docstatus,
    String? search,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (docstatus != null && docstatus.isNotEmpty) qs['docstatus'] = docstatus;
    if (search != null && search.isNotEmpty) qs['q'] = search;

    final res = await _api.get(
      '/v1/projects/mandays-matching/runs${_qs(qs)}',
      token: token,
    );
    return _mapList(res, MandaysMatchingRun.fromJson);
  }

  Future<List<MandaysMatchingEmployeeSummary>> mandaysMatchingRunDetail(
    int runId, {
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/projects/mandays-matching/runs/$runId',
      token: token,
    );
    return _mapList(res, MandaysMatchingEmployeeSummary.fromJson);
  }

  // ===== Maker/checker workflow =====

  /// Pending list — one row per (employee, schedule date) with aggregate
  /// status (UNMATCHED / PARTIAL / PREMATCHED / MATCHED).
  Future<List<MandaysPendingRow>> mandaysPendingList({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? status, // UNMATCHED | PREMATCHED | MATCHED
    String? search,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (dateFrom != null) qs['date_from'] = _ymd(dateFrom);
    if (dateTo != null) qs['date_to'] = _ymd(dateTo);
    if (status != null && status.isNotEmpty) qs['status'] = status;
    if (search != null && search.isNotEmpty) qs['q'] = search;
    final res = await _api.get(
      '/v1/projects/mandays-matching/pending${_qs(qs)}',
      token: token,
    );
    return _mapList(res, MandaysPendingRow.fromJson);
  }

  Future<List<MandaysTaLog>> mandaysTaLogs({
    required int employeeId,
    required DateTime date,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/projects/mandays-matching/employee/$employeeId/${_ymd(date)}/ta-logs',
      token: token,
    );
    return _mapList(res, MandaysTaLog.fromJson);
  }

  Future<List<MandaysMatchingDoc>> mandaysEmployeeMatchings({
    required int employeeId,
    required DateTime date,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/projects/mandays-matching/employee/$employeeId/${_ymd(date)}/matchings',
      token: token,
    );
    return _mapList(res, MandaysMatchingDoc.fromJson);
  }

  Future<MandaysDer?> mandaysEmployeeDer({
    required int employeeId,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/projects/mandays-matching/employee/$employeeId/der',
      token: token,
    );
    final raw = res['data'];
    if (raw is! Map) return null;
    return MandaysDer.fromJson(Map<String, dynamic>.from(raw));
  }

  Future<List<MandaysStagePickerRow>> mandaysPickerStages({
    String? search,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (search != null && search.isNotEmpty) qs['q'] = search;
    final res = await _api.get(
      '/v1/projects/mandays-matching/pickers/project-scope-stages${_qs(qs)}',
      token: token,
    );
    return _mapList(res, MandaysStagePickerRow.fromJson);
  }

  Future<List<MandaysBpartnerPickerRow>> mandaysPickerBpartners({
    String? search,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (search != null && search.isNotEmpty) qs['q'] = search;
    final res = await _api.get(
      '/v1/projects/mandays-matching/pickers/bpartners${_qs(qs)}',
      token: token,
    );
    return _mapList(res, MandaysBpartnerPickerRow.fromJson);
  }

  Future<List<MandaysAcctPairPickerRow>> mandaysPickerAcctPairs({
    String? search,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (search != null && search.isNotEmpty) qs['q'] = search;
    final res = await _api.get(
      '/v1/projects/mandays-matching/pickers/account-pairs${_qs(qs)}',
      token: token,
    );
    return _mapList(res, MandaysAcctPairPickerRow.fromJson);
  }

  // --- writes ---

  Future<MandaysWriteResult> mandaysCreateProject({
    required int employeeId,
    required DateTime dateSchedule,
    required int stageId,
    required double matchedMandaysQty,
    required List<int> taLogIds,
    String? explanation,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/projects/mandays-matching/project',
      {
        'employee_id': employeeId,
        'date_schedule': _ymd(dateSchedule),
        'stage_id': stageId,
        'matched_mandays_qty': matchedMandaysQty,
        'ta_log_ids': taLogIds,
        if (explanation != null && explanation.isNotEmpty)
          'explanation': explanation,
      },
      token: token,
    );
    return MandaysWriteResult.fromJson(res);
  }

  Future<MandaysWriteResult> mandaysCreateCharging({
    required int employeeId,
    required DateTime dateSchedule,
    required int bpartnerId,
    required int acctPairId,
    required double matchedMandaysQty,
    required List<int> taLogIds,
    required String explanation,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/projects/mandays-matching/charging',
      {
        'employee_id': employeeId,
        'date_schedule': _ymd(dateSchedule),
        'bpartner_id': bpartnerId,
        'acct_pair_id': acctPairId,
        'matched_mandays_qty': matchedMandaysQty,
        'ta_log_ids': taLogIds,
        'explanation': explanation,
      },
      token: token,
    );
    return MandaysWriteResult.fromJson(res);
  }

  Future<MandaysWriteResult> mandaysCreateAcctpair({
    required int employeeId,
    required DateTime dateSchedule,
    required int bpartnerId,
    required int acctPairId,
    required double matchedMandaysQty,
    required List<int> taLogIds,
    String? description,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/projects/mandays-matching/acctpair',
      {
        'employee_id': employeeId,
        'date_schedule': _ymd(dateSchedule),
        'bpartner_id': bpartnerId,
        'acct_pair_id': acctPairId,
        'matched_mandays_qty': matchedMandaysQty,
        'ta_log_ids': taLogIds,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
      token: token,
    );
    return MandaysWriteResult.fromJson(res);
  }

  Future<MandaysWriteResult> mandaysCreateUnaccounted({
    required int employeeId,
    required DateTime dateSchedule,
    required int bpartnerId,
    required double matchedMandaysQty,
    required List<int> taLogIds,
    required String remarks,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/projects/mandays-matching/unaccounted',
      {
        'employee_id': employeeId,
        'date_schedule': _ymd(dateSchedule),
        'bpartner_id': bpartnerId,
        'matched_mandays_qty': matchedMandaysQty,
        'ta_log_ids': taLogIds,
        'remarks': remarks,
      },
      token: token,
    );
    return MandaysWriteResult.fromJson(res);
  }

  Future<MandaysWriteResult> mandaysProcess({
    required int matchingId,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/projects/mandays-matching/$matchingId/process',
      const {},
      token: token,
    );
    return MandaysWriteResult.fromJson(res);
  }

  Future<MandaysWriteResult> mandaysCancel({
    required int matchingId,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/projects/mandays-matching/$matchingId/cancel',
      const {},
      token: token,
    );
    return MandaysWriteResult.fromJson(res);
  }

  // ── Unaccounted-salary acknowledgements ──────────────────────────────

  /// Create an unaccounted-salary ack with a signature PNG. [signatureBytes]
  /// is the raw PNG payload from the signature_pad widget (already
  /// `toPngBytes()`'d). Backend stores it on the public disk and returns the
  /// row plus a `signature_url` you can render directly via Image.network.
  Future<MandaysUnacctdSalaryAck> createUnacctdAck({
    required int unaccountedLineId,
    required double amtUnaccountedSalary,
    required DateTime ackDate,
    required List<int> signatureBytes,
    int? bparPersonId,
    int? sBpartnerEmployeeId,
    String? createdBy,
    String? token,
  }) async {
    if (bparPersonId == null && sBpartnerEmployeeId == null) {
      throw ArgumentError(
        'createUnacctdAck requires either bparPersonId or sBpartnerEmployeeId.',
      );
    }
    final fields = <String, String>{
      'wip_t_mandays_matching_unaccounted_line_id': unaccountedLineId.toString(),
      'amt_unaccounted_salary': amtUnaccountedSalary.toString(),
      'ack_date': _ymd(ackDate),
    };
    if (bparPersonId != null) {
      fields['bpar_i_person_id'] = bparPersonId.toString();
    }
    if (sBpartnerEmployeeId != null) {
      fields['s_bpartner_employee_id'] = sBpartnerEmployeeId.toString();
    }
    if (createdBy != null && createdBy.isNotEmpty) fields['created_by'] = createdBy;

    final res = await _api.postMultipart(
      '/v1/projects/mandays-matching/unaccounted-acks',
      fields: fields,
      fileField: 'signature',
      fileBytes: signatureBytes,
      filename: 'signature.png',
      token: token,
    );
    // Backend includes `signature_url` at the top level, not inside `data` —
    // splice it into the row map so the model's fromJson picks it up.
    final data = Map<String, dynamic>.from(res['data'] as Map);
    if (res['signature_url'] != null) {
      data['signature_url'] = res['signature_url'];
    }
    return MandaysUnacctdSalaryAck.fromJson(data);
  }

  Future<MandaysUnacctdSalaryAck> cancelUnacctdAck({
    required int ackId,
    String? cancelledBy,
    String? token,
  }) async {
    final body = <String, dynamic>{};
    if (cancelledBy != null && cancelledBy.isNotEmpty) body['cancelled_by'] = cancelledBy;
    final res = await _api.post(
      '/v1/projects/mandays-matching/unaccounted-acks/$ackId/cancel',
      body,
      token: token,
    );
    return MandaysUnacctdSalaryAck.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<List<MandaysUnacctdSalaryAck>> listUnacctdAcksForEmployee({
    required int bparPersonId,
    bool includeCancelled = false,
    String? token,
  }) async {
    final qs = includeCancelled ? '?include_cancelled=1' : '';
    final res = await _api.get(
      '/v1/projects/mandays-matching/employees/$bparPersonId/unaccounted-acks$qs',
      token: token,
    );
    return _mapList(res, MandaysUnacctdSalaryAck.fromJson);
  }

  Future<List<MandaysUnacctdSalaryAck>> listUnacctdAcksForLine({
    required int unaccountedLineId,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/projects/mandays-matching/unaccounted-lines/$unaccountedLineId/acks',
      token: token,
    );
    return _mapList(res, MandaysUnacctdSalaryAck.fromJson);
  }

  // ── Accounted-salary period reports ──────────────────────────────────

  Future<List<MandaysReportProjectRow>> reportAccountedSalaryPerProject({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? token,
  }) async {
    final qs = _qs({
      'date_from': _ymd(dateFrom),
      'date_to': _ymd(dateTo),
    });
    final res = await _api.get(
      '/v1/projects/mandays-matching/reports/per-project$qs',
      token: token,
    );
    return _mapList(res, MandaysReportProjectRow.fromJson);
  }

  Future<MandaysReportContractTypeResult> reportAccountedSalaryPerContractType({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? token,
  }) async {
    final qs = _qs({
      'date_from': _ymd(dateFrom),
      'date_to': _ymd(dateTo),
    });
    final res = await _api.get(
      '/v1/projects/mandays-matching/reports/per-contract-type$qs',
      token: token,
    );
    return MandaysReportContractTypeResult(
      hasSplitData: res['has_split_data'] == true,
      rows: _mapList(res, MandaysReportContractTypeRow.fromJson),
    );
  }

  String _qs(Map<String, String> qs) {
    if (qs.isEmpty) return '';
    final encoded = qs.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '?$encoded';
  }

  List<T> _mapList<T>(
    Map<String, dynamic> res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = (res['data'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((m) => fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
