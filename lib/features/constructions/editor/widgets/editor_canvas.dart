import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerScrollEvent, PointerSignalEvent;
import 'package:flutter/material.dart';

import '../../../../core/geometry/section_layout.dart';
import '../../../../core/geometry/snap.dart';
import '../../../../core/models/construction.dart';
import '../../../../core/models/section_geometry.dart';
import '../editor_viewport.dart';
import '../../widgets/construction_painter.dart';

/// Wheel-scroll distance (logical pixels) that corresponds to one natural
/// log-scale step. A notched mouse wheel typically reports dy of ±120 per
/// notch, so exp(±120 * 0.0015) ≈ 1.2 -- roughly a 20% zoom step per
/// notch, smooth for continuous trackpad deltas.
const double _kWheelZoomPerLogicalPixel = 0.0015;

/// The editor's center working zone: a pan/zoomable 2D view of the
/// construction, plus the geometry status banners overlaid on top.
///
/// MODEL-DRIVEN RENDERING: this widget owns no geometry state of its own.
/// Everything drawn comes from [construction] via `ConstructionPainter`/
/// `layoutConstruction`, transformed by the ONE authoritative transform
/// owned by [viewport] (`EditorViewport`). Every interaction mutates only
/// that viewport -- there is no second, canvas-side representation of the
/// construction or its transform that could diverge from the model.
///
/// Interactions:
///   - mouse wheel / trackpad scroll -> cursor-anchored zoom,
///   - single-finger drag            -> pan,
///   - two-finger pinch              -> focal-anchored zoom (+ pan),
///   - tap on a section / empty area -> [onSectionTap] with the section id
///     (or null, selecting the construction root).
///
/// The canvas also reports its laid-out size to the viewport after every
/// layout pass whose size differs from the last reported one (see
/// `EditorViewport.setCanvasSize`), and notifies [onCanvasSizeChanged] so
/// the screen can react to the first usable size (e.g. its initial fit).
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
  /// empty space (selecting the construction root).
  final ValueChanged<String?> onSectionTap;

  /// Called whenever this canvas reports a new size to the viewport --
  /// including the first usable layout, which is when the screen performs
  /// its initial fit.
  final VoidCallback? onCanvasSizeChanged;

  /// A currently-highlighted snap to visualize, or null.
  ///
  /// Dormant plumbing for the snapping foundation: nothing produces an
  /// [ActiveSnap] yet. When drag manipulation arrives it will own this
  /// value's lifecycle (the screen will hold it as presentation state,
  /// gestures will set/clear it via the pure snap engine) -- the canvas
  /// only forwards it to the painter today.
  final ActiveSnap? activeSnap;

  const EditorCanvas({
    super.key,
    required this.construction,
    required this.selectedSectionId,
    required this.viewport,
    required this.onSectionTap,
    this.onCanvasSizeChanged,
    this.activeSnap,
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

                return Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerSignal: _handlePointerScroll,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _handleTapUp(details.localPosition),
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    child: ListenableBuilder(
                      listenable: widget.viewport,
                      builder: (context, _) => CustomPaint(
                        size: size,
                        painter: ConstructionPainter(
                          construction: widget.construction,
                          selectedSectionId: widget.selectedSectionId,
                          transform: widget.viewport.transform,
                          activeSnap: widget.activeSnap,
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

  /// Turns a tap in canvas pixel space into a section selection callback:
  /// the point is converted into millimetre space via the viewport's
  /// authoritative inverse conversion, then hit-tested against the pure
  /// mm-space section rectangles. No painter is involved in hit testing.
  void _handleTapUp(Offset localPosition) {
    final layout = layoutConstruction(widget.construction);
    final hit = layout == null
        ? null
        : sectionAtPoint(layout, widget.viewport.screenToModel(localPosition));
    widget.onSectionTap(hit?.section.id);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _scaleLastFocal = details.localFocalPoint;
    _scaleLastRatio = 1.0; // details.scale starts at 1.0 on every gesture.
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Single-finger drag (or two fingers moving together): translation
    // only, in screen space. (ScaleUpdateDetails has no focalDelta getter
    // in this Flutter version, so the delta is computed from the previous
    // focal point tracked in _handleScaleStart/_scaleLastFocal.)
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
