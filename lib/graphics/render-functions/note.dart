import 'package:flutter/material.dart';

import '../../musicXML/data.dart';
import '../generated/engraving-defaults.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-anchors.dart';
import '../generated/glyph-bboxes.dart';
import '../generated/glyph-definitions.dart';
import '../generated/glyph-range-definitions.dart';
import '../notes.dart';
import 'DrawingContext.dart';
import 'beam.dart';
import 'glyph.dart';

paintLedgers(DrawingContext drawC, Clefs staff, Fifths tone, NotePosition note) {
  int numLedgersToDraw = 0;
  switch (staff) {
    case Clefs.G:
      {
        if (note.positionalValue > topStaffLineNoteGClef.positionalValue + 1) {
          numLedgersToDraw = ((note.positionalValue - topStaffLineNoteGClef.positionalValue) / 2).floor();
        } else if (note.positionalValue < bottomStaffLineNoteGClef.positionalValue - 1) {
          numLedgersToDraw = ((note.positionalValue - bottomStaffLineNoteGClef.positionalValue) / 2).ceil();
        }
        break;
      }
    case Clefs.F:
      {
        if (note.positionalValue > topStaffLineNoteFClef.positionalValue + 1) {
          numLedgersToDraw = ((note.positionalValue - topStaffLineNoteFClef.positionalValue) / 2).floor();
        } else if (note.positionalValue < bottomStaffLineNoteFClef.positionalValue - 1) {
          numLedgersToDraw = ((note.positionalValue - bottomStaffLineNoteFClef.positionalValue) / 2).ceil();
        }
      }
    case Clefs.C:
      {
        if (note.positionalValue > topStaffLineNoteCClef.positionalValue + 1) {
          numLedgersToDraw = ((note.positionalValue - topStaffLineNoteCClef.positionalValue) / 2).floor();
        } else if (note.positionalValue < bottomStaffLineNoteCClef.positionalValue - 1) {
          numLedgersToDraw = ((note.positionalValue - bottomStaffLineNoteCClef.positionalValue) / 2).ceil();
        }
      }
    case Clefs.T:
      {
        if (note.positionalValue > topStaffLineNoteTClef.positionalValue + 1) {
          numLedgersToDraw = ((note.positionalValue - topStaffLineNoteTClef.positionalValue) / 2).floor();
        } else if (note.positionalValue < bottomStaffLineNoteTClef.positionalValue - 1) {
          numLedgersToDraw = ((note.positionalValue - bottomStaffLineNoteTClef.positionalValue) / 2).ceil();
        }
      }
  }

  double lineSpacing = drawC.lS;
  final paint = Paint()..color = Colors.black;
  paint.strokeWidth = lineSpacing * ENGRAVING_DEFAULTS.staffLineThickness;
  double noteWidth = GLYPH_ADVANCE_WIDTHS[singleNoteHeadByLength[note.length]!]! * lineSpacing;
  double ledgerLength = noteWidth * 1.5;
  for (int i = numLedgersToDraw; i != 0;) {
    if (i < 0) {
      double pos = (-i * 2) * (lineSpacing / 2) + drawC.staffHeight;
      drawC.canvas.drawLine(Offset(-((ledgerLength - noteWidth) / 2), pos),
          Offset(-((ledgerLength - noteWidth) / 2) + ledgerLength, pos), paint);
      i++;
    } else {
      double pos = -(i * 2) * (lineSpacing / 2);
      drawC.canvas.drawLine(Offset(-((ledgerLength - noteWidth) / 2), pos),
          Offset(-((ledgerLength - noteWidth) / 2) + ledgerLength, pos), paint);
      i--;
    }
  }
}

class PitchNoteRenderMeasurements {
  PitchNoteRenderMeasurements(this.boundingBox, this.noteAnchors);

  final Rect boundingBox;
  final GlyphAnchor? noteAnchors;
}

paintPitchNote(DrawingContext drawC, PitchNote note, {bool noAdvance = false}) {
  final notePosition = note.notePosition;
  final lS = drawC.lS;
  final tone = drawC.latestAttributes.key!.fifths;
  final staff = drawC.latestAttributes.clefs!.firstWhere((clef) => clef.staffNumber == note.staff).sign;
  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue);
  bool drawNoteWithStem = note.beams.isEmpty;

  if (noAdvance) {
    drawC.canvas.save();
  }

  drawC.canvas.translate(
    0,
    (drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1),
  );

  final noteGlyph = drawNoteWithStem
      ? (note.stem == StemValue.up
          ? singleNoteUpByLength[notePosition.length]!
          : singleNoteDownByLength[notePosition.length]!)
      : singleNoteHeadByLength[notePosition.length]!;

  paintLedgers(drawC, staff, tone, notePosition);

  paintGlyph(
    drawC,
    noteGlyph,
    yOffset: (lS / 2) * offset,
    noAdvance: true,
    color: note.color,
  );

  // Augmentation dot(s): each dot lengthens the previous duration by half. Drawn just
  // right of the note head with a small gap, then dot-to-dot at the same spacing. A note
  // on a staff line (even half-line-space offset) places its dot in the space above
  // (standard engraving); a note already in a space keeps the dot on the same y.
  if (note.dots > 0) {
    final headWidth = GLYPH_ADVANCE_WIDTHS[singleNoteHeadByLength[notePosition.length]!]! * lS;
    final dotWidth = GLYPH_ADVANCE_WIDTHS[Glyph.augmentationDot]! * lS;
    const dotGapInLineSpaces = 0.25;
    final dotGap = dotGapInLineSpaces * lS;
    final dotYHalfSpaces = offset.isEven ? offset - 1 : offset;
    final dotYOffset = (lS / 2) * dotYHalfSpaces;
    drawC.canvas.save();
    drawC.canvas.translate(headWidth + dotGap, 0);
    for (var i = 0; i < note.dots; i++) {
      paintGlyph(drawC, Glyph.augmentationDot, yOffset: dotYOffset, noAdvance: true, color: note.color);
      drawC.canvas.translate(dotWidth + dotGap, 0);
    }
    drawC.canvas.restore();
  }

  if (note.beams.isNotEmpty && !note.chord) {
    final noteAnchor = GLYPH_ANCHORS[noteGlyph];

    final currentBeamPointMapForThisId = drawC.currentBeamPointsPerID[note.beams.first.id] ?? {};
    drawC.currentBeamPointsPerID[note.beams.first.id] = currentBeamPointMapForThisId;

    final beamAbove = currentBeamPointMapForThisId.isNotEmpty
        ? currentBeamPointMapForThisId[1]!.first.drawAbove
        : note.stem == StemValue.up;
    for (final elmt in note.beams) {
      if (currentBeamPointMapForThisId[elmt.number] == null) {
        currentBeamPointMapForThisId[elmt.number] = [];
      }
      currentBeamPointMapForThisId[elmt.number]!.add(
        BeamPoint(
          elmt,
          drawC.canvas.localToGlobal(Offset(0, (lS / 2) * offset)),
          noteAnchor!,
          beamAbove,
        ),
      );
    }

    final openBeams = getOpenBeams(currentBeamPointMapForThisId);

    if (openBeams.isEmpty) {
      // A beam group's slope is defined ONCE by the primary beam (the smallest beam
      // number, which spans the whole group). Every higher-level (shorter) beam — e.g.
      // the sixteenth beams inside an eighth+sixteenth group — must run PARALLEL to it,
      // only shifted outwards by one beam spacing per level. Deriving each level's slope
      // from its own first/last note (the previous behaviour) tilted secondary beams
      // independently whenever the inner notes had a different pitch contour.
      final double levelGap =
          ENGRAVING_DEFAULTS.beamThickness * lS + ENGRAVING_DEFAULTS.beamSpacing * lS;
      final sortedEntries = currentBeamPointMapForThisId.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final int primaryKey = sortedEntries.first.key;
      final int outerMostKey = sortedEntries.last.key;
      final BeamPoint primaryFirst = sortedEntries.first.value.first;
      final BeamPoint primaryLast = sortedEntries.first.value.last;
      // The primary (longest) beam occupies the OUTERMOST slot so that the
      // shorter sixteenth beams sit inside it (towards the note heads), as in
      // standard engraving. The slot depth equals the deepest beam level.
      final double primaryStemLength = lS * 2 + outerMostKey * levelGap;

      // Outer edge of the primary beam at its first and last note (global coordinates).
      final Offset primaryStartGlobal;
      final Offset primaryEndGlobal;
      if (primaryFirst.drawAbove) {
        primaryStartGlobal = Offset(
          primaryFirst.notePosition.dx + primaryFirst.noteAnchor.stemUpSE.dx * lS,
          primaryFirst.notePosition.dy +
              (drawC.staffHeight / 2) -
              primaryStemLength -
              (ENGRAVING_DEFAULTS.beamThickness * lS) +
              primaryFirst.noteAnchor.stemUpSE.dy * lS,
        );
        primaryEndGlobal = Offset(
          primaryLast.notePosition.dx + primaryLast.noteAnchor.stemUpSE.dx * lS,
          primaryLast.notePosition.dy +
              (drawC.staffHeight / 2) -
              primaryStemLength -
              (ENGRAVING_DEFAULTS.beamThickness * lS) +
              primaryLast.noteAnchor.stemUpSE.dy * lS,
        );
      } else {
        primaryStartGlobal = Offset(
          primaryFirst.notePosition.dx + primaryFirst.noteAnchor.stemDownNW.dx * lS,
          primaryFirst.notePosition.dy + (drawC.staffHeight / 2) + primaryStemLength +
              primaryFirst.noteAnchor.stemDownNW.dy * lS,
        );
        primaryEndGlobal = Offset(
          primaryLast.notePosition.dx + primaryLast.noteAnchor.stemDownNW.dx * lS,
          primaryLast.notePosition.dy + (drawC.staffHeight / 2) + primaryStemLength +
              primaryLast.noteAnchor.stemDownNW.dy * lS,
        );
      }

      for (final beamPoints in sortedEntries) {
        final BeamPoint start = beamPoints.value.first;
        final BeamPoint end = beamPoints.value.last;

        // Higher levels sit one beam spacing closer to the note heads per level
        // (downwards for stem-up, upwards for stem-down) while keeping the
        // primary slope, so the longest beam stays on the outside of the group.
        final double levelShift =
            beamLevelShift(beamPoints.key, primaryKey, levelGap, start.drawAbove);

        Offset startOffset, endOffset;
        if (start.drawAbove) {
          final double startX = start.notePosition.dx + start.noteAnchor.stemUpSE.dx * lS;
          final double endX = end.notePosition.dx + end.noteAnchor.stemUpSE.dx * lS;
          final (s, e) = parallelBeamSegment(primaryStartGlobal, primaryEndGlobal, startX, endX, levelShift);
          startOffset = drawC.canvas.globalToLocal(s);
          endOffset = drawC.canvas.globalToLocal(e);
        } else {
          final double startX = start.notePosition.dx + start.noteAnchor.stemDownNW.dx * lS;
          final double endX = end.notePosition.dx + end.noteAnchor.stemDownNW.dx * lS;
          final (s, e) = parallelBeamSegment(primaryStartGlobal, primaryEndGlobal, startX, endX, levelShift);
          startOffset = drawC.canvas.globalToLocal(s);
          endOffset = drawC.canvas.globalToLocal(e);
        }

        paintBeam(drawC, startOffset, endOffset);

        for (final beamPoint in beamPoints.value) {
          Offset stemOffsetStart, stemOffsetEnd;
          if (beamPoint.drawAbove) {
            stemOffsetStart = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS,
              beamPoint.notePosition.dy + (drawC.staffHeight / 2) + beamPoint.noteAnchor.stemUpSE.dy * lS,
            ));

            final startOffsetGlobal = drawC.canvas.localToGlobal(startOffset);
            final endOffsetGlobal = drawC.canvas.localToGlobal(endOffset);

            double stemOffsetYEnd =
                ((beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS) - startOffsetGlobal.dx) *
                        ((endOffsetGlobal.dy - startOffsetGlobal.dy) / (endOffsetGlobal.dx - startOffsetGlobal.dx)) +
                    startOffsetGlobal.dy;

            stemOffsetEnd = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemUpSE.dx * lS,
              stemOffsetYEnd,
            ));
          } else {
            stemOffsetStart = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemDownNW.dx * lS,
              beamPoint.notePosition.dy + (drawC.staffHeight / 2) + beamPoint.noteAnchor.stemDownNW.dy * lS,
            ));

            final startOffsetGlobal = drawC.canvas.localToGlobal(startOffset);
            final endOffsetGlobal = drawC.canvas.localToGlobal(endOffset);

            double stemOffsetYEnd =
                ((beamPoint.notePosition.dx + beamPoint.noteAnchor.stemDownNW.dx * lS) - startOffsetGlobal.dx) *
                        ((endOffsetGlobal.dy - startOffsetGlobal.dy) / (endOffsetGlobal.dx - startOffsetGlobal.dx)) +
                    startOffsetGlobal.dy +
                    ENGRAVING_DEFAULTS.beamThickness * lS;

            stemOffsetEnd = drawC.canvas.globalToLocal(Offset(
              beamPoint.notePosition.dx + beamPoint.noteAnchor.stemDownNW.dx * lS,
              stemOffsetYEnd,
            ));
          }

          paintStem(drawC, stemOffsetStart, stemOffsetEnd);
        }
      }

      // Everything has been drawn, now it is time to reset the
      // beam context list, so that it is ready for the next
      // beam group that might come.
      drawC.currentBeamPointsPerID.remove(note.beams.first.id);
    }
  }

  // Paint a per-note accidental by standard notation rules (key signature +
  // within-measure carry-over). A coloured feedback note is a `chord` copy drawn at
  // the exact x of its black target: when the target already drew this accidental the
  // standard rule suppresses the feedback's, so we additionally repaint it ON TOP in
  // the feedback colour — but only when the sign is intrinsically required
  // (out-of-key, or a key-cancelling natural), never for an in-key pitch (which
  // carries no accidental glyph at all). This colours e.g. a played G♯ in G major
  // green/red/yellow without re-stating an in-key F♯.
  final bool standardPaint = shouldPaintAccidental(drawC, staff, notePosition);
  final bool colourOverlay = note.chord &&
      note.color != Colors.black &&
      accidentalIsIntrinsicallyRequired(drawC, staff, notePosition);
  final bool paintAccidental = standardPaint || colourOverlay;
  if (paintAccidental) {
    final accidentalGlyph = accidentalGlyphMap[notePosition.accidental]!;

    drawC.canvas.translate(-GLYPH_ADVANCE_WIDTHS[accidentalGlyph]! * lS - ENGRAVING_DEFAULTS.barlineSeparation * lS, 0);

    paintGlyph(
      drawC,
      accidentalGlyph,
      yOffset: (lS / 2) * calculateYOffsetForNote(staff, notePosition.positionalValue),
      noAdvance: true,
      color: note.color,
    );

    // Register the accidental so subsequent notes of the same pitch in this bar can
    // suppress their own sign (carry-over rule). Feedback (chord) copies are visual
    // overlays only and must never mutate the carry-over state.
    if (!note.chord) {
      drawC.registerMeasureAccidental(staff, notePosition.tone, notePosition.octave, notePosition.accidental);
    }
  }

  drawC.canvas.translate(
    0,
    -(drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1),
  );

  if (noAdvance) {
    drawC.canvas.restore();
  }
}

double durationToRestLengthIndex(DrawingContext drawC, int duration) {
  return ((drawC.latestAttributes.divisions! * 4) / duration) / 2;
}

paintRestNote(DrawingContext drawC, RestNote note, {bool noAdvance = false}) {
  drawC.canvas.translate(0, (drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1));

  var restGlyph = GLYPHRANGE_MAP[GlyphRange.rests]!
      .glyphs[durationToRestLengthIndex(drawC, note.duration).round() + 3]; // whole rest begins at index 3

  paintGlyph(drawC, restGlyph, noAdvance: noAdvance);

  drawC.canvas.translate(0, -(drawC.staffHeight + drawC.staffsSpacing) * (note.staff - 1));
}

/// Returns true when an accidental glyph must be rendered before [note].
///
/// Rules (per standard notation, see
/// https://www.lehrklaenge.de/PHP/Notation/VorzeichenNotation.php):
/// 1. An accidental written once in a bar carries over to all subsequent notes
///    of the **same tone and octave** on the same staff within that bar.
/// 2. It is cancelled only by a natural sign (♮) or the start of a new bar.
///
/// This function is **pure** — it does not mutate [drawC].
/// Callers that actually paint the accidental must follow up with
/// [DrawingContext.registerMeasureAccidental] so that carry-over tracking stays
/// consistent for subsequent notes in the same bar.
bool shouldPaintAccidental(DrawingContext drawC, Clefs staff, NotePosition note) {
  if (note.accidental == Accidentals.none) return false;

  final tone = drawC.latestAttributes.key!.fifths;

  // Key-signature accidentals (statically applied to all relevant pitches).
  final List<NotePosition> keyAccidentals =
      staff == Clefs.G ? mainToneAccidentalsMapForGClef[tone]! : mainToneAccidentalsMapForFClef[tone]!;
  final bool inKeySig = keyAccidentals.any((a) =>
      a.tone == note.tone &&
      (a.accidental == note.accidental || note.accidental == Accidentals.natural));

  // Within-measure carry-over state for this exact pitch (tone + octave).
  final Accidentals? measureAcc =
      drawC.getMeasureAccidental(staff, note.tone, note.octave);

  if (note.accidental == Accidentals.natural) {
    // A natural already written for this exact pitch this bar carries over, so a
    // repeated natural (e.g. the target note and its chord/feedback copy on the
    // same beat) is redundant and must be suppressed.
    if (measureAcc == Accidentals.natural) return false;
    // A natural is only needed when the note would otherwise be altered —
    // either by the key signature or by a within-measure accidental.
    return inKeySig || (measureAcc != null && measureAcc != Accidentals.natural);
  } else if (measureAcc != null) {
    // An accidental was already written for this pitch this bar: only repaint
    // if it differs (e.g. the note changes from sharp to flat mid-bar).
    return measureAcc != note.accidental;
  } else {
    // No within-measure record yet: suppress only if the key signature
    // already implies this exact accidental.
    return !inKeySig;
  }
}

/// Whether [note]'s accidental is intrinsically required by the key signature alone,
/// ignoring any within-measure carry-over. A sharp/flat is required only when it is
/// **not** already implied by the key signature; a natural is required only when it
/// **cancels** a key-signature accidental. `Accidentals.none` is never required.
///
/// Used to repaint a coloured feedback (chord) overlay on top of its target's black
/// accidental even after the carry-over rule has suppressed it, without ever drawing
/// a sign for an in-key pitch.
bool accidentalIsIntrinsicallyRequired(DrawingContext drawC, Clefs staff, NotePosition note) {
  if (note.accidental == Accidentals.none) return false;

  final tone = drawC.latestAttributes.key!.fifths;
  final List<NotePosition> keyAccidentals =
      staff == Clefs.G ? mainToneAccidentalsMapForGClef[tone]! : mainToneAccidentalsMapForFClef[tone]!;
  final bool inKeySig = keyAccidentals.any((a) =>
      a.tone == note.tone &&
      (a.accidental == note.accidental || note.accidental == Accidentals.natural));

  // A natural is meaningful only if it cancels a key-signature accidental; any other
  // accidental is meaningful only when the key signature does not already imply it.
  return note.accidental == Accidentals.natural ? inKeySig : !inKeySig;
}

PitchNoteRenderMeasurements calculateNoteWidth(DrawingContext drawC, PitchNote note) {
  final notePosition = note.notePosition;
  final lineSpacing = drawC.lS;
  final staff = drawC.latestAttributes.clefs!.firstWhere((clef) => clef.staffNumber == note.staff).sign;
  int offset = calculateYOffsetForNote(staff, notePosition.positionalValue);
  bool drawBeamedNote = note.beams.isEmpty;

  final noteGlyph = drawBeamedNote
      ? (note.stem == StemValue.up
          ? singleNoteUpByLength[notePosition.length]!
          : singleNoteDownByLength[notePosition.length]!)
      : singleNoteHeadByLength[notePosition.length]!;

  double leftBorder = 0;
  double rightBorder = GLYPH_ADVANCE_WIDTHS[noteGlyph]! * lineSpacing;
  double topBorder = (lineSpacing / 2) * offset + GLYPH_BBOXES[noteGlyph]!.northEast.dy;
  double bottomBorder = (lineSpacing / 2) * offset + GLYPH_BBOXES[noteGlyph]!.northEast.dy;

  // Augmentation dots add to the note's right-hand footprint so the next column does
  // not overlap them (head width + N × (gap + dot width)).
  if (note.dots > 0) {
    final headWidth = GLYPH_ADVANCE_WIDTHS[singleNoteHeadByLength[notePosition.length]!]! * lineSpacing;
    final dotWidth = GLYPH_ADVANCE_WIDTHS[Glyph.augmentationDot]! * lineSpacing;
    const dotGapInLineSpaces = 0.25;
    final dotGap = dotGapInLineSpaces * lineSpacing;
    final dottedRight = headWidth + note.dots * (dotGap + dotWidth);
    if (dottedRight > rightBorder) rightBorder = dottedRight;
  }

  if (shouldPaintAccidental(drawC, staff, notePosition)) {
    final accidentalGlyph = accidentalGlyphMap[notePosition.accidental]!;
    leftBorder =
        -GLYPH_ADVANCE_WIDTHS[accidentalGlyph]! * lineSpacing - ENGRAVING_DEFAULTS.barlineSeparation * lineSpacing;

    final potTopBorder = (lineSpacing / 2) * calculateYOffsetForNote(staff, notePosition.positionalValue) +
        GLYPH_BBOXES[accidentalGlyph]!.northEast.dy;

    final potBottomBorder = (lineSpacing / 2) * calculateYOffsetForNote(staff, notePosition.positionalValue) +
        GLYPH_BBOXES[accidentalGlyph]!.southWest.dy;

    topBorder = potTopBorder < topBorder ? potTopBorder : topBorder;
    bottomBorder = potBottomBorder < bottomBorder ? potBottomBorder : bottomBorder;
  }

  return PitchNoteRenderMeasurements(
    Rect.fromLTRB(leftBorder, topBorder, rightBorder, bottomBorder),
    !drawBeamedNote ? GLYPH_ANCHORS[noteGlyph]!.translate(Offset(0, (lineSpacing / 2) * offset)) : null,
  );
}

const stdNotePositionGClef = NotePosition(tone: BaseTones.B, octave: 2, length: NoteLength.quarter);
const stdNotePositionFClef = NotePosition(tone: BaseTones.D, octave: 1, length: NoteLength.quarter);
const stdNotePositionCClef = NotePosition(tone: BaseTones.C, octave: 2, length: NoteLength.quarter);
const stdNotePositionTClef = NotePosition(tone: BaseTones.B, octave: 1, length: NoteLength.quarter);

const Map<Clefs, NotePosition> stdNotePosition = {
  Clefs.G: stdNotePositionGClef,
  Clefs.F: stdNotePositionFClef,
  Clefs.C: stdNotePositionCClef,
  Clefs.T: stdNotePositionTClef,
};

const topStaffLineNoteGClef = NotePosition(tone: BaseTones.F, octave: 3, length: NoteLength.quarter);
const bottomStaffLineNoteGClef = NotePosition(tone: BaseTones.E, octave: 2, length: NoteLength.quarter);

const topStaffLineNoteFClef = NotePosition(tone: BaseTones.A, octave: 1, length: NoteLength.quarter);
const bottomStaffLineNoteFClef = NotePosition(tone: BaseTones.G, octave: 0, length: NoteLength.quarter);

const topStaffLineNoteCClef = NotePosition(tone: BaseTones.G, octave: 2, length: NoteLength.quarter);
const bottomStaffLineNoteCClef = NotePosition(tone: BaseTones.F, octave: 1, length: NoteLength.quarter);

const topStaffLineNoteTClef = NotePosition(tone: BaseTones.F, octave: 2, length: NoteLength.quarter);
const bottomStaffLineNoteTClef = NotePosition(tone: BaseTones.E, octave: 1, length: NoteLength.quarter);

const Map<Clefs, NotePosition> topStaffLineNote = {
  Clefs.G: topStaffLineNoteGClef,
  Clefs.F: topStaffLineNoteFClef,
  Clefs.C: topStaffLineNoteCClef,
  Clefs.T: topStaffLineNoteTClef,
};

const Map<Clefs, NotePosition> bottomStaffLineNote = {
  Clefs.G: bottomStaffLineNoteGClef,
  Clefs.F: bottomStaffLineNoteFClef,
  Clefs.C: bottomStaffLineNoteCClef,
  Clefs.T: bottomStaffLineNoteTClef,
};

int calculateYOffsetForNote(Clefs clef, int positionalValue) {
  int diff = 0;
  if (clef == Clefs.G) {
    diff = stdNotePositionGClef.positionalValue - positionalValue;
  } else if (clef == Clefs.F) {
    diff = stdNotePositionFClef.positionalValue - positionalValue;
  } else if (clef == Clefs.C) {
    diff = stdNotePositionCClef.positionalValue - positionalValue;
  } else if (clef == Clefs.T) {
    diff = stdNotePositionTClef.positionalValue - positionalValue;
  }
  return diff;
}
