import '../../../core/api/api_client.dart';
import '../models/hangs_models.dart';
import '../models/taps_sync_models.dart';

/// Thin wrapper over [ApiClient] for the `/v1/hr/*` endpoints — Taps sync
/// and Hangs. Both endpoints page by DWR day under the hood and return a
/// flat list of intervals/punches, with `has_more` + `next_cursor` for
/// chronologically older days.
class HrApi {
  final ApiClient _api;

  HrApi({ApiClient? client}) : _api = client ?? ApiClient();

  /// GET `/v1/hr/taps-sync` — one day-keyed page of an employee's TAPS
  /// punches. `sBpartnerEmployeeId` comes from the auth user's `id`.
  /// Defaults to matched-only; pass `includeUnmatched: true` to surface
  /// raw punches the matcher hasn't paired yet.
  Future<TapsSyncPage> listTapsSync({
    required String sBpartnerEmployeeId,
    int? days,
    String? beforeDate, // yyyy-MM-dd
    bool includeUnmatched = false,
    String? token,
  }) async {
    final qs = <String, String>{
      's_bpartner_employee_id': sBpartnerEmployeeId,
      if (days != null) 'days': days.toString(),
      if (beforeDate != null && beforeDate.isNotEmpty) 'before_date': beforeDate,
      if (includeUnmatched) 'include_unmatched': '1',
    };
    final res = await _api.get('/v1/hr/taps-sync${_qs(qs)}', token: token);
    final raw = (res['data'] as List?) ?? const [];
    return TapsSyncPage(
      items: raw
          .whereType<Map>()
          .map((e) => TapsRawLog.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasMore: res['has_more'] == true || res['has_more'] == 1,
      nextCursor: _strOrNull(res['next_cursor']),
      dayCount: (res['day_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// GET `/v1/hr/hangs` — one cursor page of hang intervals (flat list
  /// across days). Cursor matches the Mandays Match endpoint.
  Future<HangsPage> listHangs({
    required String sBpartnerEmployeeId,
    required String employeeCode,
    int? days,
    String? beforeDate,
    String? token,
  }) async {
    final qs = <String, String>{
      's_bpartner_employee_id': sBpartnerEmployeeId,
      'employee_code': employeeCode,
      if (days != null) 'days': days.toString(),
      if (beforeDate != null && beforeDate.isNotEmpty) 'before_date': beforeDate,
    };
    final res = await _api.get('/v1/hr/hangs${_qs(qs)}', token: token);
    final raw = (res['data'] as List?) ?? const [];
    return HangsPage(
      items: raw
          .whereType<Map>()
          .map((e) => HangRowItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      hasMore: res['has_more'] == true || res['has_more'] == 1,
      nextCursor: _strOrNull(res['next_cursor']),
      dayCount: (res['day_count'] as num?)?.toInt() ?? 0,
    );
  }

  String _qs(Map<String, String> qs) {
    if (qs.isEmpty) return '';
    return '?${qs.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
  }

  String? _strOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }
}
