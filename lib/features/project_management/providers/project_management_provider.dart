import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/project_management_models.dart';
import '../services/project_management_api.dart';

final projectManagementApiProvider = Provider<ProjectManagementApi>(
  (ref) => ProjectManagementApi(),
);

/// Filter state shared by BoQ, WIP, and LMC list screens. Each screen owns
/// its own [StateNotifier] instance so changes to one list don't redraw the
/// others.
class ProjectListFilter {
  final String search;
  final int? projectId;
  final String? status;     // BOQ/WIP project_status, or LMC docstatus
  final String? lineKind;   // BOQ only: BOM | LABOR | MISC | LMC
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const ProjectListFilter({
    this.search = '',
    this.projectId,
    this.status,
    this.lineKind,
    this.dateFrom,
    this.dateTo,
  });

  static const empty = ProjectListFilter();

  bool get isActive =>
      search.isNotEmpty ||
      projectId != null ||
      (status != null && status!.isNotEmpty) ||
      (lineKind != null && lineKind!.isNotEmpty) ||
      dateFrom != null ||
      dateTo != null;

  ProjectListFilter copyWith({
    String? search,
    Object? projectId = _unset,
    Object? status = _unset,
    Object? lineKind = _unset,
    Object? dateFrom = _unset,
    Object? dateTo = _unset,
  }) {
    return ProjectListFilter(
      search: search ?? this.search,
      projectId: projectId == _unset ? this.projectId : projectId as int?,
      status: status == _unset ? this.status : status as String?,
      lineKind: lineKind == _unset ? this.lineKind : lineKind as String?,
      dateFrom: dateFrom == _unset ? this.dateFrom : dateFrom as DateTime?,
      dateTo: dateTo == _unset ? this.dateTo : dateTo as DateTime?,
    );
  }
}

const Object _unset = Object();

class ProjectListFilterController extends StateNotifier<ProjectListFilter> {
  ProjectListFilterController() : super(ProjectListFilter.empty);

  void setSearch(String v) => state = state.copyWith(search: v);
  void setProjectId(int? v) => state = state.copyWith(projectId: v);
  void setStatus(String? v) => state = state.copyWith(status: v);
  void setLineKind(String? v) => state = state.copyWith(lineKind: v);
  void setDateFrom(DateTime? v) => state = state.copyWith(dateFrom: v);
  void setDateTo(DateTime? v) => state = state.copyWith(dateTo: v);
  void reset() => state = ProjectListFilter.empty;
}

/// Per-screen filter controllers.
final boqFilterProvider =
    StateNotifierProvider<ProjectListFilterController, ProjectListFilter>(
  (ref) => ProjectListFilterController(),
);

final wipFilterProvider =
    StateNotifierProvider<ProjectListFilterController, ProjectListFilter>(
  (ref) => ProjectListFilterController(),
);

final lmcFilterProvider =
    StateNotifierProvider<ProjectListFilterController, ProjectListFilter>(
  (ref) => ProjectListFilterController(),
);

/// `wip_i_project_category_id` whitelist for the BOQ screen. Limits the list
/// to the RP-managed categories: RP In-House (2), RP LAND DEV (18), and
/// RP_LAND DEV (19). Add new ids here to widen visibility.
const List<int> kBoqRpCategoryIds = [2, 18, 19];

/// Bill-of-Quantities listing — re-runs whenever the filter or auth token
/// changes. Defaults to the latest BOM/LMC budget per stage server-side.
///
/// Not auto-disposed: when the user pushes the per-row Tasks/Log time screens
/// on top of the list, those siblings can briefly reset the watch graph; an
/// auto-disposed list would refetch and flash empty on return.
final boqListProvider =
    FutureProvider<List<BoqItem>>((ref) async {
  final api = ref.watch(projectManagementApiProvider);
  final token = ref.watch(authProvider).token;
  final f = ref.watch(boqFilterProvider);
  return api.boqList(
    token: token,
    projectId: f.projectId,
    status: f.status,
    lineKind: f.lineKind,
    categoryIds: kBoqRpCategoryIds,
    search: f.search,
  );
});

/// Work-in-Progress listing (defaults to status=COMMENCED on the API side).
final wipListProvider =
    FutureProvider.autoDispose<List<WipProject>>((ref) async {
  final api = ref.watch(projectManagementApiProvider);
  final token = ref.watch(authProvider).token;
  final f = ref.watch(wipFilterProvider);
  return api.wipList(
    token: token,
    status: f.status,
    projectId: f.projectId,
    dateFrom: f.dateFrom,
    dateTo: f.dateTo,
    search: f.search,
  );
});

/// LMC Payout header listing — defaults to the latest payout per scope.
final lmcPayoutListProvider =
    FutureProvider.autoDispose<List<LmcPayout>>((ref) async {
  final api = ref.watch(projectManagementApiProvider);
  final token = ref.watch(authProvider).token;
  final f = ref.watch(lmcFilterProvider);
  return api.lmcPayoutList(
    token: token,
    docstatus: f.status,
    projectId: f.projectId,
    dateFrom: f.dateFrom,
    dateTo: f.dateTo,
    search: f.search,
  );
});

/// Per-payout line detail, keyed by payout id.
final lmcPayoutDetailProvider = FutureProvider.autoDispose
    .family<List<LmcPayoutLine>, int>((ref, payoutId) async {
  final api = ref.watch(projectManagementApiProvider);
  final token = ref.watch(authProvider).token;
  return api.lmcPayoutDetail(payoutId, token: token);
});

/// Mandays-matching run listing.
final mandaysRunsProvider =
    FutureProvider.autoDispose<List<MandaysMatchingRun>>((ref) async {
  final api = ref.watch(projectManagementApiProvider);
  final token = ref.watch(authProvider).token;
  return api.mandaysMatchingRuns(token: token);
});

/// Per-employee detail for a specific mandays-matching run, keyed by run id.
final mandaysRunDetailProvider = FutureProvider.autoDispose
    .family<List<MandaysMatchingEmployeeSummary>, int>((ref, runId) async {
  final api = ref.watch(projectManagementApiProvider);
  final token = ref.watch(authProvider).token;
  return api.mandaysMatchingRunDetail(runId, token: token);
});

/// Project lookup for the picker dropdown — cached across screens; tiny payload.
final projectLookupProvider =
    FutureProvider.autoDispose<List<ProjectLookup>>((ref) async {
  final api = ref.watch(projectManagementApiProvider);
  final token = ref.watch(authProvider).token;
  return api.projectLookup(token: token);
});
