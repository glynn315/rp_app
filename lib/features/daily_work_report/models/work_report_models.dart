/// Data classes for the Daily Work Report feature.
///
/// Mirrors the backend's response shapes (Laravel `DailyWorkReportService`).
/// All times are HH:MM strings, all dates are YYYY-MM-DD strings.
library;

class ContractType {
  static const String field = 'field';
  static const String admin = 'admin';
}

class TagType {
  static const String project = 'project';
  static const String jobOrder = 'job_order';
  static const String department = 'department';
  static const String adminProject = 'admin_project';

  /// BOQ scope tag types — mapped to WIP-replica IDs (`wip_i_project_id` and
  /// `wip_i_project_scope_id`). Only valid for task-template CRUD on the
  /// BOQ screens; the work-report block flow still uses the four above.
  static const String wipProject = 'wip_project';
  static const String wipScope = 'wip_scope';

  static const fieldTagTypes = [project, jobOrder];
  static const adminTagTypes = [department, adminProject];

  /// All four tag types in a single list. Used while role separation is
  /// disabled (see `FeatureFlags.roleSeparation`).
  static const allTagTypes = [project, jobOrder, department, adminProject];

  static String labelFor(String value) => switch (value) {
        project => 'Project',
        jobOrder => 'Job Order',
        department => 'Department',
        adminProject => 'Admin Project',
        wipProject => 'Project',
        wipScope => 'Scope',
        _ => value,
      };
}

/// Mirror of the backend `App\Domain\DailyWorkReport\FeatureFlags`.
/// Flip [roleSeparation] to true to re-enable contract-aware tag filtering.
class FeatureFlags {
  static const bool roleSeparation = false;

  /// Tag-type pills to show in block forms / unmatched rows. When role
  /// separation is off every worker sees all four.
  static List<String> tagTypesFor(String contractType) {
    if (!roleSeparation) return TagType.allTagTypes;
    return contractType == ContractType.field
        ? TagType.fieldTagTypes
        : TagType.adminTagTypes;
  }
}

class DayStatus {
  static const String completed = 'completed';
  static const String inProgress = 'in_progress';
  static const String blocked = 'blocked';
}

class WorkProfile {
  final String employeeId;
  final String name;
  final String contractType;
  final String? supervisorId;
  final ShiftAnchors? shift;
  final bool hasAttendanceToday;

  const WorkProfile({
    required this.employeeId,
    required this.name,
    required this.contractType,
    required this.shift,
    this.supervisorId,
    this.hasAttendanceToday = false,
  });

  factory WorkProfile.fromJson(Map<String, dynamic> j) {
    return WorkProfile(
      employeeId: j['employee_id']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      contractType: j['contract_type']?.toString() ?? ContractType.admin,
      supervisorId: j['supervisor_id']?.toString(),
      shift: j['shift'] is Map
          ? ShiftAnchors.fromJson(Map<String, dynamic>.from(j['shift'] as Map))
          : null,
      hasAttendanceToday: j['has_attendance_today'] == true,
    );
  }
}

class ShiftAnchors {
  final String timeIn;
  final String timeOut;

  const ShiftAnchors({required this.timeIn, required this.timeOut});

  factory ShiftAnchors.fromJson(Map<String, dynamic> j) => ShiftAnchors(
        timeIn: j['time_in']?.toString() ?? '00:00',
        timeOut: j['time_out']?.toString() ?? '00:00',
      );
}

class LookupOption {
  final String id;
  final String code;
  final String name;

  const LookupOption({required this.id, required this.code, required this.name});

  factory LookupOption.fromJson(Map<String, dynamic> j) => LookupOption(
        id: j['id']?.toString() ?? '',
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
      );
}

class WorkBlock {
  /// Local UUID-style id for unsaved blocks; replaced by server `block_id` after submit.
  final String localId;
  final String? blockId; // server-assigned UUID
  final String tagType;
  final String tagId;
  final String tagLabel;
  final String timeIn;
  final String timeOut;
  final String tasks;

  /// Server-side relative paths (e.g. `work_report_photos/EMP/2026-05-05/x.jpg`).
  /// These are what we send back on submit.
  final List<String> photoPaths;

  /// Absolute URLs to display in-app. Aligned by index with [photoPaths].
  /// Populated by the upload endpoint and by the server's report response.
  final List<String> photoUrls;

  /// Optional Log-Progress wizard fields. Set when a block is created via the
  /// guided Attendance → BoQ → Photo → AI flow; null on regular block submits.
  final String? boqItemId;
  final String? boqLabel;
  final String? aiEvaluation;

  /// One of 'ok' | 'retake' | 'uncertain' (or null if not evaluated).
  final String? aiVerdict;

  const WorkBlock({
    required this.localId,
    required this.tagType,
    required this.tagId,
    required this.tagLabel,
    required this.timeIn,
    required this.timeOut,
    required this.tasks,
    this.blockId,
    this.photoPaths = const [],
    this.photoUrls = const [],
    this.boqItemId,
    this.boqLabel,
    this.aiEvaluation,
    this.aiVerdict,
  });

  WorkBlock copyWith({
    String? tagType,
    String? tagId,
    String? tagLabel,
    String? timeIn,
    String? timeOut,
    String? tasks,
    List<String>? photoPaths,
    List<String>? photoUrls,
    String? boqItemId,
    String? boqLabel,
    String? aiEvaluation,
    String? aiVerdict,
  }) {
    return WorkBlock(
      localId: localId,
      blockId: blockId,
      tagType: tagType ?? this.tagType,
      tagId: tagId ?? this.tagId,
      tagLabel: tagLabel ?? this.tagLabel,
      timeIn: timeIn ?? this.timeIn,
      timeOut: timeOut ?? this.timeOut,
      tasks: tasks ?? this.tasks,
      photoPaths: photoPaths ?? this.photoPaths,
      photoUrls: photoUrls ?? this.photoUrls,
      boqItemId: boqItemId ?? this.boqItemId,
      boqLabel: boqLabel ?? this.boqLabel,
      aiEvaluation: aiEvaluation ?? this.aiEvaluation,
      aiVerdict: aiVerdict ?? this.aiVerdict,
    );
  }

  factory WorkBlock.fromJson(Map<String, dynamic> j) {
    final paths = (j['photo_paths'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const <String>[];
    final urls = (j['photo_urls'] as List?)
            ?.map((e) => e.toString())
            .toList(growable: false) ??
        const <String>[];
    String? str(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }
    return WorkBlock(
      localId: j['block_id']?.toString() ?? UniqueId.next(),
      blockId: j['block_id']?.toString(),
      tagType: j['tag_type']?.toString() ?? '',
      tagId: j['tag_id']?.toString() ?? '',
      tagLabel: j['tag_label']?.toString() ?? '',
      timeIn: j['time_in']?.toString() ?? '00:00',
      timeOut: j['time_out']?.toString() ?? '00:00',
      tasks: j['tasks']?.toString() ?? '',
      photoPaths: paths,
      photoUrls: urls,
      boqItemId: str(j['boq_item_id']),
      boqLabel: str(j['boq_label']),
      aiEvaluation: str(j['ai_evaluation']),
      aiVerdict: str(j['ai_verdict']),
    );
  }

  Map<String, dynamic> toSubmitJson() => {
        'tag_type': tagType,
        'tag_id': tagId,
        'tag_label': tagLabel,
        'time_in': timeIn,
        'time_out': timeOut,
        'tasks': tasks,
        'photo_paths': photoPaths,
        if (boqItemId != null) 'boq_item_id': boqItemId,
        if (boqLabel != null) 'boq_label': boqLabel,
        if (aiEvaluation != null) 'ai_evaluation': aiEvaluation,
        if (aiVerdict != null) 'ai_verdict': aiVerdict,
      };
}

/// Result of a GPT-4o vision evaluation of a progress photo.
class ProgressPhotoEvaluation {
  /// 'ok' | 'retake' | 'uncertain'
  final String verdict;
  final String evaluation;
  final bool imageClear;

  const ProgressPhotoEvaluation({
    required this.verdict,
    required this.evaluation,
    required this.imageClear,
  });

  factory ProgressPhotoEvaluation.fromJson(Map<String, dynamic> j) =>
      ProgressPhotoEvaluation(
        verdict: j['verdict']?.toString() ?? 'uncertain',
        evaluation: j['evaluation']?.toString() ?? '',
        imageClear: j['image_clear'] == true,
      );
}

class AiCheckQuestion {
  final int checkId;
  final String category;
  final String question;

  const AiCheckQuestion({
    required this.checkId,
    required this.category,
    required this.question,
  });

  factory AiCheckQuestion.fromJson(Map<String, dynamic> j) => AiCheckQuestion(
        checkId: int.tryParse(j['check_id']?.toString() ?? '') ?? 0,
        category: j['category']?.toString() ?? '',
        question: j['question']?.toString() ?? '',
      );
}

enum AiCheckOutcome { unanswered, answered, skipped }

class AiCheckState {
  final AiCheckQuestion? question;
  final String answer;
  final AiCheckOutcome outcome;

  const AiCheckState({
    this.question,
    this.answer = '',
    this.outcome = AiCheckOutcome.unanswered,
  });

  AiCheckState copyWith({
    AiCheckQuestion? question,
    String? answer,
    AiCheckOutcome? outcome,
    bool clearQuestion = false,
  }) {
    return AiCheckState(
      question: clearQuestion ? null : (question ?? this.question),
      answer: answer ?? this.answer,
      outcome: outcome ?? this.outcome,
    );
  }
}

class CalendarDay {
  final DateTime date;
  /// Backend states: 'matched' | 'unmatched' | 'today' | 'inactive'
  final String state;
  final bool isLateMatch;

  const CalendarDay({
    required this.date,
    required this.state,
    this.isLateMatch = false,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
        date: DateTime.parse(j['date']?.toString() ?? '1970-01-01'),
        state: j['state']?.toString() ?? 'inactive',
        isLateMatch: j['is_late_match'] == true,
      );
}

class GapInfo {
  final String from;
  final String to;
  final int minutes;

  const GapInfo({required this.from, required this.to, required this.minutes});
}

/// Lightweight UUID-ish generator without a dependency.
class UniqueId {
  static int _counter = 0;
  static String next() {
    _counter++;
    return 'local-${DateTime.now().microsecondsSinceEpoch}-$_counter';
  }
}
