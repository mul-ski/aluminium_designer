import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Matrix4, Offset, Size;

import '../../../core/geometry/section_layout.dart';

/// Scale limits for [EditorViewport], matching the clamps the previous
/// InteractiveViewer-based canvas enforced (`minScale: 0.2`, `maxScale: 6`).
const double kViewportMinScale = 0.2;
const double kViewportMaxScale = 6.0;

/// Padding, in logical pixels, reserved on every side when fitting the
/// construction to the canvas -- the same value `ConstructionPainter` used
/// to reserve internally for its dimension labels.
const double kViewportFitPadding = 32;

/// Owns THE single model→screen transform of the editor's 2D viewport.
///
/// Model space is millimetres with the origin at the construction's
/// top-left corner -- exactly the space `layoutConstruction` produces.
/// Screen space is the canvas widget's logical pixel space. Exactly one
/// [EditorViewport] instance exists per open editor; every pan, zoom, and
/// fit action mutates only this object's matrix, and rendering and hit
/// testing both consume it through [matrix]/[modelToScreen]/
/// [screenToModel]. No widget keeps its own copy of scale or offset, so
/// there is no second transform that could drift out of sync (this is the
/// structural fix for the previous two-stacked-transforms problem where
/// `ConstructionPainter` computed an internal fit underneath
/// `InteractiveViewer`'s matrix).
///
/// The transform is a uniform translate·scale matrix (no rotation/skew),
/// built as `T(offsetX, offsetY) · S(scale)` so that a model point maps
/// to screen as `offset + point * scale`. The stored [matrix] is the
/// single source of truth: scale/translation are read back from it, never
/// tracked separately.
///
/// PRESENTATION-ONLY STATE: this class knows nothing about `Construction`,
/// the catalog, or any domain logic. Callers supply content dimensions per
/// call ([fitToContent]); geometry stays derived from the draft via
/// `layoutConstruction`. It is owned by the editor screen alongside other
/// presentation state -- NOT by `ConstructionEditorController`, which
/// stays domain-only.
///
/// Scale is clamped to [kViewportMinScale]/[kViewportMaxScale]. Panning is
/// unbounded, preserving the generous overscroll freedom the old canvas
/// had via `InteractiveViewer.boundaryMargin`.
///
/// Mutating methods notify listeners only for accepted changes; rejected
/// no-ops (zero factor zoom, missing canvas size, degenerate content)
/// notify nobody.
class EditorViewport extends ChangeNotifier {
  Matrix4 _matrix = Matrix4.identity();
  Size? _canvasSize;

  /// The authoritative model→screen transform. Pass this to painters and
  /// read conversions from it; do not cache or compose transforms outside
  /// this class.
  Matrix4 get matrix => _matrix;

  /// The same authoritative transform as [matrix], in the
  /// [FittedTransform] value form `ConstructionPainter` consumes
  /// (scale + centered offset). A second *view*, not a second source of
  /// truth -- both are derived from [_matrix] alone.
  FittedTransform get transform =>
      FittedTransform(scale: _scale, offsetX: _tx, offsetY: _ty);

  /// The canvas widget's current logical size, as reported via
  /// [setCanvasSize], or null before the first layout pass.
  Size? get canvasSize => _canvasSize;

  // The uniform scale and translation components are read straight back
  // from [_matrix]: the matrix is the single source of truth, and these
  // accessors are what keep the coordinate math below exactly consistent
  // with whatever transform was last applied.
  double get _scale {
    assert(
      _matrix[0] == _matrix[5],
      'EditorViewport transforms must stay uniformly scaled',
    );
    return _matrix[0];
  }

  double get _tx => _matrix[12];
  double get _ty => _matrix[13];

  void _apply({required double scale, required double tx, required double ty}) {
    _matrix = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    notifyListeners();
  }

  /// Converts a model-space (millimetre) point to screen (pixel) space:
  /// `offset + point * scale`.
  Offset modelToScreen(Offset point) =>
      Offset(_tx + point.dx * _scale, _ty + point.dy * _scale);

  /// Converts a screen (pixel) point back to model (millimetre) space --
  /// the exact inverse of [modelToScreen].
  ///
  /// Returns `Offset.zero` for a degenerate (scale-0) transform rather
  /// than dividing by zero; such transforms are guarded against elsewhere
  /// but this keeps the conversion total.
  Offset screenToModel(Offset point) {
    final s = _scale;
    if (s == 0) return Offset.zero;
    return Offset((point.dx - _tx) / s, (point.dy - _ty) / s);
  }

  /// Reports the canvas widget's current logical size. Called by the
  /// canvas after every layout pass whose size differs from the last one
  /// reported. Does not itself change the transform -- refitting after a
  /// resize is a caller decision (the editor fits once initially and on
  /// explicit user request, never automatically mid-editing).
  void setCanvasSize(Size size) {
    if (_canvasSize == size) return;
    _canvasSize = size;
    notifyListeners();
  }

  /// Fits [contentWidth] x [contentHeight] millimetres into the canvas,
  /// preserving aspect ratio and centering, via the shared pure
  /// `fitConstructionToCanvas` function.
  ///
  /// Returns false (and changes nothing) when there is no usable canvas
  /// yet, the content is degenerate (non-positive dimension), or the fit
  /// produced a degenerate scale -- mirroring that function's own guards.
  bool fitToContent({
    required double contentWidth,
    required double contentHeight,
  }) {
    final canvas = _canvasSize;
    if (canvas == null || canvas.width <= 0 || canvas.height <= 0) {
      return false;
    }
    if (contentWidth <= 0 || contentHeight <= 0) return false;

    final fit = fitConstructionToCanvas(
      contentWidth: contentWidth,
      contentHeight: contentHeight,
      canvasWidth: canvas.width,
      canvasHeight: canvas.height,
      padding: kViewportFitPadding,
    );
    // Clamp the fitted scale into the viewport's own zoom bounds so the
    // viewport never starts outside the range the zoom controls can
    // reach -- an extremely large construction simply fits at the
    // minimum scale instead of below it.
    final scale = (fit.scale.clamp(
      kViewportMinScale,
      kViewportMaxScale,
    )).toDouble();
    if (fit.scale <= 0) return false;

    _apply(scale: scale, tx: fit.offsetX, ty: fit.offsetY);
    return true;
  }

  /// Zooms by [factor] around the viewport CENTER, so repeated toolbar
  /// clicks keep the middle of the drawing anchored instead of drifting
  /// the content toward one corner (which is what scaling about the
  /// origin did previously). No-op without a known canvas size.
  void zoomBy(double factor) {
    final canvas = _canvasSize;
    if (canvas == null || canvas.width <= 0 || canvas.height <= 0) return;
    zoomAt(Offset(canvas.width / 2, canvas.height / 2), factor);
  }

  /// Zooms by [factor] keeping the model point currently under
  /// [screenPoint] exactly under it afterwards -- cursor/focal-stable
  /// zooming for wheel events and pinch gestures.
  ///
  /// The resulting scale is clamped to [kViewportMinScale]/
  /// [kViewportMaxScale]; when clamping makes the scale unchanged the call
  /// is a no-op. Zero/negative factors are ignored.
  void zoomAt(Offset screenPoint, double factor) {
    if (!factor.isFinite || factor <= 0 || factor == 1) return;

    final s0 = _scale;
    final s1 = ((s0 * factor).clamp(
      kViewportMinScale,
      kViewportMaxScale,
    )).toDouble();
    if (s1 == s0) return;

    // Keep the anchor stable: screen = offset + model * scale must hold
    // for the SAME (screenPoint, modelPoint) pair before and after.
    final anchor = screenToModel(screenPoint);
    _apply(
      scale: s1,
      tx: screenPoint.dx - anchor.dx * s1,
      ty: screenPoint.dy - anchor.dy * s1,
    );
  }

  /// Pans by [screenDelta] pixels (drag gesture). Translation-only; scale
  /// and therefore all coordinate semantics stay untouched.
  void panBy(Offset screenDelta) {
    if (screenDelta == Offset.zero) return;
    _apply(scale: _scale, tx: _tx + screenDelta.dx, ty: _ty + screenDelta.dy);
  }
}
