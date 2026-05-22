import '../../../core/api/api_client.dart';
import '../models/consumption_models.dart';

/// Thin wrapper over [ApiClient] for the `/consumption/*` endpoints.
class ConsumptionApi {
  final ApiClient _api;

  ConsumptionApi({ApiClient? client}) : _api = client ?? ApiClient();

  Future<List<ConsumptionProject>> listProjects({
    String? search,
    String? category,
    String? token,
  }) async {
    final qs = <String, String>{};
    if (search != null && search.isNotEmpty) qs['search'] = search;
    if (category != null && category.isNotEmpty) qs['category'] = category;

    final res = await _api.get('/consumption/projects${_qs(qs)}', token: token);
    final data = (res['data'] as List?) ?? const [];
    return data
        .map((e) => ConsumptionProject.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ConsumptionBomBundle> loadFromErp(int ioId, {String? token}) async {
    final res = await _api.get('/consumption/load/$ioId', token: token);
    final data = res['data'];
    if (data is! Map) {
      throw ApiException('Unexpected response shape from load endpoint.');
    }
    return ConsumptionBomBundle.fromJson(Map<String, dynamic>.from(data));
  }

  Future<ConsumptionSession> createSession({
    int? ioId,
    int? wipProjectId,
    required String projectType,
    String completionMode = 'per_item',
    String? referenceNumber,
    String? remarks,
    String? updatedBy,
    required List<ConsumptionLine> lines,
    String? token,
  }) async {
    final body = <String, dynamic>{
      'io_id': ?ioId,
      'wip_i_project_id': ?wipProjectId,
      'project_type': projectType,
      'completion_mode': completionMode,
      'reference_number': ?referenceNumber,
      'remarks': ?remarks,
      'updated_by': ?updatedBy,
      'lines': lines.map((l) => l.toRequestJson()).toList(),
    };
    final res = await _api.post('/consumption/sessions', body, token: token);
    return ConsumptionSession.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<ConsumptionSession> getSession(int id, {String? token}) async {
    final res = await _api.get('/consumption/sessions/$id', token: token);
    return ConsumptionSession.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<ConsumptionSession> updateSession(
    int id, {
    required String projectType,
    String completionMode = 'per_item',
    String? remarks,
    String? updatedBy,
    required List<ConsumptionLine> lines,
    String? token,
  }) async {
    final body = <String, dynamic>{
      'project_type': projectType,
      'completion_mode': completionMode,
      'remarks': ?remarks,
      'updated_by': ?updatedBy,
      'lines': lines.map((l) => l.toRequestJson()).toList(),
    };
    final res = await _api.put('/consumption/sessions/$id', body, token: token);
    return ConsumptionSession.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<ConsumptionHistory> historyByBomline(
    int wipBomlineId, {
    String? token,
  }) async {
    final res = await _api.get(
      '/consumption/by-bomline/$wipBomlineId',
      token: token,
    );
    return ConsumptionHistory.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  /// Aggregated consumption across every BOM line under a project scope.
  /// Backs the BoQ Entries screen's consumption read-out now that selection
  /// happens at the scope level (no single bomline anchor).
  Future<ConsumptionHistory> historyByScope(
    int scopeId, {
    String? token,
  }) async {
    final res = await _api.get(
      '/consumption/by-scope/$scopeId',
      token: token,
    );
    return ConsumptionHistory.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  Future<ConsumptionSession> postSession(
    int id, {
    required String postedBy,
    String? token,
  }) async {
    final res = await _api.post(
      '/consumption/sessions/$id/post',
      {'posted_by': postedBy},
      token: token,
    );
    return ConsumptionSession.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  /// `/consumption/categories` — project categories for RP / Vespera orgs.
  /// Useful for filter dropdowns on the projects list.
  Future<List<ConsumptionCategory>> listCategories({String? token}) async {
    final res = await _api.get('/consumption/categories', token: token);
    final raw = (res['data'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((e) => ConsumptionCategory.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// `/consumption/sessions` — paginated list of saved sessions across every
  /// project. Filters: [status] (`draft` / `posted` / `voided`),
  /// [wipProjectId], [search] (matches reference_number or erp_document_no).
  Future<ConsumptionSessionsPage> listSessions({
    String? status,
    int? wipProjectId,
    String? search,
    int page = 1,
    int perPage = 25,
    String? token,
  }) async {
    final qs = <String, String>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null && status.isNotEmpty) qs['status'] = status;
    if (wipProjectId != null) qs['wip_i_project_id'] = wipProjectId.toString();
    if (search != null && search.isNotEmpty) qs['q'] = search;

    final res = await _api.get(
      '/consumption/sessions${_qs(qs)}',
      token: token,
    );
    final raw = (res['data'] as List?) ?? const [];
    final meta = (res['meta'] as Map?) ?? const {};
    return ConsumptionSessionsPage(
      items: raw
          .whereType<Map>()
          .map((e) => ConsumptionSessionSummary.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
      page: (meta['page'] as num?)?.toInt() ?? page,
      perPage: (meta['per_page'] as num?)?.toInt() ?? perPage,
      total: (meta['total'] as num?)?.toInt() ?? raw.length,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
    );
  }

  /// `/consumption/sessions/{id}/erp-verify` — side-by-side reconciliation
  /// of a posted session against the ERP `wip_t_project_consumption_line`
  /// rows it produced. Per-line `match_status` flags drift.
  Future<ErpVerifyResult> verifyAgainstErp(int id, {String? token}) async {
    final res = await _api.get(
      '/consumption/sessions/$id/erp-verify',
      token: token,
    );
    return ErpVerifyResult.fromJson(
      Map<String, dynamic>.from(res['data'] as Map),
    );
  }

  String _qs(Map<String, String> qs) {
    if (qs.isEmpty) return '';
    final parts = qs.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}');
    return '?${parts.join('&')}';
  }
}
