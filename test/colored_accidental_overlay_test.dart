import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_music_notes/ExtendedCanvas.dart';
import 'package:sheet_music_notes/graphics/notes.dart';
import 'package:sheet_music_notes/graphics/render-functions/DrawingContext.dart';
import 'package:sheet_music_notes/graphics/render-functions/note.dart';
import 'package:sheet_music_notes/musicXML/data.dart';

/// A single empty G-major measure so [DrawingContext] picks up the F♯ key signature.
Score gMajorScore() => Score([
      Part([
        Measure([
          Attributes(1, MusicalKey(CircleOfFifths.G_E.v, KeyMode.major), 1,
              [Clef(1, Clefs.G)], Time(4, 4)),
        ])
      ])
    ]);

DrawingContext gMajorContext() {
  final recorder = ui.PictureRecorder();
  final canvas = XCanvas(ui.Canvas(recorder));
  return DrawingContext(gMajorScore(), 36.0, 1.0, canvas, const Size(1100, 360), 72.0);
}

NotePosition pos(BaseTones tone, int octave, Accidentals accidental) =>
    NotePosition(tone: tone, octave: octave, accidental: accidental, length: NoteLength.quarter);

void main() {
  group('shouldPaintAccidental — key-signature suppression', () {
    test('an in-key F♯ in G major draws no sharp glyph', () {
      final drawC = gMajorContext();
      expect(shouldPaintAccidental(drawC, Clefs.G, pos(BaseTones.F, 3, Accidentals.sharp)), isFalse);
    });

    test('the same in-key F♯ in another octave still draws no sharp glyph', () {
      final drawC = gMajorContext();
      // The key signature applies to F in every octave, so a lower/upper F♯ is equally implicit.
      expect(shouldPaintAccidental(drawC, Clefs.G, pos(BaseTones.F, 2, Accidentals.sharp)), isFalse);
      expect(shouldPaintAccidental(drawC, Clefs.G, pos(BaseTones.F, 4, Accidentals.sharp)), isFalse);
    });

    test('an out-of-key C♯ in G major draws its accidental', () {
      final drawC = gMajorContext();
      expect(shouldPaintAccidental(drawC, Clefs.G, pos(BaseTones.C, 3, Accidentals.sharp)), isTrue);
    });
  });

  group('shouldPaintAccidental — natural carry-over (no duplicate ♮)', () {
    test('a first F♮ in G major needs a natural, a repeat of the same pitch in the bar does not', () {
      final drawC = gMajorContext();
      final fNatural = pos(BaseTones.F, 3, Accidentals.natural);

      // First F♮ cancels the key-signature F♯ -> draw it and register the carry-over.
      expect(shouldPaintAccidental(drawC, Clefs.G, fNatural), isTrue);
      drawC.registerMeasureAccidental(Clefs.G, fNatural.tone, fNatural.octave, fNatural.accidental);

      // The target note and its chord/feedback copy share the same beat: the second
      // natural is redundant because the first one already carries over.
      expect(shouldPaintAccidental(drawC, Clefs.G, fNatural), isFalse);
    });

    test('a natural in one octave does not suppress a natural in another octave', () {
      final drawC = gMajorContext();
      final low = pos(BaseTones.F, 3, Accidentals.natural);
      drawC.registerMeasureAccidental(Clefs.G, low.tone, low.octave, low.accidental);
      // Different octave is a different pitch, so it still needs its own natural.
      expect(shouldPaintAccidental(drawC, Clefs.G, pos(BaseTones.F, 4, Accidentals.natural)), isTrue);
    });
  });

  group('accidentalIsIntrinsicallyRequired (coloured feedback overlay)', () {
    test('an in-key F♯ is never intrinsically required (no colour overlay)', () {
      final drawC = gMajorContext();
      expect(accidentalIsIntrinsicallyRequired(drawC, Clefs.G, pos(BaseTones.F, 3, Accidentals.sharp)), isFalse);
    });

    test('an out-of-key G♯ is intrinsically required (colour overlay drawn)', () {
      final drawC = gMajorContext();
      expect(accidentalIsIntrinsicallyRequired(drawC, Clefs.G, pos(BaseTones.G, 3, Accidentals.sharp)), isTrue);
    });

    test('a key-cancelling F♮ is intrinsically required regardless of carry-over', () {
      final drawC = gMajorContext();
      final fNatural = pos(BaseTones.F, 3, Accidentals.natural);
      // Even after the target already registered the natural, the overlay must still draw it coloured.
      drawC.registerMeasureAccidental(Clefs.G, fNatural.tone, fNatural.octave, fNatural.accidental);
      expect(shouldPaintAccidental(drawC, Clefs.G, fNatural), isFalse);
      expect(accidentalIsIntrinsicallyRequired(drawC, Clefs.G, fNatural), isTrue);
    });

    test('a non-cancelling natural (C♮ in G major) is not intrinsically required', () {
      final drawC = gMajorContext();
      expect(accidentalIsIntrinsicallyRequired(drawC, Clefs.G, pos(BaseTones.C, 3, Accidentals.natural)), isFalse);
    });

    test('no accidental is never intrinsically required', () {
      final drawC = gMajorContext();
      expect(accidentalIsIntrinsicallyRequired(drawC, Clefs.G, pos(BaseTones.A, 3, Accidentals.none)), isFalse);
    });
  });
}

