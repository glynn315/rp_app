import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/ipr_models.dart';

/// Talks to the backend IPR endpoints (under the `/ipr` prefix). Mirrors
/// rpv-frontend-web/domains/ipr/services/ipr.service.ts.
class IprApi {
  final ApiClient _api;
  IprApi({ApiClient? api}) : _api = api ?? ApiClient();

  String _qs(Map<String, dynamic> params) {
    final parts = <String>[];
    params.forEach((k, v) {
      if (v == null) return;
      final s = v.toString();
      if (s.isEmpty) return;
      parts.add('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(s)}');
    });
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  Map<String, dynamic> _actor({int? actorEmployeeId, String? postedBy}) => {
        if (actorEmployeeId != null && actorEmployeeId > 0)
          'actor_employee_id': actorEmployeeId,
        if (postedBy != null && postedBy.isNotEmpty) 'posted_by': postedBy,
      };

  Future<IprListResponse> list({
    String search = '',
    String status = '',
    int page = 1,
    int perPage = 20,
    String? token,
  }) async {
    final res = await _api.get(
      '/ipr${_qs({'search': search, 'status': status, 'page': page, 'per_page': perPage})}',
      token: token,
    );
    final data = ((res['data'] as List?) ?? const [])
        .map((e) => IprSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final meta = res['meta'] is Map
        ? IprMeta.fromJson(Map<String, dynamic>.from(res['meta'] as Map))
        : const IprMeta(total: 0, page: 1, perPage: 20, lastPage: 1);
    return IprListResponse(data: data, meta: meta);
  }

  Future<IprDetail> getById(int id, {String? token}) async {
    final res = await _api.get('/ipr/$id', token: token);
    return IprDetail.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<List<IprSummary>> byProject(int projectId, {String? token}) async {
    final res = await _api.get('/ipr/project/$projectId', token: token);
    return ((res['data'] as List?) ?? const [])
        .map((e) => IprSummary.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<IprDetail> generate(
    int projectId, {
    int? actorEmployeeId,
    String? postedBy,
    String? token,
  }) async {
    final res = await _api.post(
      '/ipr/generate/$projectId',
      _actor(actorEmployeeId: actorEmployeeId, postedBy: postedBy),
      token: token,
    );
    return IprDetail.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<IprDetail> post(
    int id, {
    int? actorEmployeeId,
    String? postedBy,
    String? token,
  }) async {
    final res = await _api.post(
      '/ipr/$id/post',
      _actor(actorEmployeeId: actorEmployeeId, postedBy: postedBy),
      token: token,
    );
    return IprDetail.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<List<EligibleProject>> eligibleProjects({
    String search = '',
    String? token,
  }) async {
    final res = await _api.get(
      '/ipr/eligible-projects${_qs({'search': search})}',
      token: token,
    );
    return ((res['data'] as List?) ?? const [])
        .map((e) => EligibleProject.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<IprDetail> closeLine(
    int iprId,
    int lineId, {
    required String explanation,
    String? remarks,
    String? token,
  }) async {
    final res = await _api.put(
      '/ipr/$iprId/lines/$lineId/close',
      {'explanation': explanation, 'remarks': ?remarks},
      token: token,
    );
    return IprDetail.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<IprDetail> updateLineQty(
    int iprId,
    int lineId,
    double qty, {
    String? token,
  }) async {
    final res = await _api.put(
      '/ipr/$iprId/lines/$lineId',
      {'qty': qty},
      token: token,
    );
    return IprDetail.fromJson(Map<String, dynamic>.from(res['data'] as Map));
  }

  Future<({List<IprMonitoringRow> data, IprMeta meta})> monitoring({
    String search = '',
    int? supplierId,
    String maker = '',
    int page = 1,
    int perPage = 30,
    String? token,
  }) async {
    final res = await _api.get(
      '/ipr/monitoring${_qs({
            'search': search,
            'supplier_id': supplierId,
            'maker': maker,
            'page': page,
            'per_page': perPage,
          })}',
      token: token,
    );
    final data = ((res['data'] as List?) ?? const [])
        .map((e) => IprMonitoringRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final meta = res['meta'] is Map
        ? IprMeta.fromJson(Map<String, dynamic>.from(res['meta'] as Map))
        : const IprMeta(total: 0, page: 1, perPage: 30, lastPage: 1);
    return (data: data, meta: meta);
  }

  Future<IprMonitoringFilters> monitoringFilters({String? token}) async {
    final res = await _api.get('/ipr/monitoring/filters', token: token);
    return IprMonitoringFilters.fromJson(
        Map<String, dynamic>.from(res['data'] as Map));
  }
}

final iprApiProvider = Provider<IprApi>((ref) => IprApi());
