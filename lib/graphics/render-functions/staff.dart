import 'package:flutter/material.dart';

import '../../musicXML/data.dart';
import '../generated/engraving-defaults.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-definitions.dart';
import '../generated/glyph-range-definitions.dart';
import '../notes.dart';
import 'DrawingContext.dart';
import 'glyph.dart';
import 'note.dart';

/// Advances to the end of the lines.
///
/// [endX] is the x-coordinate (in the painter's root coordinate space) up to
/// which the staff lines are drawn. When omitted, the lines extend to the full
/// width of the canvas (the window width). Pass the right edge of the last
/// barline here to stop the staff lines at the end of the music.
paintStaffLines(DrawingContext drawC, bool noAdvance, {double? endX}) {
  final lS = drawC.lS;
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lS * ENGRAVING_DEFAULTS.staffLineThickness;

  final lineEndX = endX ?? drawC.size.width;
  final lineWidth = lineEndX - drawC.canvas.getTranslation().dx;

  drawC.canvas.drawLine(const Offset(0, 0), Offset(lineWidth, 0), paint);
  drawC.canvas.drawLine(Offset(0, lS * 1), Offset(lineWidth, lS * 1), paint);
  drawC.canvas.drawLine(Offset(0, lS * 2), Offset(lineWidth, lS * 2), paint);
  drawC.canvas.drawLine(Offset(0, lS * 3), Offset(lineWidth, lS * 3), paint);
  drawC.canvas.drawLine(Offset(0, lS * 4), Offset(lineWidth, lS * 4), paint);

  if (!noAdvance) {
    drawC.canvas.translate(lineWidth, 0);
  }
}

enum BarLineTypes { regular, lightLight, heavyHeavy, heavyLight, lightHeavy, heavy, dashed, repeatRight, repeatLeft }

/// Does translate to after its width.
///
/// Returns the x-coordinate (in the painter's root coordinate space) of the
/// visible right edge of the drawn barline. Because the barline strokes are
/// drawn centred on the current pen position, this right edge lies half a stroke
/// width left of the post-advance translation. Use this value to make staff
/// lines stop exactly at the barline instead of overshooting it.
double paintBarLine(DrawingContext drawC, Barline barline, bool noAdvance) {
  final lS = drawC.lS;
  final thinBarlineWidh = lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
  final paint = Paint()..color = Colors.black;
  final staves = drawC.latestAttributes.staves!;

  const startOffset = Offset(0, 0);
  final endOffset = Offset(0, staves > 1 ? drawC.staffHeight * 2 + drawC.staffsSpacing : drawC.staffHeight);

  if (noAdvance) {
    drawC.canvas.save();
  }

  /// Tracks the right edge of the last (right-most) stroke that was drawn.
  double rightEdge = drawC.canvas.getTranslation().dx;

  /// Draws a vertical barline stroke at the current pen position and records its
  /// visible right edge (the stroke is centred on the pen, hence + half width).
  void drawStroke(double strokeWidth) {
    paint.strokeWidth = strokeWidth;
    drawC.canvas.drawLine(startOffset, endOffset, paint);
    rightEdge = drawC.canvas.getTranslation().dx + strokeWidth / 2;
  }

  if (barline.barStyle == BarLineTypes.regular) {
    drawStroke(thinBarlineWidh);
    drawC.canvas.translate(thinBarlineWidh, 0);
  } else if (barline.barStyle == BarLineTypes.dashed) {
    // A dashed bar line: same footprint/advance as a thin bar line, but drawn as a
    // dashed stroke. Without this branch the dashed style was not rendered at all, so
    // the music had no visible right boundary and the staff lines (which stop at the
    // returned right edge) appeared to overshoot the music.
    paint.strokeWidth = thinBarlineWidh;
    final double height = endOffset.dy;
    final double dashLength = lS;
    final double gapLength = lS / 2;
    double y = 0;
    while (y < height) {
      final double segmentEnd = (y + dashLength) > height ? height : (y + dashLength);
      drawC.canvas.drawLine(Offset(0, y), Offset(0, segmentEnd), paint);
      y = segmentEnd + gapLength;
    }
    rightEdge = drawC.canvas.getTranslation().dx + thinBarlineWidh / 2;
    drawC.canvas.translate(thinBarlineWidh, 0);
  } else if (barline.barStyle == BarLineTypes.lightLight) {
    drawStroke(thinBarlineWidh);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.barlineSeparation + thinBarlineWidh, 0);
    drawStroke(thinBarlineWidh);
    drawC.canvas.translate(thinBarlineWidh, 0);
  } else if (barline.barStyle == BarLineTypes.lightHeavy) {
    drawStroke(thinBarlineWidh);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.barlineSeparation + thinBarlineWidh, 0);
    drawStroke(lS * ENGRAVING_DEFAULTS.thickBarlineThickness);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.thickBarlineThickness, 0);
  } else if (barline.barStyle == BarLineTypes.repeatRight) {
    drawStroke(lS * ENGRAVING_DEFAULTS.thickBarlineThickness);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.barlineSeparation, 0);
    drawStroke(thinBarlineWidh);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.repeatBarlineDotSeparation, 0);
    paintGlyph(drawC, Glyph.repeatDots);
    rightEdge = drawC.canvas.getTranslation().dx + lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]!;
    drawC.canvas.translate(lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]!, 0);
  } else if (barline.barStyle == BarLineTypes.repeatLeft) {
    paintGlyph(drawC, Glyph.repeatDots);
    drawC.canvas.translate(
        lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]! + lS * ENGRAVING_DEFAULTS.repeatBarlineDotSeparation, 0);
    drawStroke(thinBarlineWidh);
    drawC.canvas.translate(thinBarlineWidh + lS * ENGRAVING_DEFAULTS.barlineSeparation, 0);
    drawStroke(lS * ENGRAVING_DEFAULTS.thickBarlineThickness);
    drawC.canvas.translate(lS * ENGRAVING_DEFAULTS.thickBarlineThickness, 0);
  }

  if (noAdvance) {
    drawC.canvas.restore();
  }

  return rightEdge;
}

calculateBarlineWidth(DrawingContext drawC, Barline barline) {
  final lS = drawC.lS;
  final thinBarlineWidh = lS * ENGRAVING_DEFAULTS.thinBarlineThickness;
  double width = 0;

  if (barline.barStyle == BarLineTypes.regular) {
    width = thinBarlineWidh;
  } else if (barline.barStyle == BarLineTypes.dashed) {
    width = thinBarlineWidh;
  } else if (barline.barStyle == BarLineTypes.lightLight) {
    width = lS * ENGRAVING_DEFAULTS.barlineSeparation + thinBarlineWidh + thinBarlineWidh;
  } else if (barline.barStyle == BarLineTypes.lightHeavy) {
    width = lS * ENGRAVING_DEFAULTS.barlineSeparation +
        thinBarlineWidh +
        lS * ENGRAVING_DEFAULTS.thickBarlineThickness;
  } else if (barline.barStyle == BarLineTypes.heavyHeavy) {
    width = lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation +
        thinBarlineWidh +
        lS * ENGRAVING_DEFAULTS.thickBarlineThickness;
  } else if (barline.barStyle == BarLineTypes.repeatRight) {
    width = lS * ENGRAVING_DEFAULTS.thickBarlineThickness +
        lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation +
        thinBarlineWidh +
        lS * ENGRAVING_DEFAULTS.repeatBarlineDotSeparation +
        lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]!;
  } else if (barline.barStyle == BarLineTypes.repeatLeft) {
    width = lS * GLYPH_ADVANCE_WIDTHS[Glyph.repeatDots]! +
        lS * ENGRAVING_DEFAULTS.repeatBarlineDotSeparation +
        thinBarlineWidh +
        lS * ENGRAVING_DEFAULTS.thinThickBarlineSeparation +
        lS * ENGRAVING_DEFAULTS.thickBarlineThickness;
  }

  return width;
}

/// Returns true if something was actually drawn
Rect? paintAccidentalsForTone(DrawingContext drawC, Clefs staff, Fifths tone, {bool noAdvance = false}) {
  if (noAdvance) {
    drawC.canvas.save();
  }

  Rect? boundingBox;

  double lineSpacing = drawC.lS;
  var accidentals = mainToneAccidentalsMapForGClef[tone]!;
  if (staff == Clefs.F) {
    accidentals = mainToneAccidentalsMapForFClef[tone]!;
  } else if (staff == Clefs.C) {
    accidentals = mainToneAccidentalsMapForCClef[tone]!;
  } else if (staff == Clefs.T) {
    accidentals = mainToneAccidentalsMapForClefLevelled(mainToneAccidentalsMapForGClef, octavesUp: -1)[tone]!;
  }

  for (var note in accidentals) {
    if (note.accidental != Accidentals.none) {
      final glyphBB = paintGlyph(
        drawC,
        accidentalGlyphMap[note.accidental]!,
        yOffset: (lineSpacing / 2) * calculateYOffsetForNote(staff, note.positionalValue),
      );
      if (boundingBox == null) {
        boundingBox = glyphBB.boundingBox;
      } else {
        boundingBox = boundingBox.expandToInclude(glyphBB.boundingBox);
      }
    }
  }

  if (noAdvance) {
    drawC.canvas.restore();
  }

  return boundingBox;
}

double calculateAccidentalsForToneWidth(DrawingContext drawC, Fifths tone) {
  double width = 0;
  final accidentals = mainToneAccidentalsMapForFClef[tone]!;
  for (var note in accidentals) {
    if (note.accidental != Accidentals.none) {
      width += calculateGlyphWidth(drawC, accidentalGlyphMap[note.accidental]!);
    }
  }
  return width;
}

Rect paintTimeSignature(DrawingContext drawC, Attributes attributes, {bool noAdvance = false}) {
  Rect timeBB = paintGlyph(drawC, GLYPHRANGE_MAP[GlyphRange.timeSignatures]!.glyphs[attributes.time!.beats],
          yOffset: -drawC.lS, noAdvance: true)
      .boundingBox;
  timeBB = timeBB.expandToInclude(paintGlyph(
          drawC, GLYPHRANGE_MAP[GlyphRange.timeSignatures]!.glyphs[attributes.time!.beatType],
          yOffset: drawC.lS, noAdvance: noAdvance)
      .boundingBox);
  return timeBB;
}

calculateTimeSignatureWidth(DrawingContext drawC, Attributes attributes) {
  return calculateGlyphWidth(drawC, GLYPHRANGE_MAP[GlyphRange.timeSignatures]!.glyphs[attributes.time!.beatType]);
}
