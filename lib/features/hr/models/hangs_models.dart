/// Shape returned by GET /v1/hr/hangs. Each row is one contiguous TAPS
/// interval the employee didn't log work against, paired with the DWR day
/// it falls on. Mirrors the web mobile HangRowItem / HangsPage.
class HangRowItem {
  final String date; // yyyy-MM-dd
  final String timeIn; // HH:mm
  final String timeOut; // HH:mm
  final int minutes;
  final String period; // 'AM' | 'PM'
  /// Why this interval is "hang":
  ///  - 'idle'    → TAPS shows clocked in but no DWR task claimed it.
  ///  - 'no_taps' → A DWR task claims this time but no TAPS pair backs it
  ///                (e.g., TAPS hasn't synced for the day yet).
  final String kind; // 'idle' | 'no_taps'

  const HangRowItem({
    required this.date,
    required this.timeIn,
    required this.timeOut,
    required this.minutes,
    required this.period,
    required this.kind,
  });

  bool get isNoTaps => kind == 'no_taps';

  factory HangRowItem.fromJson(Map<String, dynamic> j) {
    String s(dynamic v, [String fb = '']) => v?.toString() ?? fb;
    int n(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final rawKind = s(j['kind']).toLowerCase();
    final kind = (rawKind == 'idle' || rawKind == 'no_taps') ? rawKind : 'idle';
    final rawPeriod = s(j['period']).toUpperCase();
    final period = (rawPeriod == 'AM' || rawPeriod == 'PM') ? rawPeriod : 'AM';

    return HangRowItem(
      date: s(j['date']),
      timeIn: s(j['time_in']),
      timeOut: s(j['time_out']),
      minutes: n(j['minutes']),
      period: period,
      kind: kind,
    );
  }
}

class HangsPage {
  final List<HangRowItem> items;
  final bool hasMore;
  final String? nextCursor;
  final int dayCount;

  const HangsPage({
    required this.items,
    required this.hasMore,
    required this.nextCursor,
    required this.dayCount,
  });
}
