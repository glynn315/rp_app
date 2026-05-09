import 'package:image_picker/image_picker.dart' show XFile;

import '../../../core/api/api_client.dart';
import '../models/work_report_models.dart';

/// Thin wrapper over [ApiClient] for the `/v1/work-report/*` endpoints.
class DailyWorkReportApi {
  final ApiClient _api;

  DailyWorkReportApi({ApiClient? client}) : _api = client ?? ApiClient();

  Future<WorkProfile> resolveProfile({required String employeeId, String? token}) async {
    final res = await _api.post(
      '/v1/work-report/auth/resolve',
      {'employee_id': employeeId, 'password': '_'},
      token: token,
    );
    return WorkProfile.fromJson(Map<String, dynamic>.from(res['profile'] as Map));
  }

  Future<Map<String, dynamic>> today({required String employeeId, String? token}) async {
    return _api.get(
      '/v1/work-report/today?employee_id=${Uri.encodeQueryComponent(employeeId)}',
      token: token,
    );
  }

  Future<List<LookupOption>> lookup({
    required String contractType,
    required String tagType,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/work-report/lookup'
      '?contract_type=${Uri.encodeQueryComponent(contractType)}'
      '&tag_type=${Uri.encodeQueryComponent(tagType)}',
      token: token,
    );
    final list = (res['options'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => LookupOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Returns the list of pre-configured task templates for a (tag_type, tag_id)
  /// pair. The block form renders these as tap-to-fill chips above the
  /// free-text tasks textarea.
  Future<List<String>> projectTasks({
    required String tagType,
    required String tagId,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/work-report/project-tasks'
      '?tag_type=${Uri.encodeQueryComponent(tagType)}'
      '&tag_id=${Uri.encodeQueryComponent(tagId)}',
      token: token,
    );
    return ((res['tasks'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  /// Adds a task template under (tag_type, tag_id). Returns the refreshed
  /// list so the caller can swap the chip set without a follow-up GET.
  Future<List<String>> createProjectTask({
    required String tagType,
    required String tagId,
    required String name,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/work-report/project-tasks',
      {'tag_type': tagType, 'tag_id': tagId, 'name': name},
      token: token,
    );
    return ((res['tasks'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  /// Hard-deletes a task template. Returns the refreshed list.
  Future<List<String>> deleteProjectTask({
    required String tagType,
    required String tagId,
    required String name,
    String? token,
  }) async {
    final res = await _api.delete(
      '/v1/work-report/project-tasks',
      body: {'tag_type': tagType, 'tag_id': tagId, 'name': name},
      token: token,
    );
    return ((res['tasks'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  // ─── Admin lookup CRUD ──────────────────────────────────────────────────

  /// Returns ALL lookup rows (active + inactive) for the given tag_type.
  Future<List<Map<String, dynamic>>> adminLookups({
    required String tagType,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/work-report/admin/lookup?tag_type=${Uri.encodeQueryComponent(tagType)}',
      token: token,
    );
    return ((res['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<Map<String, dynamic>> createAdminLookup({
    required String tagType,
    required String code,
    required String name,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/work-report/admin/lookup',
      {'tag_type': tagType, 'code': code, 'name': name},
      token: token,
    );
    return Map<String, dynamic>.from(res['item'] as Map);
  }

  Future<Map<String, dynamic>> updateAdminLookup({
    required String tagType,
    required String id,
    String? code,
    String? name,
    bool? isActive,
    String? token,
  }) async {
    final body = <String, dynamic>{'tag_type': tagType};
    if (code != null) body['code'] = code;
    if (name != null) body['name'] = name;
    if (isActive != null) body['is_active'] = isActive;
    final res = await _api.put(
      '/v1/work-report/admin/lookup/${Uri.encodeComponent(id)}',
      body,
      token: token,
    );
    return Map<String, dynamic>.from(res['item'] as Map);
  }

  Future<AiCheckQuestion> randomAiQuestion({
    required String contractType,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/work-report/ai-check?contract_type=${Uri.encodeQueryComponent(contractType)}',
      token: token,
    );
    return AiCheckQuestion.fromJson(Map<String, dynamic>.from(res));
  }

  Future<void> answerAiCheck({
    required String employeeId,
    required String reportDate,
    required int checkId,
    String? answer,
    required bool skipped,
    String? token,
  }) async {
    await _api.post(
      '/v1/work-report/ai-check/answer',
      {
        'employee_id': employeeId,
        'report_date': reportDate,
        'check_id': checkId,
        'answer': answer,
        'skipped': skipped,
      },
      token: token,
    );
  }

  Future<Map<String, dynamic>> submit({
    required String employeeId,
    required String reportDate,
    required String shiftIn,
    required String shiftOut,
    required List<WorkBlock> blocks,
    Map<String, dynamic>? aiCheck,
    required String dayStatus,
    String? blockerNote,
    String? token,
  }) {
    return _api.post(
      '/v1/work-report/daily',
      {
        'employee_id': employeeId,
        'report_date': reportDate,
        'shift_in': shiftIn,
        'shift_out': shiftOut,
        'blocks': blocks.map((b) => b.toSubmitJson()).toList(),
        'ai_check': aiCheck,
        'day_status': dayStatus,
        'blocker_note': blockerNote,
      },
      token: token,
    );
  }

  /// Uploads one verification photo for a work-block. Returns the relative
  /// `path` (the value the submit payload references in `photo_paths`) and
  /// an absolute `url` for in-app preview.
  ///
  /// Takes an [XFile] (from `image_picker`) so the same code path works on
  /// mobile, desktop, and web — `dart:io.File` is not available on web.
  Future<({String path, String url})> uploadPhoto({
    required XFile file,
    required String employeeId,
    required String reportDate,
    String? token,
  }) async {
    final bytes = await file.readAsBytes();
    final res = await _api.postMultipart(
      '/v1/work-report/photo',
      fields: {
        'employee_id': employeeId,
        'report_date': reportDate,
      },
      fileField: 'photo',
      fileBytes: bytes,
      filename: file.name,
      token: token,
    );
    return (
      path: res['path']?.toString() ?? '',
      url: res['url']?.toString() ?? '',
    );
  }

  /// Persists a single Log-Progress wizard entry as a draft block on the
  /// employee's daily report. Bypasses the biometric attendance + work
  /// profile gates that the full /daily submit endpoint enforces, so the
  /// wizard can save mid-day even when those haven't been registered.
  /// Returns the server-assigned report_id and block_id.
  Future<({String reportId, String blockId})> saveProgressEntry({
    required String employeeId,
    required String reportDate,
    required String timeIn,
    required String timeOut,
    required String tasks,
    required String tagType,
    required String tagId,
    required String tagLabel,
    required List<String> photoPaths,
    String? boqItemId,
    String? boqLabel,
    String? aiEvaluation,
    String? aiVerdict,
    String? token,
  }) async {
    final res = await _api.post(
      '/v1/work-report/progress-entry',
      {
        'employee_id': employeeId,
        'report_date': reportDate,
        'time_in': timeIn,
        'time_out': timeOut,
        'tasks': tasks,
        'tag_type': tagType,
        'tag_id': tagId,
        'tag_label': tagLabel,
        'photo_paths': photoPaths,
        'boq_item_id': ?boqItemId,
        'boq_label': ?boqLabel,
        'ai_evaluation': ?aiEvaluation,
        'ai_verdict': ?aiVerdict,
      },
      token: token,
    );
    return (
      reportId: res['report_id']?.toString() ?? '',
      blockId: res['block_id']?.toString() ?? '',
    );
  }

  /// Asks the server's GPT-4o vision evaluator whether [file] plausibly shows
  /// progress on the chosen BoQ item. Used by the Log-Progress wizard's
  /// step 4 — does not persist anything; the result is attached to the
  /// in-progress work block and only stored on submit.
  Future<ProgressPhotoEvaluation> evaluateProgressPhoto({
    required XFile file,
    required String boqLabel,
    String? projectName,
    String? scopeName,
    String? stageName,
    String? boqItemId,
    String? token,
  }) async {
    final fields = <String, String>{'boq_label': boqLabel};
    if (projectName != null && projectName.isNotEmpty) fields['project_name'] = projectName;
    if (scopeName != null && scopeName.isNotEmpty) fields['scope_name'] = scopeName;
    if (stageName != null && stageName.isNotEmpty) fields['stage_name'] = stageName;
    if (boqItemId != null && boqItemId.isNotEmpty) fields['boq_item_id'] = boqItemId;

    final bytes = await file.readAsBytes();
    final res = await _api.postMultipart(
      '/v1/work-report/progress-photo/evaluate',
      fields: fields,
      fileField: 'photo',
      fileBytes: bytes,
      filename: file.name,
      token: token,
    );
    return ProgressPhotoEvaluation.fromJson(res);
  }

  // ─── BoQ expected-output reference images ───────────────────────────────

  /// Active reference images for [boqItemId]. Field-side endpoint — used by
  /// the BoQ photos screen and the Log-Progress wizard preview.
  Future<List<Map<String, dynamic>>> listBoqOutputUploads({
    required String boqItemId,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/work-report/boq-output-uploads'
      '?boq_item_id=${Uri.encodeQueryComponent(boqItemId)}',
      token: token,
    );
    return ((res['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Admin listing — includes inactive rows.
  Future<List<Map<String, dynamic>>> adminListBoqOutputUploads({
    String? boqItemId,
    String? token,
  }) async {
    final qs = (boqItemId != null && boqItemId.isNotEmpty)
        ? '?boq_item_id=${Uri.encodeQueryComponent(boqItemId)}'
        : '';
    final res = await _api.get(
      '/v1/work-report/admin/boq-output-uploads$qs',
      token: token,
    );
    return ((res['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Uploads a reference image for [boqItemId]. Returns the persisted row
  /// (id, paths, urls, caption, etc.).
  Future<Map<String, dynamic>> createBoqOutputUpload({
    required XFile file,
    required String boqItemId,
    String? boqLabel,
    String? caption,
    String? uploadedBy,
    String? token,
  }) async {
    final fields = <String, String>{'boq_item_id': boqItemId};
    if (boqLabel != null && boqLabel.isNotEmpty) fields['boq_label'] = boqLabel;
    if (caption != null && caption.isNotEmpty) fields['caption'] = caption;
    if (uploadedBy != null && uploadedBy.isNotEmpty) fields['uploaded_by'] = uploadedBy;

    final bytes = await file.readAsBytes();
    final res = await _api.postMultipart(
      '/v1/work-report/admin/boq-output-uploads',
      fields: fields,
      fileField: 'image',
      fileBytes: bytes,
      filename: file.name,
      token: token,
    );
    return Map<String, dynamic>.from(res['item'] as Map);
  }

  /// Deletes a reference image. Default = soft delete (is_active=false);
  /// pass [hard]=true to also remove the file from disk.
  Future<void> deleteBoqOutputUpload({
    required String id,
    bool hard = false,
    String? token,
  }) async {
    final qs = hard ? '?hard=1' : '';
    await _api.delete(
      '/v1/work-report/admin/boq-output-uploads/${Uri.encodeComponent(id)}$qs',
      token: token,
    );
  }

  /// Work-block entries the given employee has logged against [boqItemId].
  /// Newest day first. Each row is the raw JSON shape produced by the
  /// service's `listBoqEntries`, including `report_date`, `time_in`,
  /// `tasks`, `photo_urls`, `ai_verdict`, etc.
  Future<List<Map<String, dynamic>>> listBoqEntries({
    required String employeeId,
    required String boqItemId,
    String? token,
  }) async {
    final res = await _api.get(
      '/v1/work-report/boq-entries'
      '?employee_id=${Uri.encodeQueryComponent(employeeId)}'
      '&boq_item_id=${Uri.encodeQueryComponent(boqItemId)}',
      token: token,
    );
    return ((res['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<CalendarDay>> calendar({
    required String employeeId,
    required DateTime month,
    String? token,
  }) async {
    final m =
        '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';
    final res = await _api.get(
      '/v1/work-report/calendar'
      '?employee_id=${Uri.encodeQueryComponent(employeeId)}'
      '&month=${Uri.encodeQueryComponent(m)}',
      token: token,
    );
    final list = (res['days'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((e) => CalendarDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<String>> unmatched({required String employeeId, String? token}) async {
    final res = await _api.get(
      '/v1/work-report/unmatched?employee_id=${Uri.encodeQueryComponent(employeeId)}',
      token: token,
    );
    return ((res['dates'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
  }

  Future<void> lateMatch({
    required String employeeId,
    required String date,
    required String tagType,
    required String tagId,
    required String tagLabel,
    String? token,
  }) async {
    await _api.post(
      '/v1/work-report/late-match',
      {
        'employee_id': employeeId,
        'date': date,
        'tag_type': tagType,
        'tag_id': tagId,
        'tag_label': tagLabel,
      },
      token: token,
    );
  }
}
