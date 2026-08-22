import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';

import '../../../../core/geometry/section_layout.dart';
import '../../../../core/geometry/snap.dart';
import '../../../../core/logic/boundary_manipulation.dart';
import '../../../../core/models/construction.dart';
import '../../../../core/models/layout_direction.dart';
import '../../../../core/models/section_geometry.dart';
import '../editor_viewport.dart';
import '../../widgets/construction_painter.dart';

/// Wheel-scroll distance (logical pixels) that corresponds to one natural
/// log-scale step. A notched mouse wheel typically reports dy of ±120 per
/// notch, so exp(±120 * 0.0015) ≈ 1.2 -- roughly a 20% zoom step per
/// notch, smooth for continuous trackpad deltas.
const double _kWheelZoomPerLogicalPixel = 0.0015;

/// One draggable interior boundary of the current construction, in model
/// space. [boundaryIndex] follows the ordered-section convention shared
/// with `withBoundaryMoved`/`moveBoundary`: index i is the line between
/// ordered[i-1] and ordered[i] (so 1..count-1; edges are NOT boundaries).
class _InteriorBoundary {
  final int boundaryIndex;
  final double positionMm;

  const _InteriorBoundary({
    required this.boundaryIndex,
    required this.positionMm,
  });
}

/// Transient per-gesture state for a boundary drag. [base] is the
/// construction the drag started from -- the controller's draft is never
/// mutated during the gesture; all movement renders as an immutable
/// preview derived from [base].
class _BoundaryDragSession {
  final int boundaryIndex;
  final Construction base;

  /// Snap candidates collected ONCE at drag start, excluding the dragged
  /// boundary's own position (otherwise it would self-snap at distance
  /// zero and never move).
  final List<SnapTarget1D> targets;

  const _BoundaryDragSession({
    required this.boundaryIndex,
    required this.base,
    required this.targets,
  });
}

/// The editor's center working zone: a pan/zoomable 2D view of the
/// construction with direct section-boundary manipulation, plus the
/// geometry status banners overlaid on top.
///
/// MODEL-DRIVEN RENDERING: this widget owns no persistent geometry. The
/// construction comes from [construction]; during a boundary drag a
/// transient PREVIEW construction -- rebuilt immutably from that same
/// draft via `withBoundaryMoved` -- is what gets painted instead, so the
/// rendering pipeline stays identical while the authoritative model is
/// only ever changed by the single committed mutation reported through
/// [onBoundaryDragCompleted].
///
/// Interactions:
///   - mouse wheel / trackpad scroll -> cursor-anchored zoom,
///   - single-finger drag            -> pan,
///   - two-finger pinch              -> focal-anchored zoom (+ pan),
///   - tap on a section / empty area -> [onSectionTap],
///   - drag starting on an interior BOUNDARY corridor -> boundary move
///     (screen point -> viewport.screenToModel -> axis mm ->
///     snapPosition -> withBoundaryMoved), committed once on release.
///
/// A plain TAP inside a boundary corridor is deliberately a no-op: the
/// narrow corridor must never hijack section selection.
///
/// Gesture-transient visuals ([ActiveSnap], the preview) are owned here --
/// producer and consumer are both this widget -- and cleared on every
/// end/cancel path.
class EditorCanvas extends StatefulWidget {
  final Construction construction;

  /// Id of the currently selected [Section], or null for the construction
  /// root -- passed straight through to the painter so the highlighted
  /// rectangle always matches what the tree and properties panel show.
  final String? selectedSectionId;

  /// The viewport owning the single model→screen transform. Owned by the
  /// screen; this widget only drives it.
  final EditorViewport viewport;

  /// Called with the tapped section's id, or null when the tap landed on
  /// empty space (selecting the construction root). Never called when the
  /// tap lands inside a boundary corridor.
  final ValueChanged<String?> onSectionTap;

  /// Called whenever this canvas reports a new size to the viewport --
  /// including the first usable layout, which is when the screen performs
  /// its initial fit.
  final VoidCallback? onCanvasSizeChanged;

  /// Called EXACTLY ONCE per completed boundary drag, with the
  /// ordered-section boundary index and its final millimetre position.
  /// The receiver commits through the editor controller (one mutation =
  /// one undo entry). Not called when nothing moved.
  final void Function(int boundaryIndex, double positionMm)?
  onBoundaryDragCompleted;

  const EditorCanvas({
    super.key,
    required this.construction,
    required this.selectedSectionId,
    required this.viewport,
    required this.onSectionTap,
    this.onCanvasSizeChanged,
    required this.onBoundaryDragCompleted,
  });

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  Size? _lastReportedSize;

  // Incremental scale-gesture state: each update pans by the focal delta
  // and applies only the RATIO of scales since the previous update as a
  // focal-anchored zoom, so combined pinch+drag composes correctly.
  Offset? _scaleLastFocal;
  double _scaleLastRatio = 1.0;

  // Boundary-drag state. All four fields are cleared together on every
  // end/cancel path; see [_endBoundaryDrag].
  _BoundaryDragSession? _boundaryDrag;
  ActiveSnap? _activeSnap;
  Construction? _dragPreview;

  // Hover feedback: which interior boundary (if any) is under the cursor.
  int? _hoveredBoundaryIndex;

  /// The interior boundary (if any) under the pointer at raw DOWN time.
  /// Consumed by [_handleScaleStart] to enter boundary-drag mode; see its
  /// doc for why the decision happens here rather than at scale-start.
  _InteriorBoundary? _pointerDownHit;

  /// Raw local position of the active pointer's DOWN event; anchors
  /// free-mode panning across the gesture-recognizer slop window.
  Offset? _pointerDownPosition;

  bool get _isHorizontal =>
      widget.construction.layoutDirection == SectionLayoutDirection.horizontal;

  double _axisComponent(Offset point) => _isHorizontal ? point.dx : point.dy;

  double _axisSizeOf(SectionRect rect) =>
      _isHorizontal ? rect.width : rect.height;

  @override
  void didUpdateWidget(covariant EditorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the committed draft changed underneath an active drag (e.g. an
    // undo shortcut fired mid-gesture), abandon the stale session without
    // committing anything computed against a foreign base.
    if (_boundaryDrag != null &&
        !identical(_boundaryDrag!.base, widget.construction)) {
      _clearDragState(notify: true);
    }
  }

  void _reportSize(Size size) {
    if (_lastReportedSize == size) return;
    _lastReportedSize = size;
    widget.viewport.setCanvasSize(size);
    widget.onCanvasSizeChanged?.call();
  }

  void _handlePointerScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final dy = event.scrollDelta.dy;
    if (dy == 0) return;

    // Cursor-anchored zoom: the model point currently under the cursor
    // stays exactly under it. The event's localPosition is in THIS
    // widget's coordinate space -- the same space CustomPaint paints in.
    widget.viewport.zoomAt(
      event.localPosition,
      math.exp(-dy * _kWheelZoomPerLogicalPixel),
    );
  }

  /// Lists every interior boundary of the current construction, in model
  /// millimetres along the layout axis.
  List<_InteriorBoundary> _interiorBoundaries(ConstructionLayout layout) {
    final ordered = [...layout.sections]
      ..sort((a, b) => a.section.order.compareTo(b.section.order));

    final boundaries = <_InteriorBoundary>[];
    var cursor = 0.0;
    for (var i = 0; i < ordered.length - 1; i++) {
      cursor += _axisSizeOf(ordered[i]);
      boundaries.add(
        _InteriorBoundary(boundaryIndex: i + 1, positionMm: cursor),
      );
    }
    return boundaries;
  }

  /// The interior boundary under [screenPoint], or null. The grab window
  /// is SCREEN-perceived (`kSnapTolerancePx` converted through the live
  /// scale) and requires the pointer to sit over the construction's cross
  /// extent, so corridors cannot be grabbed from empty space above/below.
  _InteriorBoundary? _hitBoundary(Offset screenPoint) {
    if (widget.construction.sections.length < 2) return null;
    final layout = layoutConstruction(widget.construction);
    if (layout == null) return null;

    final toleranceMm = kSnapTolerancePx / widget.viewport.scale;
    final pointerModel = widget.viewport.screenToModel(screenPoint);

    final totalCross = _isHorizontal ? layout.height : layout.width;
    final cross = _isHorizontal ? pointerModel.dy : pointerModel.dx;
    if (cross < -toleranceMm || cross > totalCross + toleranceMm) {
      return null;
    }

    final axis = _axisComponent(pointerModel);
    _InteriorBoundary? best;
    var bestDistance = double.infinity;
    for (final boundary in _interiorBoundaries(layout)) {
      final distance = (axis - boundary.positionMm).abs();
      if (distance <= toleranceMm && distance < bestDistance) {
        best = boundary;
        bestDistance = distance;
      }
    }
    return best;
  }

  /// Records whether a pointer went down inside a boundary corridor.
  ///
  /// The decision is made HERE, at raw pointer-down time, because
  /// ScaleGestureRecognizer only accepts after the slop threshold: by the
  /// time `onScaleStart` fires, the pointer has usually already MOVED away
  /// from the corridor and hit-testing the current position would miss it.
  void _handlePointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.localPosition;
    _pointerDownHit = _hitBoundary(event.localPosition);
  }

  void _clearPointerDown() {
    _pointerDownPosition = null;
    _pointerDownHit = null;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    // Boundary dragging consumes single-pointer gestures whose DOWN landed
    // inside a corridor (see [_handlePointerDown] for why the decision is
    // made at down-time). Multi-touch starts never enter boundary mode
    // (pinch stays pinch).
    if (details.pointerCount == 1 && _pointerDownHit != null) {
      final hit = _pointerDownHit!;
      _pointerDownHit = null;
      final layout = layoutConstruction(widget.construction)!;
      _boundaryDrag = _BoundaryDragSession(
        boundaryIndex: hit.boundaryIndex,
        base: widget.construction,
        targets: collectSnapTargets(
          layout,
          widget.construction.layoutDirection,
        ).where((target) => target.positionMm != hit.positionMm).toList(),
      );
      // Reset pan/pinch trackers; unused in boundary mode.
      _scaleLastFocal = null;
      _scaleLastRatio = 1.0;
      return;
    }
    _pointerDownHit = null;

    // Anchor panning to the ORIGINAL pointer-down position: the scale
    // recognizer only accepts after the touch slop, so anchoring to the
    // acceptance-time focal would silently discard the pre-slop movement.
    // Multi-pointer restarts re-anchor to their own centroid instead (the
    // first finger's origin is meaningless for a fresh two-hand pinch).
    _scaleLastFocal =
        (details.pointerCount == 1 ? _pointerDownPosition : null) ??
        details.localFocalPoint;
    _scaleLastRatio = 1.0; // details.scale starts at 1.0 on every gesture.
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    final session = _boundaryDrag;
    if (session != null) {
      if (!identical(session.base, widget.construction)) {
        _clearDragState(notify: true);
        return;
      }

      // screen point -> model mm -> snap -> clamped preview. Position-based
      // (not delta-based), so stray multi-touch simply retargets.
      final modelPoint = widget.viewport.screenToModel(details.localFocalPoint);
      final raw = _axisComponent(modelPoint);
      final snapped = snapPosition(
        positionMm: raw,
        targets: session.targets,
        toleranceMm: kSnapTolerancePx / widget.viewport.scale,
      );
      final effective = snapped?.snappedPositionMm ?? raw;

      setState(() {
        _activeSnap = snapped == null
            ? null
            : ActiveSnap(
                positionMm: snapped.snappedPositionMm,
                kind: snapped.target.kind,
              );
        _dragPreview = withBoundaryMoved(
          widget.construction,
          session.boundaryIndex,
          effective,
        );
      });
      return;
    }

    // Single-finger drag (or two fingers moving together): translation
    // only, in screen space.
    final lastFocal = _scaleLastFocal ?? details.localFocalPoint;
    widget.viewport.panBy(details.localFocalPoint - lastFocal);

    // Multi-finger pinch: apply ONLY the ratio since the previous update
    // around the current focal point, keeping the geometry under the
    // user's fingers stable while they spread/close them.
    final last = _scaleLastRatio;
    if (details.scale > 0 && details.scale != last && last > 0) {
      widget.viewport.zoomAt(details.localFocalPoint, details.scale / last);
    }
    _scaleLastRatio = details.scale;
    _scaleLastFocal = details.localFocalPoint;
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (_boundaryDrag != null) {
      // One completed drag = exactly one committed mutation.
      _endBoundaryDrag(commit: true);
    }
  }

  /// Clears every piece of transient drag state. Called on release
  /// (commit:true), on abort paths, and from didUpdateWidget.
  void _clearDragState({required bool notify}) {
    if (!notify) {
      _boundaryDrag = null;
      _activeSnap = null;
      _dragPreview = null;
      return;
    }
    setState(() {
      _boundaryDrag = null;
      _activeSnap = null;
      _dragPreview = null;
    });
  }

  void _endBoundaryDrag({required bool commit}) {
    final session = _boundaryDrag;
    final preview = _dragPreview;

    _clearDragState(notify: true);

    if (commit && session != null && preview != null) {
      // Report the ACTUAL final boundary position as held by the preview
      // model (withBoundaryMoved may have clamped the requested position
      // against the minimum-size floor).
      widget.onBoundaryDragCompleted?.call(
        session.boundaryIndex,
        _boundaryPositionIn(preview, session.boundaryIndex),
      );
    }
  }

  /// The millimetre position of the boundary after [boundaryIndex] within
  /// [construction] -- same ordered-section convention as everywhere else.
  double _boundaryPositionIn(Construction construction, int boundaryIndex) {
    final ordered = [...construction.sections]
      ..sort((a, b) => a.order.compareTo(b.order));
    var cursor = 0.0;
    for (var i = 0; i < boundaryIndex; i++) {
      cursor += _isHorizontal ? ordered[i].width : ordered[i].height;
    }
    return cursor;
  }

  /// Turns a tap into selection -- unless it landed on a boundary corridor,
  /// where taps are deliberate no-ops so grabbing a divider can never
  /// accidentally change selection.
  void _handleTapUp(Offset localPosition) {
    if (_hitBoundary(localPosition) != null) return;

    final layout = layoutConstruction(widget.construction);
    final hit = layout == null
        ? null
        : sectionAtPoint(layout, widget.viewport.screenToModel(localPosition));
    widget.onSectionTap(hit?.section.id);
  }

  void _updateHover(Offset? localPosition) {
    final hit = localPosition == null ? null : _hitBoundary(localPosition);
    final index = hit?.boundaryIndex;
    if (index != _hoveredBoundaryIndex) {
      setState(() => _hoveredBoundaryIndex = index);
    }
  }

  MouseCursor get _hoverCursor {
    if (_hoveredBoundaryIndex == null) return MouseCursor.defer;
    return _isHorizontal
        ? SystemMouseCursors.resizeLeftRight
        : SystemMouseCursors.resizeUpDown;
  }

  @override
  Widget build(BuildContext context) {
    final status = constructionGeometryStatus(widget.construction);
    final problems = validateSectionGeometry(widget.construction);

    return Container(
      color: const Color(0xFFF3F5F6),
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;

                // Report after layout completes -- setCanvasSize notifies
                // listeners, which must not happen during build.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _reportSize(size);
                });

                return MouseRegion(
                  cursor: _hoverCursor,
                  onHover: (event) => _updateHover(event.localPosition),
                  onExit: (_) => _updateHover(null),
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _handlePointerDown,
                    onPointerUp: (_) => _clearPointerDown(),
                    onPointerCancel: (_) => _clearPointerDown(),
                    onPointerSignal: _handlePointerScroll,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (details) => _handleTapUp(details.localPosition),
                      onScaleStart: _handleScaleStart,
                      onScaleUpdate: _handleScaleUpdate,
                      onScaleEnd: _handleScaleEnd,
                      child: ListenableBuilder(
                        listenable: widget.viewport,
                        builder: (context, _) => CustomPaint(
                          size: size,
                          painter: ConstructionPainter(
                            construction: _dragPreview ?? widget.construction,
                            selectedSectionId: widget.selectedSectionId,
                            transform: widget.viewport.transform,
                            activeSnap: _activeSnap,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (status == GeometryStatus.incomplete)
            Positioned(
              left: 16,
              top: 16,
              right: 16,
              child: _StatusBanner(
                color: const Color(0xFFFFF3CD),
                textColor: const Color(0xFF7A5C00),
                icon: Icons.edit_note,
                message:
                    'Construction en cours de création -- ajoutez les '
                    'dimensions et au moins une section pour voir l\'aperçu.',
              ),
            )
          else if (status == GeometryStatus.invalid)
            Positioned(
              left: 16,
              top: 16,
              right: 16,
              child: _StatusBanner(
                color: const Color(0xFFFDE2E1),
                textColor: const Color(0xFF8C2E27),
                icon: Icons.error_outline,
                message: problems.join(' '),
              ),
            ),
        ],
      ),
    );
  }
}

/// Floating message banner shown over the canvas for incomplete/invalid
/// geometry states -- see `GeometryStatus` for why those are distinct
/// states with distinct visual treatments (informational vs error).
class _StatusBanner extends StatelessWidget {
  final Color color;
  final Color textColor;
  final IconData icon;
  final String message;

  const _StatusBanner({
    required this.color,
    required this.textColor,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: textColor)),
          ),
        ],
      ),
    );
  }
}
