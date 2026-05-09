import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../auth/providers/auth_provider.dart';
import '../../project_management/models/project_management_models.dart';
import '../models/work_report_models.dart';
import '../services/daily_work_report_api.dart';
import 'work_report_provider.dart';

/// Steps of the Log-Progress wizard. Order is also the index in the screen.
enum WizardStep { attendance, boq, photo, evaluation, done }

class LogProgressWizardState {
  final WizardStep step;

  // Step 1 — attendance (just-collected, not yet committed to workReportProvider)
  final String tagType;
  final String? tagId;
  final String? tagLabel;
  final String timeIn;
  final String timeOut;
  final String tasks;

  // Step 2 — BoQ selection
  final BoqItem? selectedBoq;

  // Step 3 — uploaded progress photo
  final String? photoPath;
  final String? photoUrl;
  /// Picked file kept in memory so step 4 can re-feed the same image to the
  /// AI evaluator without round-tripping through the server URL. [XFile] is
  /// cross-platform (mobile + web), unlike `dart:io.File`.
  final XFile? photoFile;

  // Step 4 — AI evaluation
  final ProgressPhotoEvaluation? evaluation;

  final bool busy;
  final String? error;

  const LogProgressWizardState({
    this.step = WizardStep.attendance,
    this.tagType = TagType.project,
    this.tagId,
    this.tagLabel,
    this.timeIn = '',
    this.timeOut = '',
    this.tasks = '',
    this.selectedBoq,
    this.photoPath,
    this.photoUrl,
    this.photoFile,
    this.evaluation,
    this.busy = false,
    this.error,
  });

  LogProgressWizardState copyWith({
    WizardStep? step,
    String? tagType,
    String? tagId,
    String? tagLabel,
    String? timeIn,
    String? timeOut,
    String? tasks,
    BoqItem? selectedBoq,
    String? photoPath,
    String? photoUrl,
    XFile? photoFile,
    ProgressPhotoEvaluation? evaluation,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearEvaluation = false,
    bool clearPhoto = false,
    bool clearBoq = false,
  }) {
    return LogProgressWizardState(
      step: step ?? this.step,
      tagType: tagType ?? this.tagType,
      tagId: tagId ?? this.tagId,
      tagLabel: tagLabel ?? this.tagLabel,
      timeIn: timeIn ?? this.timeIn,
      timeOut: timeOut ?? this.timeOut,
      tasks: tasks ?? this.tasks,
      selectedBoq: clearBoq ? null : (selectedBoq ?? this.selectedBoq),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      photoUrl: clearPhoto ? null : (photoUrl ?? this.photoUrl),
      photoFile: clearPhoto ? null : (photoFile ?? this.photoFile),
      evaluation:
          clearEvaluation ? null : (evaluation ?? this.evaluation),
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }

  /// Step 1 only collects time + tasks now — the project tag is derived from
  /// the BoQ pick in step 2, so tagId is not part of step-1 readiness.
  bool get attendanceReady =>
      timeIn.isNotEmpty &&
      timeOut.isNotEmpty &&
      tasks.trim().isNotEmpty;

  bool get boqReady => selectedBoq != null;
  bool get photoReady => photoPath != null && photoUrl != null;
  bool get evaluationReady => evaluation != null;
}

class LogProgressWizardNotifier
    extends StateNotifier<LogProgressWizardState> {
  LogProgressWizardNotifier(this._api, this._read)
      : super(const LogProgressWizardState());

  final DailyWorkReportApi _api;
  final Ref _read;

  String? get _token => _read.read(authProvider).token;
  String? get _employeeId => _read.read(authProvider).user?.employeeId;

  void reset() => state = const LogProgressWizardState();

  void goTo(WizardStep step) {
    state = state.copyWith(step: step, clearError: true);
  }

  void next() {
    final n = WizardStep.values[state.step.index + 1];
    state = state.copyWith(step: n, clearError: true);
  }

  void back() {
    if (state.step.index == 0) return;
    final p = WizardStep.values[state.step.index - 1];
    state = state.copyWith(step: p, clearError: true);
  }

  // ─── Step 1 — attendance (time + tasks only) ────────────────────

  void setAttendance({
    required String timeIn,
    required String timeOut,
    required String tasks,
  }) {
    state = state.copyWith(
      timeIn: timeIn,
      timeOut: timeOut,
      tasks: tasks,
      clearError: true,
    );
  }

  // ─── Step 2 — BoQ ───────────────────────────────────────────────

  /// Selecting a BoQ item also stamps the work block's project tag — the
  /// wizard no longer asks the worker to pick a project separately, since
  /// the BoQ already names one. tag_type is always 'project' here; tag_id
  /// is the BoQ's projectId (sourced from the WIP replica, so the backend
  /// must skip the local-lookup existence check when boq_item_id is set).
  void setBoq(BoqItem item) {
    state = state.copyWith(
      selectedBoq: item,
      tagType: TagType.project,
      tagId: item.projectId?.toString() ?? '',
      tagLabel: item.projectName,
      // Switching BoQ invalidates an old evaluation since the model was scored
      // against the previous label.
      clearEvaluation: true,
      clearError: true,
    );
  }

  // ─── Step 3 — photo upload ──────────────────────────────────────

  Future<bool> uploadPhoto(XFile file) async {
    final empId = _employeeId;
    if (empId == null) {
      state = state.copyWith(error: 'No active profile.');
      return false;
    }
    state = state.copyWith(busy: true, clearError: true, clearEvaluation: true);
    try {
      final res = await _api.uploadPhoto(
        file: file,
        employeeId: empId,
        reportDate: todayYmd(),
        token: _token,
      );
      state = state.copyWith(
        busy: false,
        photoPath: res.path,
        photoUrl: res.url,
        photoFile: file,
      );
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Upload failed: $e');
      return false;
    }
  }

  void clearPhoto() {
    state = state.copyWith(clearPhoto: true, clearEvaluation: true);
  }

  /// Clears just the AI evaluation result so it can be re-run.
  void clearEvaluation() {
    state = state.copyWith(clearEvaluation: true);
  }

  // ─── Step 4 — AI evaluation ─────────────────────────────────────

  Future<bool> runEvaluation(XFile file) async {
    final boq = state.selectedBoq;
    if (boq == null) {
      state = state.copyWith(error: 'No BoQ item selected.');
      return false;
    }
    // Some BoQ rows from the WIP replica have a blank `item_label`; the list
    // UI shows '—' in that case. The eval endpoint requires a non-empty
    // boq_label, so fall back to a join of whatever metadata IS present.
    final fallbackParts = [
      boq.lineKind,
      boq.scopeName,
      boq.stageName,
    ].where((s) => s.isNotEmpty).toList();
    final boqLabel = boq.itemLabel.isNotEmpty
        ? boq.itemLabel
        : (fallbackParts.isNotEmpty ? fallbackParts.join(' · ') : 'BoQ item');
    state = state.copyWith(busy: true, clearError: true, clearEvaluation: true);
    try {
      final ev = await _api.evaluateProgressPhoto(
        file: file,
        boqLabel: boqLabel,
        projectName: boq.projectName,
        scopeName: boq.scopeName,
        stageName: boq.stageName,
        boqItemId: boq.lineId?.toString(),
        token: _token,
      );
      state = state.copyWith(busy: false, evaluation: ev);
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Evaluation failed: $e');
      return false;
    }
  }

  // ─── Finish ─────────────────────────────────────────────────────

  /// Persists the wizard's collected data via the dedicated progress-entry
  /// endpoint. Returns null on success or an error message to surface in the
  /// UI. The endpoint creates/finds a draft daily report and appends the
  /// block — it does NOT require biometric attendance or a registered work
  /// profile, so the wizard works on devices where dashboard detection
  /// never completed.
  Future<String?> commitProgress() async {
    if (!state.attendanceReady) return 'Attendance is incomplete.';
    if (!state.boqReady) return 'No BoQ item selected.';
    if (!state.photoReady) return 'No progress photo uploaded.';

    final boq = state.selectedBoq!;
    final tagId = state.tagId;
    final tagLabel = state.tagLabel;
    if (tagId == null || tagId.isEmpty || tagLabel == null) {
      return 'Selected BoQ item has no project — pick another item.';
    }

    // Basic time-ordering check. Shift-bounds enforcement is the backend's
    // job (and is skipped on this endpoint by design).
    final tIn = hhmmToMinutes(state.timeIn);
    final tOut = hhmmToMinutes(state.timeOut);
    if (tOut - tIn < 1) {
      return 'Time-out must be at least 1 minute after time-in.';
    }

    final empId = _employeeId;
    if (empId == null) return 'No active session.';

    state = state.copyWith(busy: true, clearError: true);
    try {
      await _api.saveProgressEntry(
        employeeId: empId,
        reportDate: todayYmd(),
        timeIn: state.timeIn,
        timeOut: state.timeOut,
        tasks: state.tasks.trim(),
        tagType: state.tagType,
        tagId: tagId,
        tagLabel: tagLabel,
        photoPaths: [state.photoPath!],
        boqItemId: boq.lineId?.toString(),
        boqLabel: boq.itemLabel,
        aiEvaluation: state.evaluation?.evaluation,
        aiVerdict: state.evaluation?.verdict,
        token: _token,
      );
      state = state.copyWith(busy: false, step: WizardStep.done);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Save failed: $e');
      return 'Save failed: $e';
    }
  }
}

final logProgressWizardProvider = StateNotifierProvider<
    LogProgressWizardNotifier, LogProgressWizardState>((ref) {
  return LogProgressWizardNotifier(
    ref.read(dailyWorkReportApiProvider),
    ref,
  );
});
