import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../musicXML/data.dart';
import '../generated/engraving-defaults.dart';
import '../generated/glyph-advance-widths.dart';
import '../generated/glyph-definitions.dart';
import '../graphics-model/measure.dart';
import '../notes.dart';
import 'DrawingContext.dart';
import 'common.dart';
import 'glyph.dart';
import 'note.dart';
import 'staff.dart';

paintMeasure(Measure measure, DrawingContext drawC) {
  final (grid, positioned) = createGridForMeasure(measure, drawC);
  double leftEnd = 0;
  if (measure.attributes == null) {
    leftEnd = drawC.canvas.getTranslation().dx;
  }

  MeasureAttributesGeometry? attributesGeom;

  grid.forEachIndexed((columnIndex, column) {
    final measurements = column
        .whereType<Note>()
        .map((element) => element is PitchNote
            ? calculateNoteWidth(drawC, element)
            : calculateRestWidth(drawC, element as RestNote))
        .toList();
    final alignmentOffset = calculateColumnAlignment(drawC, measurements);

    // Decorative next-note marker: drawn first so a background band sits behind the glyphs
    // (but above the already-painted staff lines) and a cursor overlays the column. The target
    // note and its overlapping feedback chord copy share this column, so one marker suffices.
    final highlightNote =
        column.whereType<Note>().firstWhereOrNull((note) => note.highlight != null);
    if (highlightNote != null) {
      final contentWidth = alignmentOffset.right - alignmentOffset.left;
      final halfGap = drawC.lS * drawC.spacingFactor / 2;
      // Full vertical ink extent (head + stem + accidental) of the highlighted note in the
      // band's coordinate frame (y = 0 at the staff top line). Used to grow the band/cursor
      // so it fully encloses notes whose head/stem sit far above or below the staff on
      // ledger lines. Null for rest highlights (no pitched extent).
      (double, double)? noteExtent;
      if (highlightNote is PitchNote) {
        noteExtent = noteVerticalExtent(drawC, highlightNote);
      }
      paintNoteHighlight(
          drawC, highlightNote.highlight!, contentWidth, halfGap, noteExtent);
    }

    drawC.canvas.translate(alignmentOffset.left.abs(), 0);
    column.forEachIndexed((index, measureContent) {
      bool isLastElement = index == column.length - 1;
      switch (measureContent.runtimeType) {
        case Barline:
          break;
        case Attributes:
          {
            attributesGeom =
                paintMeasureAttributes(measureContent as Attributes, drawC);
            leftEnd = drawC.canvas.getTranslation().dx;
            break;
          }
        case Direction:
          {
            paintDirection(measureContent as Direction, drawC);
            break;
          }
        case PitchNote:
          {
            paintPitchNote(drawC, measureContent as PitchNote, noAdvance: true);
            break;
          }
        case RestNote:
          {
            paintRestNote(drawC, measureContent as RestNote,
                noAdvance: !isLastElement);
            break;
          }
        default:
          {
            throw FormatException(
                '${measureContent.runtimeType} is an invalid MeasureContent type');
          }
      }
    });

    drawC.canvas.translate(alignmentOffset.right, 0);

    // TODO: Spacing between columns, currently static, probably needs to be dynamic
    // to justify measures for the whole line
    if (column.isNotEmpty && columnIndex < grid.length - 1) {
      drawC.canvas.translate(drawC.lS * drawC.spacingFactor, 0);
    }
  });

  final rightEnd = drawC.canvas.getTranslation().dx;
  final measureWidth = rightEnd - leftEnd;

  for (var xPosElement in positioned) {
    drawC.canvas.save();
    drawC.canvas.translate(-measureWidth * xPosElement.xPosition, 0);
    switch (xPosElement.measureContent.runtimeType) {
      case PitchNote:
        {
          paintPitchNote(drawC, xPosElement.measureContent as PitchNote,
              noAdvance: true);
          break;
        }
      case RestNote:
        {
          drawC.canvas.translate(-GLYPH_ADVANCE_WIDTHS[Glyph.restHalf]! / 2, 0);
          paintRestNote(drawC, xPosElement.measureContent as RestNote,
              noAdvance: true);
          break;
        }
      default:
        {
          throw FormatException(
              '${xPosElement.measureContent.runtimeType} is an invalid MeasureContent type');
        }
    }
    drawC.canvas.restore();
  }

  final xyTranslation = drawC.canvas.getTranslation();
  final List<Rect> stavesBounds = [];
  for (var i = 0; i < drawC.latestAttributes.staves!; i++) {
    stavesBounds.add(Rect.fromLTRB(
        leftEnd,
        xyTranslation.dy + (drawC.staffHeight * i) + (drawC.staffsSpacing * i),
        rightEnd,
        xyTranslation.dy +
            drawC.staffHeight * (i + 1) +
            drawC.staffsSpacing * i));
  }
  final measureRectLT = Offset(leftEnd, xyTranslation.dy);
  final measureRectRB = Offset(
      rightEnd,
      xyTranslation.dy +
          (drawC.staffHeight * drawC.latestAttributes.staves!) +
          (drawC.staffsSpacing * (drawC.latestAttributes.staves! - 1)));

  final measureRect = Rect.fromPoints(measureRectLT, measureRectRB);
  final measureGeom = MeasureGeometry(measureRect, stavesBounds);
  measureGeom.attributesGeometry = attributesGeom;
  if (attributesGeom != null) {
    // drawC.debugDrawBB(attributesGeom!.boundingBox);
  }
  drawC.measuresPerPart[drawC.currentPart].add(measureGeom);
}

/// Draws the decorative next-note [highlight] for the current column. The canvas is expected to
/// be translated so that local x = 0 is the column's left edge and local y = 0 the top staff
/// line. [contentWidth] is the column's visual width (leftmost to rightmost glyph extent) and
/// [halfGap] half the spacing to the neighbouring columns, so a background band reaches to the
/// middle of the gap on either side. Purely visual: it never advances the canvas.
void paintNoteHighlight(
    DrawingContext drawC, NoteHighlight highlight, double contentWidth, double halfGap,
    (double top, double bottom)? noteExtent) {
  final staves = drawC.latestAttributes.staves ?? 1;
  final blockHeight =
      drawC.staffHeight * staves + drawC.staffsSpacing * (staves - 1);

  drawC.canvas.save();
  switch (highlight.style) {
    case NoteHighlightStyle.background:
      _paintBackgroundHighlight(drawC, highlight, contentWidth, halfGap, noteExtent, blockHeight);
      break;
    case NoteHighlightStyle.cursor:
      _paintCursorHighlight(drawC, highlight, contentWidth, noteExtent, blockHeight);
      break;
  }
  drawC.canvas.restore();
}

/// Small breathing space so a highlight border never sits directly on the glyph ink.
double _highlightPad(DrawingContext drawC) => drawC.lS * 0.35;

/// Translucent rounded band behind the column, reaching to the middle of the gap on either
/// side. The staff-anchored frame is the default bound; it grows outward so the whole note
/// (head, stem and accidental) stays enclosed when it reaches beyond that frame.
void _paintBackgroundHighlight(DrawingContext drawC, NoteHighlight highlight, double contentWidth,
    double halfGap, (double top, double bottom)? noteExtent, double blockHeight) {
  final lS = drawC.lS;
  final pad = _highlightPad(drawC);
  final margin = lS * 1.5;
  double top = -margin;
  double bottom = blockHeight + margin;
  if (noteExtent != null) {
    final noteTop = noteExtent.$1 - pad;
    final noteBottom = noteExtent.$2 + pad;
    if (noteTop < top) top = noteTop;
    if (noteBottom > bottom) bottom = noteBottom;
  }
  final rect = Rect.fromLTRB(-halfGap, top, contentWidth + halfGap, bottom);
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(lS * 0.4));
  drawC.canvas.drawRRect(
      rrect, Paint()..color = highlight.color.withValues(alpha: 0.16));
  drawC.canvas.drawRRect(
      rrect,
      Paint()
        ..color = highlight.color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = lS * 0.12);
}

/// Caret above the column plus a vertical guide line through it, extended so it still spans
/// very high / very low notes (head + stem).
void _paintCursorHighlight(DrawingContext drawC, NoteHighlight highlight, double contentWidth,
    (double top, double bottom)? noteExtent, double blockHeight) {
  final lS = drawC.lS;
  final pad = _highlightPad(drawC);
  final centerX = contentWidth / 2;
  double caretTop = -lS * 2.4;
  double lineBottom = blockHeight + lS * 0.5;
  if (noteExtent != null) {
    final caretHeight = lS * 0.95;
    final noteTop = noteExtent.$1 - pad - caretHeight;
    final noteBottom = noteExtent.$2 + pad;
    if (noteTop < caretTop) caretTop = noteTop;
    if (noteBottom > lineBottom) lineBottom = noteBottom;
  }
  final caretBottom = caretTop + lS * 0.95;
  final caretHalfWidth = lS * 0.6;
  drawC.canvas.drawLine(
      Offset(centerX, caretBottom),
      Offset(centerX, lineBottom),
      Paint()
        ..color = highlight.color.withValues(alpha: 0.75)
        ..strokeWidth = lS * 0.18
        ..strokeCap = StrokeCap.round);
  final caret = Path()
    ..moveTo(centerX - caretHalfWidth, caretTop)
    ..lineTo(centerX + caretHalfWidth, caretTop)
    ..lineTo(centerX, caretBottom)
    ..close();
  drawC.canvas.drawPath(caret, Paint()..color = highlight.color);
}

Rect calculateColumnAlignment(
    DrawingContext drawC, Iterable<PitchNoteRenderMeasurements> measurements) {
  final leftOffset = measurements.fold<double>(
      0, (value, element) => min(value, element.boundingBox.left));
  final rightOffset = measurements.fold<double>(
      0, (value, element) => max(value, element.boundingBox.right));

  return Rect.fromLTRB(leftOffset, 0, rightOffset, 0);
}

(List<List<MeasureContent>> grid, List<XPositionedMeasureContent> positioned)
    createGridForMeasure(Measure measure, DrawingContext drawC) {
  final columnsOnFourFour = drawC.latestAttributes.divisions! * 4;
  final currentTimeFactor = drawC.latestAttributes.time!.beats /
      drawC.latestAttributes.time!.beatType;
  final columnsOnCurrentTime = columnsOnFourFour * currentTimeFactor;
  if (columnsOnCurrentTime % 1 != 0) {
    // Not a whole number. Means, the divisions number does not work for the Time. This is an error!
    throw FormatException(
        'Found divisions of ${drawC.latestAttributes.divisions} on a Time of ${drawC.latestAttributes.time!.beats}/${drawC.latestAttributes.time!.beatType}, which does not work.');
  }
  final measureHasAttributes = measure.attributes != null;
  final List<List<MeasureContent>> grid = List.generate(
      columnsOnCurrentTime.toInt() + (measureHasAttributes ? 1 : 0), (i) => []);
  final List<XPositionedMeasureContent> positioned = [];
  int currentColumnPointer = 0;
  int? chordDuration;
  List<MeasureContent> currentColumn = grid[currentColumnPointer];
  measure.contents.forEachIndexed((index, element) {
    if (currentColumnPointer >= grid.length &&
        element.runtimeType != Backup &&
        element.runtimeType != Barline) {
      throw FormatException(
          'currentColumnPointer can only point beyond end of grid length, if next element is Backup or Barline. But was: ${element.runtimeType.toString()}');
    } else if (currentColumnPointer < grid.length) {
      currentColumn = grid[currentColumnPointer];
    }
    switch (element.runtimeType) {
      case Barline:
        currentColumn.add(element);
        break;
      case Attributes:
        {
          currentColumn.add(element);
          currentColumnPointer++;
          break;
        }
      case Direction:
        {
          currentColumn.add(element);
          break;
        }
      case RestNote:
      case PitchNote:
        {
          final note = element as Note;
          if (note is PitchNote) {
            note.beams
                .toList(); // This makes the lazy xml parser actually traverse all beams
          }

          // A whole-bar rest is centred via [positioned]; every other note/rest is placed in
          // the current rhythmic column. Chord members (incl. a feedback rest copy) share the
          // column/position of the target they overlap.
          final isWholeBarRest =
              note is RestNote && columnsOnCurrentTime / note.duration == 1;
          if (isWholeBarRest) {
            positioned.add(XPositionedMeasureContent(
                xPosition: 0.5, measureContent: note));
          } else {
            currentColumn.add(note);
          }

          // The rhythmic grid only advances when the current chord group ends. A chord note
          // overlaps the preceding note at the same x and never advances; the deferred
          // duration (the target's) is applied once the next non-chord element begins. This
          // is what keeps a target/feedback pair (note OR rest) on a single rhythmic column.
          final nextElement = index < measure.contents.length - 1
              ? measure.contents.elementAt(index + 1)
              : null;
          final nextIsChordNote = nextElement is Note && nextElement.chord;
          if (!note.chord) {
            if (nextIsChordNote) {
              chordDuration = note.duration;
            } else {
              currentColumnPointer += note.duration;
            }
          } else if (!nextIsChordNote) {
            if (chordDuration == null) {
              throw const FormatException(
                  'End of a chord reached, should have chordDuration, but is null.');
            }
            currentColumnPointer += chordDuration!;
            chordDuration = null;
          }
          break;
        }
      case Forward:
        {
          if (element is Forward) {
            currentColumnPointer += element.duration;
          }
          break;
        }
      case Backup:
        {
          if (element is Backup) {
            currentColumnPointer -= element.duration;
          }
          break;
        }
      default:
        {
          throw FormatException(
              '${element.runtimeType} is an unknown MeasureContent type');
        }
    }
  });
  return (grid, positioned);
}

paintMeasureAttributes(Attributes attributes, DrawingContext drawC) {
  final fifths = attributes.key?.fifths;
  final Attributes(:staves, :clefs) = attributes;
  final lS = drawC.lS;

  if (staves != null && clefs != null) {
    final sortedClefs = clefs.sorted((a, b) => a.staffNumber - b.staffNumber);

    Rect? boundingBox;

    //initial padding from start of the music line
    drawC.canvas.translate(5, 0);

    if (fifths != null) {
      Rect? clefBB;

      sortedClefs.forEachIndexed((index, clef) {
        final glyphBB = paintGlyph(drawC, clefToGlyphMap[clef.sign]!,
            yOffset: staffYPos(drawC, clef.staffNumber) +
                (lS * clefToPositionOffsetMap[clef.sign]!),
            noAdvance: index < (clefs.length - 1));
        if (clefBB == null) {
          clefBB = glyphBB.boundingBox;
        } else {
          clefBB = clefBB!.expandToInclude(glyphBB.boundingBox);
        }
      });
      boundingBox = clefBB;
      drawC.canvas.translate(drawC.lS * 1, 0);

      Rect? accidentalBB;
      sortedClefs.forEachIndexed((index, clef) {
        drawC.canvas.translate(0, staffYPos(drawC, clef.staffNumber));
        final glyphBB = paintAccidentalsForTone(drawC, clef.sign, fifths,
            noAdvance: index < (clefs.length - 1));
        drawC.canvas.translate(0, -staffYPos(drawC, clef.staffNumber));
        if (glyphBB != null) {
          if (accidentalBB == null) {
            accidentalBB = glyphBB;
          } else {
            accidentalBB = accidentalBB!.expandToInclude(glyphBB);
          }
        }
      });
      if (accidentalBB != null && !accidentalBB!.isEmpty) {
        boundingBox = boundingBox!.expandToInclude(accidentalBB!);
        drawC.canvas.translate(drawC.lS * 1, 0);
      }
    }

    if (attributes.time != null && attributes.time!.draw) {
      Rect? timesBB;
      sortedClefs.forEachIndexed((index, clef) {
        drawC.canvas.translate(0, staffYPos(drawC, clef.staffNumber));
        final glyphBB = paintTimeSignature(drawC, attributes,
            noAdvance: index < (clefs.length - 1));
        drawC.canvas.translate(0, -staffYPos(drawC, clef.staffNumber));
        if (timesBB == null) {
          timesBB = glyphBB;
        } else {
          timesBB = timesBB!.expandToInclude(glyphBB);
        }
      });

      if (timesBB != null) {
        boundingBox = boundingBox!.expandToInclude(timesBB!);
      }
      drawC.canvas.translate(drawC.lS * 1, 0);
    }

    if (boundingBox != null) {
      final measureAttrGeom = MeasureAttributesGeometry(boundingBox);
      return measureAttrGeom;
    } else {
      return null;
    }
  }
}

calculateMeasureAttributesWidth(Attributes attributes, DrawingContext drawC) {
  return (attributes.key != null
          ? calculateAccidentalsForToneWidth(drawC, attributes.key!.fifths)
          : 0) +
      (attributes.key != null && attributes.time != null
          ? drawC.lS * ENGRAVING_DEFAULTS.barlineSeparation * 2
          : 0) +
      (attributes.time != null
          ? calculateTimeSignatureWidth(drawC, attributes)
          : 0);
}

paintDirection(Direction direction, DrawingContext drawC) {}
