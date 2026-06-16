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

paintBeam(DrawingContext drawC, Offset start, Offset end) {
  final Paint paint = Paint();
  paint.color = Colors.black;
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

paintStem(DrawingContext drawC, Offset start, Offset end) {
  final Paint paint = Paint();
  paint.color = Colors.black;
  paint.strokeWidth = ENGRAVING_DEFAULTS.stemThickness * drawC.lS;

  drawC.canvas.drawLine(start, end, paint);
}
