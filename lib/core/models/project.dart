import 'construction.dart';

/// A project is a container for one or more [Construction]s (windows,
/// doors, curtain walls) belonging to the same job/building.
///
/// Previously `Project` wrapped a single `Construction` 1:1, which forced
/// "one window = one project" and made it impossible to group multiple
/// constructions (e.g. every window and door on one building) under one
/// project. `Project` now holds `constructions` as a list; there is no
/// remaining `Project.construction` singular field -- every call site that
/// used to read `project.construction` must go through
/// `project.constructions` instead, so there is exactly one source of
/// truth for a project's constructions.
class Project {
  final String id;
  final String name;
  final List<Construction> constructions;

  const Project({
    required this.id,
    required this.name,
    this.constructions = const [],
  });

  /// Returns a copy of this project with [constructions] replaced.
  ///
  /// `Project` is immutable (all fields `final`), so adding a construction
  /// to a project means building a new `Project` rather than mutating one
  /// in place -- this helper is what screens use to do that without
  /// re-listing `id`/`name` at every call site.
  Project copyWith({List<Construction>? constructions}) {
    return Project(
      id: id,
      name: name,
      constructions: constructions ?? this.constructions,
    );
  }
}
