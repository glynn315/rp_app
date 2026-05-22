import '../models/project_management_models.dart';

/// One row in the two-level BoQ list: a project header plus the scopes that
/// belong to it. Used by both the Log-Progress wizard's Step 2 picker and the
/// standalone Bill of Quantities screen so the grouping behaviour stays
/// consistent across the app.
class BoqProjectGroup {
  final int? projectId;
  final String projectName;
  final String projectDocumentNo;
  final String projectStatus;
  final List<BoqItem> scopes;
  final double totalAmount;

  const BoqProjectGroup({
    required this.projectId,
    required this.projectName,
    required this.projectDocumentNo,
    required this.projectStatus,
    required this.scopes,
    required this.totalAmount,
  });
}

/// Buckets a flat per-(project, scope) BoQ list into one row per project,
/// preserving the server's order within each project. Projects are sorted by
/// name so the list stays stable across reloads.
List<BoqProjectGroup> groupBoqByProject(List<BoqItem> items) {
  final order = <int?>[];
  final buckets = <int?, List<BoqItem>>{};
  for (final it in items) {
    final key = it.projectId;
    if (!buckets.containsKey(key)) {
      order.add(key);
      buckets[key] = <BoqItem>[];
    }
    buckets[key]!.add(it);
  }

  final groups = <BoqProjectGroup>[];
  for (final key in order) {
    final scopes = buckets[key]!;
    final head = scopes.first;
    final total = scopes.fold<double>(0, (acc, s) => acc + s.amount);
    groups.add(BoqProjectGroup(
      projectId: key,
      projectName: head.projectName,
      projectDocumentNo: head.projectDocumentNo,
      projectStatus: head.projectStatus,
      scopes: scopes,
      totalAmount: total,
    ));
  }

  groups.sort((a, b) => a.projectName
      .toLowerCase()
      .compareTo(b.projectName.toLowerCase()));
  return groups;
}
