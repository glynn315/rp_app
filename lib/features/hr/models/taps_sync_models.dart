/// Shape returned by GET /v1/hr/taps-sync. Backed by ta_employee_raw_logs
/// (TAPS replica, db4). Mirrors the web mobile TapsRawLog / TapsSyncPage.
class TapsRawLog {
  final int id;
  final String? timeLogged; // 'yyyy-MM-dd HH:mm:ss'
  final String logType; // 'IN' | 'OUT' | ''
  final bool isMatched;
  final bool isOvertime;
  final int? deviceId;

  const TapsRawLog({
    required this.id,
    required this.timeLogged,
    required this.logType,
    required this.isMatched,
    required this.isOvertime,
    required this.deviceId,
  });

  factory TapsRawLog.fromJson(Map<String, dynamic> j) {
    int? intOrNull(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    bool asBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().toLowerCase();
      return s == '1' || s == 'true';
    }

    String? strOrNull(dynamic v) {
      if (v == null) return null;
      final s = v.toString();
      return s.isEmpty ? null : s;
    }

    return TapsRawLog(
      id: intOrNull(j['ta_employee_raw_logs_id']) ?? 0,
      timeLogged: strOrNull(j['time_logged']),
      logType: (j['log_type']?.toString() ?? '').toUpperCase(),
      isMatched: asBool(j['is_matched']),
      isOvertime: asBool(j['is_overtime']),
      deviceId: intOrNull(j['ta_i_device_id']),
    );
  }

  /// `yyyy-MM-dd` portion of `timeLogged`. Empty string for unknown.
  String get dayKey {
    final t = timeLogged;
    if (t == null || t.isEmpty) return '';
    final space = t.indexOf(' ');
    return space < 0 ? t : t.substring(0, space);
  }

  /// `HH:mm` portion of `timeLogged`. Empty for unknown.
  String get timeOfDay {
    final t = timeLogged;
    if (t == null || t.isEmpty) return '';
    final space = t.indexOf(' ');
    if (space < 0) return '';
    final after = t.substring(space + 1);
    return after.length >= 5 ? after.substring(0, 5) : after;
  }
}

class TapsSyncPage {
  final List<TapsRawLog> items;
  final bool hasMore;
  final String? nextCursor; // 'yyyy-MM-dd' — pass as beforeDate next time
  final int dayCount;

  const TapsSyncPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
    required this.dayCount,
  });
}
