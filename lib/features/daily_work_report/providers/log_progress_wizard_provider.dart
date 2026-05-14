import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../auth/providers/auth_provider.dart';
import '../../consumption/models/consumption_models.dart';
import '../../consumption/services/consumption_api.dart';
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

  // Step 3 — uploaded progress photos. Parallel lists, aligned by index:
  // photoPaths[i] is the server-side relative path returned by the upload
  // endpoint, photoUrls[i] is the absolute URL for display, photoFiles[i] is
  // the locally-picked file kept in memory so step 4 can feed it to the AI
  // evaluator without round-tripping through the URL. [XFile] is
  // cross-platform (mobile + web), unlike `dart:io.File`.
  final List<String> photoPaths;
  final List<String> photoUrls;
  final List<XFile> photoFiles;

  // Step 4 — AI evaluation (runs against the most recently uploaded photo).
  final ProgressPhotoEvaluation? evaluation;

  // Optional consumption — BOM lines for the selected BoQ's project. When
  // populated, the worker can fill in qty consumed alongside the progress
  // photo; on commit, a draft consumption session is created.
  final List<ConsumptionLine> consumptionLines;
  final bool consumptionLoaded;

  final bool busy;
  final String? error;

  static const int maxPhotos = 5;

  const LogProgressWizardState({
    this.step = WizardStep.attendance,
    this.tagType = TagType.project,
    this.tagId,
    this.tagLabel,
    this.timeIn = '',
    this.timeOut = '',
    this.tasks = '',
    this.selectedBoq,
    this.photoPaths = const [],
    this.photoUrls = const [],
    this.photoFiles = const [],
    this.evaluation,
    this.consumptionLines = const [],
    this.consumptionLoaded = false,
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
    List<String>? photoPaths,
    List<String>? photoUrls,
    List<XFile>? photoFiles,
    ProgressPhotoEvaluation? evaluation,
    List<ConsumptionLine>? consumptionLines,
    bool? consumptionLoaded,
    bool? busy,
    String? error,
    bool clearError = false,
    bool clearEvaluation = false,
    bool clearPhotos = false,
    bool clearBoq = false,
    bool clearConsumption = false,
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
      photoPaths: clearPhotos ? const [] : (photoPaths ?? this.photoPaths),
      photoUrls: clearPhotos ? const [] : (photoUrls ?? this.photoUrls),
      photoFiles: clearPhotos ? const [] : (photoFiles ?? this.photoFiles),
      evaluation:
          clearEvaluation ? null : (evaluation ?? this.evaluation),
      consumptionLines: clearConsumption
          ? const []
          : (consumptionLines ?? this.consumptionLines),
      consumptionLoaded:
          clearConsumption ? false : (consumptionLoaded ?? this.consumptionLoaded),
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
  bool get photoReady => photoPaths.isNotEmpty;
  bool get evaluationReady => evaluation != null;
  bool get canAddPhoto => photoPaths.length < maxPhotos;
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
    final projectChanged =
        state.selectedBoq?.projectId != item.projectId;
    state = state.copyWith(
      selectedBoq: item,
      tagType: TagType.project,
      tagId: item.projectId?.toString() ?? '',
      tagLabel: item.projectName,
      // Switching BoQ invalidates an old evaluation since the model was scored
      // against the previous label.
      clearEvaluation: true,
      // Picking a different project means the cached BOM no longer applies.
      clearConsumption: projectChanged,
      clearError: true,
    );
  }

  // ─── Step 3 — photo upload ──────────────────────────────────────

  /// Uploads one photo and appends it to the wizard's photo list. Enforces
  /// the max-photos cap and clears the AI evaluation, since a new photo
  /// invalidates a verdict that was scored against the previous last image.
  Future<bool> uploadPhoto(XFile file) async {
    final empId = _employeeId;
    if (empId == null) {
      state = state.copyWith(error: 'No active profile.');
      return false;
    }
    if (!state.canAddPhoto) {
      state = state.copyWith(
        error: 'Up to ${LogProgressWizardState.maxPhotos} photos per entry.',
      );
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
        photoPaths: [...state.photoPaths, res.path],
        photoUrls: [...state.photoUrls, res.url],
        photoFiles: [...state.photoFiles, file],
      );
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Upload failed: $e');
      return false;
    }
  }

  /// Removes the photo at [index] from the wizard's list. Also clears any
  /// existing AI evaluation since it was scored against the prior last photo.
  void removePhoto(int index) {
    if (index < 0 || index >= state.photoPaths.length) return;
    final paths = [...state.photoPaths]..removeAt(index);
    final urls  = [...state.photoUrls]..removeAt(index);
    final files = [...state.photoFiles]..removeAt(index);
    state = state.copyWith(
      photoPaths: paths,
      photoUrls: urls,
      photoFiles: files,
      clearEvaluation: true,
    );
  }

  void clearPhotos() {
    state = state.copyWith(clearPhotos: true, clearEvaluation: true);
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

  // ─── Optional consumption ───────────────────────────────────────

  final ConsumptionApi _consumption = ConsumptionApi();

  /// Fetches BOM lines for the selected BoQ's project from `/consumption/load`.
  /// Safe to call repeatedly — subsequent calls re-load and discard local edits.
  Future<bool> loadConsumptionBom() async {
    final boq = state.selectedBoq;
    final pid = boq?.projectId;
    if (pid == null) {
      state = state.copyWith(error: 'Pick a BoQ item first.');
      return false;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      final bundle = await _consumption.loadFromErp(pid, token: _token);
      state = state.copyWith(
        busy: false,
        consumptionLines: bundle.lines,
        consumptionLoaded: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(busy: false, error: 'Load BOM failed: $e');
      return false;
    }
  }

  void setConsumptionLine(int index, ConsumptionLine next) {
    if (index < 0 || index >= state.consumptionLines.length) return;
    final lines = [
      for (var i = 0; i < state.consumptionLines.length; i++)
        if (i == index) next else state.consumptionLines[i],
    ];
    state = state.copyWith(consumptionLines: lines);
  }

  void clearConsumption() {
    state = state.copyWith(clearConsumption: true);
  }

  /// Filters out lines with no consumption entered — empty rows shouldn't
  /// hit the API and inflate the session.
  List<ConsumptionLine> _nonEmptyConsumptionLines() {
    return state.consumptionLines
        .where((l) => l.consumedQty > 0 || l.locQty > 0 || l.overQty > 0)
        .toList();
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
        photoPaths: state.photoPaths,
        boqItemId: boq.lineId?.toString(),
        boqLabel: boq.itemLabel,
        aiEvaluation: state.evaluation?.evaluation,
        aiVerdict: state.evaluation?.verdict,
        token: _token,
      );

      // Optional: persist a draft consumption session if the worker filled in
      // any BOM lines below the photo grid. Failures here are surfaced but
      // don't roll back the progress entry — the photo report is the primary
      // artifact.
      final filled = _nonEmptyConsumptionLines();
      if (filled.isNotEmpty && boq.projectId != null) {
        try {
          final actor = _read.read(authProvider).user?.name;
          await _consumption.createSession(
            wipProjectId: boq.projectId,
            projectType: 'project',
            updatedBy: actor,
            lines: filled,
            token: _token,
          );
        } catch (e) {
          state = state.copyWith(
            busy: false,
            step: WizardStep.done,
            error: 'Progress saved, but consumption draft failed: $e',
          );
          return null;
        }
      }

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
