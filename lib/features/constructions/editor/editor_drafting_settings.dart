import 'package:flutter/foundation.dart';

/// Default grid-snap increment, in millimetres. A deliberately "round"
/// editing aid -- NOT a fabrication rule; it never reaches the calculator
/// or the persisted construction.
const double kDefaultSnapIncrementMm = 5.0;

/// Per-editor drafting settings: the interaction aids of the workshop
/// canvas (snap on/off, grid visibility, snap increment).
///
/// OWNERSHIP AND LIFETIME mirror `EditorViewport`: exactly one instance per
/// open editor session, owned by the editor screen alongside the viewport,
/// disposed with it. This is presentation/interaction state -- never domain
/// state: it is not part of the Construction model, is not persisted, and
/// does not participate in undo history (toggling snap must not be
/// undoable any more than toggling zoom).
///
/// ORTHOGONAL KNOBS (kept independent by design):
/// - [snapEnabled] gates ALL automatic snapping during manipulations. OFF
///   means raw model positions and no snap indicator, regardless of every
///   other setting.
/// - [gridVisible] controls ONLY whether the measurement grid is drawn.
///   Drawing the grid says nothing about whether positions snap to it.
/// - [snapIncrementMm] is the model-space spacing between synthesized grid
///   candidates when snapping is enabled. An editing aid in real
///   millimetres -- it implies no fabrication tolerance, minimum size or
///   manufacturer convention.
class EditorDraftingSettings extends ChangeNotifier {
  bool _snapEnabled = true;
  bool _gridVisible = true;
  double _snapIncrementMm = kDefaultSnapIncrementMm;

  /// Whether automatic snapping is active during manipulations.
  bool get snapEnabled => _snapEnabled;

  /// Whether the measurement grid is drawn on the canvas.
  bool get gridVisible => _gridVisible;

  /// Grid-snap increment in model millimetres (> 0).
  double get snapIncrementMm => _snapIncrementMm;

  set snapEnabled(bool value) {
    if (_snapEnabled == value) return;
    _snapEnabled = value;
    notifyListeners();
  }

  set gridVisible(bool value) {
    if (_gridVisible == value) return;
    _gridVisible = value;
    notifyListeners();
  }

  set snapIncrementMm(double value) {
    // Reject degenerate increments rather than silently disabling the grid:
    // callers own validation UX, but a non-positive spacing is meaningless.
    if (!value.isFinite || value <= 0) return;
    if (_snapIncrementMm == value) return;
    _snapIncrementMm = value;
    notifyListeners();
  }
}
