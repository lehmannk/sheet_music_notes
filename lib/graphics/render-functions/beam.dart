import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../generated/engraving-defaults.dart';
import '../../musicXML/data.dart';
import '../generated/glyph-anchors.dart';
import 'DrawingContext.dart';

class BeamPoint {
  BeamPoint(this.beam, this.notePosition, this.noteAnchor, this.drawAbove);

  final bool drawAbove;
  final Beam beam;
  final Offset notePosition;
  final GlyphAnchor noteAnchor;
}

/// Mutable beam-rendering state that must live across the notes of a beam group (and its
/// chord-overlay pass), owned by the DrawingContext. Grouping it here makes the implicit
/// cross-note coupling of the beam pipeline explicit and gives it one owner:
/// 1. Base pass: every beamed non-chord note adds its [BeamPoint]s to [openGroups]; once a
///    group is complete it is painted, its geometry stashed in [paintedSegmentsByID] and the
///    group removed from [openGroups].
/// 2. Overlay pass: every chord (feedback) copy adds its colour to [chordColorsByID]; once
///    all overlays of a group arrived, stems/beams are recoloured and both entries removed.
class BeamRenderState {
  /// Beam points of the group(s) currently being collected, by `Beam.id`, then beam number.
  final Map<int, Map<int, List<BeamPoint>>> openGroups = {};

  /// Geometry (canvas-local) of stems and beam lines captured during a completed base
  /// beam-group's paint, by `Beam.id`. Reused by the chord-overlay pass to overdraw per-note
  /// stems in each feedback colour and — when every chord overlay in the group shares the
  /// same non-black colour — the connecting beam line(s).
  final Map<int,
      ({
        List<({Offset start, Offset end})> stems,
        List<({Offset start, Offset end})> beams,
      })> paintedSegmentsByID = {};

  /// Feedback colours collected from chord overlays in render order — one per chord overlay
  /// (i.e. one per note in the beam group), by `Beam.id`.
  final Map<int, List<Color>> chordColorsByID = {};
}

List<int> getOpenBeams(Map<int, List<BeamPoint>> beamPoints) {
  final List<int> beginList = [];
  final List<int> endOrHookList = [];

  for (final beamPointsForNumber in beamPoints.values) {
    for (final elmt in beamPointsForNumber) {
      switch (elmt.beam.value) {
        case BeamValue.backward:
        case BeamValue.forward:
        case BeamValue.end:
          endOrHookList.add(elmt.beam.number);
          break;
        case BeamValue.begin:
          beginList.add(elmt.beam.number);
          break;
        default:
          break;
      }
    }
  }

  return beginList
      .whereNot((element) => endOrHookList.contains(element))
      .toList(growable: false);
}

/// Returns the two endpoints of a beam segment that runs PARALLEL to the primary
/// beam line (the line through [primaryStart]..[primaryEnd]), spanning the x-range
/// [startX]..[endX] and shifted vertically by [verticalShift] (negative shifts the
/// segment upwards). Secondary beams (e.g. the sixteenth beams inside an
/// eighth+sixteenth group) must be drawn with this so they stay parallel to the
/// primary beam instead of tilting independently.
/// Signed vertical offset (in canvas pixels, +y is downwards) at which the beam
/// of level [key] must be drawn relative to the primary beam line. The primary
/// beam (the longest one, lowest [primaryKey]) sits on the OUTSIDE of the group
/// and returns 0; every higher (shorter) level is shifted one [levelGap] further
/// towards the note heads per level — downwards for stem-up groups ([drawAbove]
/// true), upwards for stem-down groups.
double beamLevelShift(int key, int primaryKey, double levelGap, bool drawAbove) {
  final double towardsHeads = (key - primaryKey) * levelGap;
  return drawAbove ? towardsHeads : -towardsHeads;
}

(Offset, Offset) parallelBeamSegment(
  Offset primaryStart,
  Offset primaryEnd,
  double startX,
  double endX,
  double verticalShift,
) {
  final double dx = primaryEnd.dx - primaryStart.dx;
  final double slope = dx.abs() < 1e-6 ? 0.0 : (primaryEnd.dy - primaryStart.dy) / dx;
  double y(double x) => primaryStart.dy + (x - primaryStart.dx) * slope + verticalShift;
  return (Offset(startX, y(startX)), Offset(endX, y(endX)));
}

paintBeam(DrawingContext drawC, Offset start, Offset end, {Color color = Colors.black}) {
  final Paint paint = Paint();
  paint.color = color;
  paint.strokeWidth = 0;
  paint.style = PaintingStyle.fill;

  final Path path = Path();
  path.moveTo(start.dx, start.dy);
  path.lineTo(end.dx, end.dy);
  path.lineTo(end.dx, end.dy + drawC.lS * ENGRAVING_DEFAULTS.beamThickness);
  path.lineTo(start.dx, start.dy + drawC.lS * ENGRAVING_DEFAULTS.beamThickness);
  path.close();

  drawC.canvas.drawPath(path, paint);
}

paintStem(DrawingContext drawC, Offset start, Offset end, {Color color = Colors.black}) {
  final Paint paint = Paint();
  paint.color = color;
  paint.strokeWidth = ENGRAVING_DEFAULTS.stemThickness * drawC.lS;

  drawC.canvas.drawLine(start, end, paint);
}
