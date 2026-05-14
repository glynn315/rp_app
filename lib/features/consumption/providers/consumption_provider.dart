import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/consumption_models.dart';
import '../services/consumption_api.dart';

final consumptionApiProvider = Provider<ConsumptionApi>(
  (ref) => ConsumptionApi(),
);

/// Free-text search applied to the projects list.
final consumptionSearchProvider = StateProvider<String>((ref) => '');

/// Projects list — refetches whenever the search query changes.
final consumptionProjectsProvider =
    FutureProvider.autoDispose<List<ConsumptionProject>>((ref) async {
  final api = ref.watch(consumptionApiProvider);
  final search = ref.watch(consumptionSearchProvider);
  return api.listProjects(search: search);
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
