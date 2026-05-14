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

  String _qs(Map<String, String> qs) {
    if (qs.isEmpty) return '';
    final parts = qs.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}');
    return '?${parts.join('&')}';
  }
}
