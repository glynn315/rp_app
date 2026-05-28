import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/consumption_models.dart';
import '../services/consumption_api.dart';

final consumptionApiProvider = Provider<ConsumptionApi>(
  (ref) => ConsumptionApi(),
);

/// Free-text search applied to the projects list.
final consumptionSearchProvider = StateProvider<String>((ref) => '');

/// Selected category-name filter for the projects list. `null` means "All".
/// Matches the web mobile filter chips — we pass the category name (not id)
/// through to `/consumption/projects?category=…`.
final consumptionCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// `/consumption/categories` — cached for the session so the chip row doesn't
/// flicker on every projects-screen rebuild.
final consumptionCategoriesProvider =
    FutureProvider<List<ConsumptionCategory>>((ref) async {
  final api = ref.watch(consumptionApiProvider);
  return api.listCategories();
});

/// Projects list — refetches whenever the search query or category changes.
final consumptionProjectsProvider =
    FutureProvider.autoDispose<List<ConsumptionProject>>((ref) async {
  final api = ref.watch(consumptionApiProvider);
  final search = ref.watch(consumptionSearchProvider);
  final category = ref.watch(consumptionCategoryFilterProvider);
  return api.listProjects(search: search, category: category);
});

/// BOM bundle for a given project — used as the starting point for a new
/// session. Cached by `projectId` so re-visiting the same project doesn't
/// re-hit the ERP.
final consumptionBomProvider = FutureProvider.autoDispose
    .family<ConsumptionBomBundle, int>((ref, projectId) async {
  final api = ref.watch(consumptionApiProvider);
  return api.loadFromErp(projectId);
});

/// Full session detail (lines + transfers) for a saved session.
final consumptionSessionProvider = FutureProvider.autoDispose
    .family<ConsumptionSession, int>((ref, sessionId) async {
  final api = ref.watch(consumptionApiProvider);
  return api.getSession(sessionId);
});

/// Aggregated consumption history for a single ERP BOM line. Used by the
/// BoQ "My entries" screen to show how much material has been consumed.
final consumptionHistoryByBomlineProvider = FutureProvider.autoDispose
    .family<ConsumptionHistory, int>((ref, bomlineId) async {
  final api = ref.watch(consumptionApiProvider);
  return api.historyByBomline(bomlineId);
});

/// Aggregated consumption history across every BOM line under a project
/// scope. Used by the BoQ Entries screen now that scope is the unit of
/// selection (no per-line anchor).
final consumptionHistoryByScopeProvider = FutureProvider.autoDispose
    .family<ConsumptionHistory, int>((ref, scopeId) async {
  final api = ref.watch(consumptionApiProvider);
  return api.historyByScope(scopeId);
});

/// One-shot fetch of the ERP-verify reconciliation for a posted session.
/// Auto-dispose so the comparison is refetched fresh each time the user opens
/// the screen (the underlying ERP state can drift between visits).
final consumptionErpVerifyProvider = FutureProvider.autoDispose
    .family<ErpVerifyResult, int>((ref, sessionId) async {
  final api = ref.watch(consumptionApiProvider);
  return api.verifyAgainstErp(sessionId);
});
