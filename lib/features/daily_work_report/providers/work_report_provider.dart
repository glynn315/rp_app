import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/work_report_models.dart';
import '../services/daily_work_report_api.dart';

// ─────────────────────────────────────────────────────────
// Time helpers
// ─────────────────────────────────────────────────────────

int hhmmToMinutes(String v) {
  final parts = v.split(':');
  if (parts.length < 2) return 0;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  return h * 60 + m;
}

String minutesToHHmm(int m) {
  m = m.clamp(0, 24 * 60 - 1);
  final h = m ~/ 60;
  final mm = m % 60;
  return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

String formatHours(int minutes) {
  final h = minutes / 60.0;
  return '${h.toStringAsFixed(1)} hrs';
}

String todayYmd([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────
// Detection / profile state
// ─────────────────────────────────────────────────────────

enum DetectStep { idle, authenticating, fetchingProfile, detectingContract, loadingProjects, checkingAttendance, done, failed }

class WorkReportState {
  final DetectStep detectStep;
  final WorkProfile? profile;
  final String? error;
  final bool submitting;
  final bool submitted;

  final List<WorkBlock> blocks;
  final AiCheckState aiCheck;
  final String? dayStatus;
  final String blockerNote;
  final Map<String, String> blockErrors; // keyed by localId / form-field name

  /// Set after the dashboard has fetched the day's snapshot at least once.
  /// Used to skip the detection animation on re-entry to /work-report.
  final bool todayLoaded;

  const WorkReportState({
    this.detectStep = DetectStep.idle,
    this.profile,
    this.error,
    this.submitting = false,
    this.submitted = false,
    this.blocks = const [],
    this.aiCheck = const AiCheckState(),
    this.dayStatus,
    this.blockerNote = '',
    this.blockErrors = const {},
    this.todayLoaded = false,
  });

  WorkReportState copyWith({
    DetectStep? detectStep,
    WorkProfile? profile,
    String? error,
    bool? submitting,
    bool? submitted,
    List<WorkBlock>? blocks,
    AiCheckState? aiCheck,
    String? dayStatus,
    String? blockerNote,
    Map<String, String>? blockErrors,
    bool? todayLoaded,
    bool clearError = false,
    bool clearProfile = false,
    bool clearDayStatus = false,
  }) {
    return WorkReportState(
      detectStep: detectStep ?? this.detectStep,
      profile: clearProfile ? null : (profile ?? this.profile),
      error: clearError ? null : (error ?? this.error),
      submitting: submitting ?? this.submitting,
      submitted: submitted ?? this.submitted,
      blocks: blocks ?? this.blocks,
      aiCheck: aiCheck ?? this.aiCheck,
      dayStatus: clearDayStatus ? null : (dayStatus ?? this.dayStatus),
      blockerNote: blockerNote ?? this.blockerNote,
      blockErrors: blockErrors ?? this.blockErrors,
      todayLoaded: todayLoaded ?? this.todayLoaded,
    );
  }

  int get allocatedMinutes {
    var total = 0;
    for (final b in blocks) {
      total += hhmmToMinutes(b.timeOut) - hhmmToMinutes(b.timeIn);
    }
    return total < 0 ? 0 : total;
  }

  int get shiftMinutes {
    final shift = profile?.shift;
    if (shift == null) return 0;
    final s = hhmmToMinutes(shift.timeOut) - hhmmToMinutes(shift.timeIn);
    return s < 0 ? 0 : s;
  }

  int get unallocatedMinutes => (shiftMinutes - allocatedMinutes).clamp(0, shiftMinutes);

  /// Sorted ascending by time_in (does not mutate state).
  List<WorkBlock> get sortedBlocks {
    final list = [...blocks];
    list.sort((a, b) => hhmmToMinutes(a.timeIn).compareTo(hhmmToMinutes(b.timeIn)));
    return list;
  }

  List<GapInfo> get gaps {
    final shift = profile?.shift;
    if (shift == null) return const [];
    final out = <GapInfo>[];
    var cursor = hhmmToMinutes(shift.timeIn);
    final endM = hhmmToMinutes(shift.timeOut);
    for (final b in sortedBlocks) {
      final tIn = hhmmToMinutes(b.timeIn);
      final gap = tIn - cursor;
      if (gap > 2) {
        out.add(GapInfo(from: minutesToHHmm(cursor), to: b.timeIn, minutes: gap));
      }
      cursor = hhmmToMinutes(b.timeOut);
    }
    final tail = endM - cursor;
    if (tail > 2) {
      out.add(GapInfo(from: minutesToHHmm(cursor), to: shift.timeOut, minutes: tail));
    }
    return out;
  }

  bool get canSubmit {
    if (profile?.shift == null) return false;
    if (blocks.isEmpty) return false;
    if (dayStatus == null) return false;
    if (dayStatus == DayStatus.blocked && blockerNote.trim().isEmpty) return false;
    for (final b in blocks) {
      if (b.tasks.trim().isEmpty) return false;
    }
    return true;
  }
}

// ─────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────

class WorkReportNotifier extends StateNotifier<WorkReportState> {
  WorkReportNotifier(this._api, this._read) : super(const WorkReportState());

  final DailyWorkReportApi _api;
  final Ref _read;

  String? get _token => _read.read(authProvider).token;

  // ─── Today bootstrap (called from dashboard on login) ────────────────
  //
  // Single round-trip that returns profile + any existing report for today.
  // Idempotent: short-circuits if already loaded. Used to populate the
  // dashboard CTA without showing the multi-step Detect animation.

  Future<void> loadToday({required String employeeId, bool force = false}) async {
    if (!force && state.todayLoaded && state.detectStep == DetectStep.done) return;

    state = state.copyWith(
      detectStep: DetectStep.fetchingProfile,
      clearError: true,
    );
    try {
      final res = await _api.today(employeeId: employeeId, token: _token);

      final profileMap = (res['profile'] is Map)
          ? Map<String, dynamic>.from(res['profile'] as Map)
          : <String, dynamic>{};
      final profile = WorkProfile.fromJson(profileMap);

      final reportMap = res['report'] is Map
          ? Map<String, dynamic>.from(res['report'] as Map)
          : null;
      final isSubmitted = reportMap != null && reportMap['status'] == 'submitted';

      state = state.copyWith(
        detectStep: DetectStep.done,
        profile: profile,
        submitted: isSubmitted,
        todayLoaded: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(detectStep: DetectStep.failed, error: e.message);
    } catch (e) {
      state = state.copyWith(detectStep: DetectStep.failed, error: e.toString());
    }
  }

  // ─── Detection (animated, used as fallback when entering /work-report
  //              cold without the dashboard pre-loading) ────────────────

  Future<void> runDetection({required String employeeId}) async {
    // Already loaded via dashboard? Show the green-checks completion instantly
    // by stepping through DetectSteps without network calls.
    if (state.detectStep == DetectStep.done && state.todayLoaded) return;

    state = state.copyWith(detectStep: DetectStep.authenticating, clearError: true);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    try {
      state = state.copyWith(detectStep: DetectStep.fetchingProfile);
      final profile = await _api.resolveProfile(employeeId: employeeId, token: _token);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      state = state.copyWith(detectStep: DetectStep.detectingContract, profile: profile);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      state = state.copyWith(detectStep: DetectStep.loadingProjects);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      state = state.copyWith(detectStep: DetectStep.checkingAttendance);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      state = state.copyWith(detectStep: DetectStep.done, todayLoaded: true);
    } on ApiException catch (e) {
      state = state.copyWith(detectStep: DetectStep.failed, error: e.message);
    } catch (e) {
      state = state.copyWith(detectStep: DetectStep.failed, error: e.toString());
    }
  }

  void resetDetection() {
    state = const WorkReportState();
  }

  // ─── Block CRUD (local edit state) ───────────────────

  void addBlock(WorkBlock block) {
    state = state.copyWith(
      blocks: [...state.blocks, block],
      blockErrors: const {},
    );
    _maybeFetchAiCheck();
  }

  void updateBlock(String localId, WorkBlock updated) {
    state = state.copyWith(
      blocks: state.blocks.map((b) => b.localId == localId ? updated : b).toList(),
      blockErrors: const {},
    );
  }

  void removeBlock(String localId) {
    state = state.copyWith(
      blocks: state.blocks.where((b) => b.localId != localId).toList(),
    );
  }

  /// Uploads a verification photo using the active profile's employee_id and
  /// today's date. Returns `(path, url)` so the caller can append it to
  /// whichever block (saved or in-form) is being edited. Throws on failure
  /// so the UI can surface the message.
  ///
  /// Takes an [XFile] from `image_picker` so the same code path works on
  /// mobile, desktop, and web (`dart:io.File` is unavailable on web).
  Future<({String path, String url})> uploadVerificationPhoto(XFile file) async {
    final empId = state.profile?.employeeId;
    if (empId == null) {
      throw const FormatException('No active employee profile.');
    }
    return _api.uploadPhoto(
      file: file,
      employeeId: empId,
      reportDate: todayYmd(),
      token: _token,
    );
  }

  /// Uploads a verification photo and appends it to the block matching
  /// [localId] in the provider's blocks list. Throws on upload failure so
  /// the UI can surface the message. Caller is expected to enforce the
  /// per-block photo cap (5).
  Future<void> addPhotoToBlock({
    required String localId,
    required XFile file,
  }) async {
    final result = await uploadVerificationPhoto(file);
    state = state.copyWith(
      blocks: state.blocks.map((b) {
        if (b.localId != localId) return b;
        return b.copyWith(
          photoPaths: [...b.photoPaths, result.path],
          photoUrls: [...b.photoUrls, result.url],
        );
      }).toList(),
    );
  }

  /// Removes one photo from a block (local state only — orphaned files on
  /// the server are swept by a separate housekeeping job, not here).
  void removePhotoFromBlock({
    required String localId,
    required String path,
  }) {
    state = state.copyWith(
      blocks: state.blocks.map((b) {
        if (b.localId != localId) return b;
        final idx = b.photoPaths.indexOf(path);
        if (idx < 0) return b;
        final paths = [...b.photoPaths]..removeAt(idx);
        final urls = [...b.photoUrls];
        if (idx < urls.length) urls.removeAt(idx);
        return b.copyWith(photoPaths: paths, photoUrls: urls);
      }).toList(),
    );
  }

  /// Validates a candidate block against the spec rules. Returns null on
  /// success, or a field-keyed error message on failure.
  String? validateBlock(WorkBlock candidate, {String? excludingLocalId}) {
    final shift = state.profile?.shift;
    if (shift == null) return 'No shift anchors available.';

    if (candidate.tasks.trim().isEmpty) return 'Tasks description is required.';

    final tIn = hhmmToMinutes(candidate.timeIn);
    final tOut = hhmmToMinutes(candidate.timeOut);
    final sIn = hhmmToMinutes(shift.timeIn);
    final sOut = hhmmToMinutes(shift.timeOut);

    if (tOut - tIn < 1) return 'Time-out must be at least 1 minute after time-in.';
    if (tIn < sIn) return 'Time-in is before shift start (${shift.timeIn}).';
    if (tOut > sOut) return 'Time-out is after shift end (${shift.timeOut}).';

    final others = state.blocks.where((b) => b.localId != excludingLocalId);
    for (final o in others) {
      final oIn = hhmmToMinutes(o.timeIn);
      final oOut = hhmmToMinutes(o.timeOut);
      // overlap if not (tOut <= oIn || tIn >= oOut)
      if (!(tOut <= oIn || tIn >= oOut)) {
        return 'Block overlaps with ${o.timeIn}–${o.timeOut} (${o.tagLabel}).';
      }
    }
    return null;
  }

  /// Suggests time defaults for a NEW block: starts at the end of the last
  /// block (or shift start), runs 3 hours, capped at shift end.
  ({String timeIn, String timeOut}) suggestTimes() {
    final shift = state.profile?.shift;
    if (shift == null) return (timeIn: '08:00', timeOut: '11:00');
    int startM;
    if (state.blocks.isEmpty) {
      startM = hhmmToMinutes(shift.timeIn);
    } else {
      final last = [...state.blocks]..sort(
          (a, b) => hhmmToMinutes(a.timeOut).compareTo(hhmmToMinutes(b.timeOut)));
      startM = hhmmToMinutes(last.last.timeOut);
    }
    final endM = hhmmToMinutes(shift.timeOut);
    final endSuggest = (startM + 180).clamp(startM + 1, endM);
    return (timeIn: minutesToHHmm(startM), timeOut: minutesToHHmm(endSuggest));
  }

  // ─── Day status / blocker ────────────────────────────

  void setDayStatus(String status) {
    state = state.copyWith(dayStatus: status);
  }

  void setBlockerNote(String note) {
    state = state.copyWith(blockerNote: note);
  }

  // ─── AI check ────────────────────────────────────────

  Future<void> _maybeFetchAiCheck() async {
    if (state.aiCheck.question != null) return;
    if (state.blocks.length != 1) return;
    final contract = state.profile?.contractType;
    if (contract == null) return;
    try {
      final q = await _api.randomAiQuestion(contractType: contract, token: _token);
      state = state.copyWith(aiCheck: state.aiCheck.copyWith(question: q));
    } on ApiException catch (e) {
      // Non-fatal — just log
      debugPrint('AI check fetch failed: ${e.message}');
    }
  }

  void setAiAnswer(String text) {
    state = state.copyWith(aiCheck: state.aiCheck.copyWith(answer: text));
  }

  Future<void> submitAiAnswer() async {
    final q = state.aiCheck.question;
    if (q == null) return;
    final empId = state.profile?.employeeId;
    if (empId == null) return;
    try {
      await _api.answerAiCheck(
        employeeId: empId,
        reportDate: todayYmd(),
        checkId: q.checkId,
        answer: state.aiCheck.answer,
        skipped: false,
        token: _token,
      );
      state = state.copyWith(aiCheck: state.aiCheck.copyWith(outcome: AiCheckOutcome.answered));
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> skipAiAnswer() async {
    final q = state.aiCheck.question;
    if (q == null) return;
    final empId = state.profile?.employeeId;
    if (empId == null) return;
    try {
      await _api.answerAiCheck(
        employeeId: empId,
        reportDate: todayYmd(),
        checkId: q.checkId,
        answer: null,
        skipped: true,
        token: _token,
      );
      state = state.copyWith(aiCheck: state.aiCheck.copyWith(outcome: AiCheckOutcome.skipped));
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  // ─── Submit ──────────────────────────────────────────

  Future<bool> submit() async {
    if (!state.canSubmit) return false;
    final shift = state.profile!.shift!;
    final empId = state.profile!.employeeId;

    state = state.copyWith(submitting: true, clearError: true);
    try {
      final aiPayload = state.aiCheck.question == null
          ? null
          : {
              'check_id': state.aiCheck.question!.checkId,
              'answer': state.aiCheck.outcome == AiCheckOutcome.skipped ? null : state.aiCheck.answer,
              'skipped': state.aiCheck.outcome == AiCheckOutcome.skipped,
            };
      await _api.submit(
        employeeId: empId,
        reportDate: todayYmd(),
        shiftIn: shift.timeIn,
        shiftOut: shift.timeOut,
        blocks: state.sortedBlocks,
        aiCheck: aiPayload,
        dayStatus: state.dayStatus!,
        blockerNote: state.dayStatus == DayStatus.blocked ? state.blockerNote : null,
        token: _token,
      );
      state = state.copyWith(submitting: false, submitted: true);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      return false;
    }
  }
}

// ─────────────────────────────────────────────────────────
// Lookup state — caches dropdown options per (contract, tag_type) pair.
// ─────────────────────────────────────────────────────────

class LookupCache {
  final Map<String, List<LookupOption>> _byKey = {};
  final Map<String, List<String>> _tasksByKey = {};

  String _key(String contract, String tagType) => '$contract:$tagType';
  String _taskKey(String tagType, String tagId) => '$tagType:$tagId';

  List<LookupOption>? get(String contract, String tagType) =>
      _byKey[_key(contract, tagType)];

  void put(String contract, String tagType, List<LookupOption> v) {
    _byKey[_key(contract, tagType)] = v;
  }

  List<String>? getTasks(String tagType, String tagId) =>
      _tasksByKey[_taskKey(tagType, tagId)];

  void putTasks(String tagType, String tagId, List<String> v) {
    _tasksByKey[_taskKey(tagType, tagId)] = v;
  }
}

class LookupNotifier extends StateNotifier<LookupCache> {
  LookupNotifier(this._api, this._read) : super(LookupCache());

  final DailyWorkReportApi _api;
  final Ref _read;

  Future<List<LookupOption>> options({
    required String contractType,
    required String tagType,
  }) async {
    final cached = state.get(contractType, tagType);
    if (cached != null) return cached;
    final token = _read.read(authProvider).token;
    final list = await _api.lookup(contractType: contractType, tagType: tagType, token: token);
    state.put(contractType, tagType, list);
    state = state; // force update
    return list;
  }

  /// Pre-configured task templates for a specific scope (e.g. a project).
  /// Cached by `(tagType, tagId)` so re-opening the same dropdown is free.
  Future<List<String>> tasksFor({
    required String tagType,
    required String tagId,
  }) async {
    if (tagId.isEmpty) return const [];
    final cached = state.getTasks(tagType, tagId);
    if (cached != null) return cached;
    final token = _read.read(authProvider).token;
    final list = await _api.projectTasks(tagType: tagType, tagId: tagId, token: token);
    state.putTasks(tagType, tagId, list);
    state = state; // force update
    return list;
  }

  /// Adds a new task template under (tagType, tagId), refreshes the cache
  /// from the server's authoritative list, and returns it so callers can
  /// re-render chips synchronously.
  Future<List<String>> createTask({
    required String tagType,
    required String tagId,
    required String name,
  }) async {
    final token = _read.read(authProvider).token;
    final list = await _api.createProjectTask(
      tagType: tagType,
      tagId: tagId,
      name: name,
      token: token,
    );
    state.putTasks(tagType, tagId, list);
    state = state; // force update
    return list;
  }

  /// Drops cached dropdown options for a tag_type so the next `options()` call
  /// re-fetches. Called by the admin notifier after lookup CRUD.
  void invalidate({String? tagType}) {
    if (tagType == null) {
      state._byKey.clear();
    } else {
      state._byKey.removeWhere((k, _) => k.endsWith(':$tagType'));
    }
    state = state;
  }

  /// Drops cached task list for a (tagType, tagId) so the next `tasksFor()`
  /// call re-fetches.
  void invalidateTasks({required String tagType, required String tagId}) {
    state._tasksByKey.remove('$tagType:$tagId');
    state = state;
  }
}

// ─────────────────────────────────────────────────────────
// Calendar / unmatched state
// ─────────────────────────────────────────────────────────

class CalendarState {
  final DateTime month;
  final List<CalendarDay> days;
  final List<String> unmatchedDates;
  final bool loading;
  final String? error;

  CalendarState({
    DateTime? month,
    this.days = const [],
    this.unmatchedDates = const [],
    this.loading = false,
    this.error,
  }) : month = month ?? DateTime(DateTime.now().year, DateTime.now().month, 1);

  CalendarState copyWith({
    DateTime? month,
    List<CalendarDay>? days,
    List<String>? unmatchedDates,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return CalendarState(
      month: month ?? this.month,
      days: days ?? this.days,
      unmatchedDates: unmatchedDates ?? this.unmatchedDates,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CalendarNotifier extends StateNotifier<CalendarState> {
  CalendarNotifier(this._api, this._read) : super(CalendarState());

  final DailyWorkReportApi _api;
  final Ref _read;

  Future<void> load(String employeeId) async {
    state = state.copyWith(loading: true, clearError: true);
    final token = _read.read(authProvider).token;
    try {
      final days = await _api.calendar(employeeId: employeeId, month: state.month, token: token);
      final unmatched = await _api.unmatched(employeeId: employeeId, token: token);
      state = state.copyWith(loading: false, days: days, unmatchedDates: unmatched);
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> shiftMonth(int delta, String employeeId) async {
    state = state.copyWith(month: DateTime(state.month.year, state.month.month + delta, 1));
    await load(employeeId);
  }

  Future<void> lateMatch({
    required String employeeId,
    required String date,
    required String tagType,
    required String tagId,
    required String tagLabel,
  }) async {
    final token = _read.read(authProvider).token;
    await _api.lateMatch(
      employeeId: employeeId,
      date: date,
      tagType: tagType,
      tagId: tagId,
      tagLabel: tagLabel,
      token: token,
    );
    await load(employeeId);
  }
}

// ─────────────────────────────────────────────────────────
// Riverpod providers
// ─────────────────────────────────────────────────────────

final dailyWorkReportApiProvider = Provider<DailyWorkReportApi>((ref) => DailyWorkReportApi());

final workReportProvider =
    StateNotifierProvider<WorkReportNotifier, WorkReportState>((ref) {
  return WorkReportNotifier(ref.read(dailyWorkReportApiProvider), ref);
});

final lookupProvider = StateNotifierProvider<LookupNotifier, LookupCache>((ref) {
  return LookupNotifier(ref.read(dailyWorkReportApiProvider), ref);
});

final calendarProvider =
    StateNotifierProvider<CalendarNotifier, CalendarState>((ref) {
  return CalendarNotifier(ref.read(dailyWorkReportApiProvider), ref);
});

// ─────────────────────────────────────────────────────────
// Lookups admin (manage projects / job orders / departments / admin projects
// + their tasks). All four tag types visible to all users — no role gating
// while the UX is being shaken out.
// ─────────────────────────────────────────────────────────

class LookupAdminItem {
  final String id;
  final String code;
  final String name;
  final bool isActive;

  const LookupAdminItem({
    required this.id,
    required this.code,
    required this.name,
    required this.isActive,
  });

  factory LookupAdminItem.fromJson(Map<String, dynamic> j) => LookupAdminItem(
        id: (j['id'] ?? '').toString(),
        code: (j['code'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        isActive: j['is_active'] == true,
      );

  LookupAdminItem copyWith({String? code, String? name, bool? isActive}) =>
      LookupAdminItem(
        id: id,
        code: code ?? this.code,
        name: name ?? this.name,
        isActive: isActive ?? this.isActive,
      );
}

class LookupsAdminState {
  /// Per-tag-type list of items.
  final Map<String, List<LookupAdminItem>> items;

  /// Per-(tagType, tagId) cached task list — populated lazily as the user
  /// expands an item.
  final Map<String, List<String>> tasks;

  /// Per-tag-type loading flag.
  final Map<String, bool> loading;

  /// Per-tag-type error text.
  final Map<String, String?> error;

  const LookupsAdminState({
    this.items = const {},
    this.tasks = const {},
    this.loading = const {},
    this.error = const {},
  });

  LookupsAdminState copyWith({
    Map<String, List<LookupAdminItem>>? items,
    Map<String, List<String>>? tasks,
    Map<String, bool>? loading,
    Map<String, String?>? error,
  }) {
    return LookupsAdminState(
      items: items ?? this.items,
      tasks: tasks ?? this.tasks,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }

  static String taskKey(String tagType, String tagId) => '$tagType:$tagId';
}

class LookupsAdminNotifier extends StateNotifier<LookupsAdminState> {
  LookupsAdminNotifier(this._api, this._read) : super(const LookupsAdminState());

  final DailyWorkReportApi _api;
  final Ref _read;

  String? get _token => _read.read(authProvider).token;

  Future<void> load(String tagType) async {
    state = state.copyWith(
      loading: {...state.loading, tagType: true},
      error: {...state.error, tagType: null},
    );
    try {
      final raw = await _api.adminLookups(tagType: tagType, token: _token);
      final list = raw.map(LookupAdminItem.fromJson).toList();
      state = state.copyWith(
        items: {...state.items, tagType: list},
        loading: {...state.loading, tagType: false},
      );
    } catch (e) {
      state = state.copyWith(
        loading: {...state.loading, tagType: false},
        error: {...state.error, tagType: e.toString()},
      );
    }
  }

  Future<bool> create(String tagType, String code, String name) async {
    try {
      final raw = await _api.createAdminLookup(
        tagType: tagType,
        code: code,
        name: name,
        token: _token,
      );
      final item = LookupAdminItem.fromJson(raw);
      final next = [...?state.items[tagType], item]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = state.copyWith(items: {...state.items, tagType: next});
      // Bust the worker-side dropdown cache for this tag type.
      _read.read(lookupProvider.notifier).invalidate(tagType: tagType);
      return true;
    } catch (e) {
      state = state.copyWith(error: {...state.error, tagType: e.toString()});
      return false;
    }
  }

  Future<bool> update(
    String tagType,
    String id, {
    String? code,
    String? name,
    bool? isActive,
  }) async {
    try {
      final raw = await _api.updateAdminLookup(
        tagType: tagType,
        id: id,
        code: code,
        name: name,
        isActive: isActive,
        token: _token,
      );
      final updated = LookupAdminItem.fromJson(raw);
      final next = (state.items[tagType] ?? const <LookupAdminItem>[])
          .map((i) => i.id == id ? updated : i)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      state = state.copyWith(items: {...state.items, tagType: next});
      _read.read(lookupProvider.notifier).invalidate(tagType: tagType);
      return true;
    } catch (e) {
      state = state.copyWith(error: {...state.error, tagType: e.toString()});
      return false;
    }
  }

  /// Lazily loads tasks for a (tagType, tagId) into the admin cache.
  Future<List<String>> loadTasks(String tagType, String tagId) async {
    final key = LookupsAdminState.taskKey(tagType, tagId);
    final cached = state.tasks[key];
    if (cached != null) return cached;
    final list = await _api.projectTasks(tagType: tagType, tagId: tagId, token: _token);
    state = state.copyWith(tasks: {...state.tasks, key: list});
    return list;
  }

  Future<bool> addTask(String tagType, String tagId, String name) async {
    try {
      final list = await _api.createProjectTask(
        tagType: tagType,
        tagId: tagId,
        name: name,
        token: _token,
      );
      final key = LookupsAdminState.taskKey(tagType, tagId);
      state = state.copyWith(tasks: {...state.tasks, key: list});
      _read.read(lookupProvider.notifier).invalidateTasks(tagType: tagType, tagId: tagId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeTask(String tagType, String tagId, String name) async {
    try {
      final list = await _api.deleteProjectTask(
        tagType: tagType,
        tagId: tagId,
        name: name,
        token: _token,
      );
      final key = LookupsAdminState.taskKey(tagType, tagId);
      state = state.copyWith(tasks: {...state.tasks, key: list});
      _read.read(lookupProvider.notifier).invalidateTasks(tagType: tagType, tagId: tagId);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final lookupsAdminProvider =
    StateNotifierProvider<LookupsAdminNotifier, LookupsAdminState>((ref) {
  return LookupsAdminNotifier(ref.read(dailyWorkReportApiProvider), ref);
});
