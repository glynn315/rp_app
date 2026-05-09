import '../../../core/api/api_client.dart';
import '../models/project_management_models.dart';

/// Thin wrapper over [ApiClient] for the `/v1/projects/*` endpoints
/// (Bill of Quantities, Work in Progress, Mandays Matching).
class ProjectManagementApi {
  final ApiClient _api;

  ProjectManagementApi({ApiClient? client}) : _api = client ?? ApiClient();

  Future<List<BoqItem>> boqList({
    int? projectId,
    String? status,
    String? lineKind,
    List<int>? categoryIds,
    String? search,
    bool latestOnly = true,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (projectId != null) qs['project_id'] = projectId.toString();
    if (status != null && status.isNotEmpty) qs['status'] = status;
    if (lineKind != null && lineKind.isNotEmpty) qs['line_kind'] = lineKind;
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
