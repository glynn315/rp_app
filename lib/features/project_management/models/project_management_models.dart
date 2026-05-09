/// Barrel/library for the project_management module models.
///
/// Each entity lives in its own file under `models/` for clarity. JSON
/// helpers are private to the library and shared across all parts via
/// Dart's `part`/`part of` mechanism.
library;

part 'json_utils.dart';
part 'project_lookup.dart';
part 'boq_item.dart';
part 'wip_project.dart';
part 'lmc_payout.dart';
part 'mandays_matching.dart';
