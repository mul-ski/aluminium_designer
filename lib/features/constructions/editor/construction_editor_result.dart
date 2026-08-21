import '../../../core/models/construction.dart';

/// Distinguishes "user saved edits" from "user deleted this construction"
/// when `ConstructionEditorScreen` pops.
///
/// `null` (popped with no result at all) means "cancelled/discarded" --
/// neither saved nor deleted -- so callers must treat absence of a result
/// as "leave the persisted project untouched".
class ConstructionEditorResult {
  final Construction? saved;
  final String? deletedId;

  const ConstructionEditorResult._({this.saved, this.deletedId});

  factory ConstructionEditorResult.saved(Construction construction) =>
      ConstructionEditorResult._(saved: construction);

  factory ConstructionEditorResult.deleted(String id) =>
      ConstructionEditorResult._(deletedId: id);

  bool get isDeleted => deletedId != null;
}
