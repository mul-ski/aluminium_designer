import 'construction.dart';

/// A user-facing project wrapping one [Construction] design.
///
/// Previously `Project` carried its own flat `type`/`width`/`height` fields
/// and a duplicate local `ConstructionType` enum, completely disconnected
/// from `Construction`/`Section`. That made it impossible for a project to
/// represent anything section-based (fixe+ouvrant, multiple ouvrants,
/// etc.) -- the New Project screen could only ever produce a single
/// rectangle with no sections.
///
/// `Project` now simply owns a [Construction], which is where type,
/// overall dimensions, and sections already live. No new dimension/type
/// fields are duplicated here.
class Project {
  final String id;
  final String name;
  final Construction construction;

  const Project({
    required this.id,
    required this.name,
    required this.construction,
  });
}
