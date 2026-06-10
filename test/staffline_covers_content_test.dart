import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_music_notes/graphics/music-line.dart';
import 'package:sheet_music_notes/musicXML/data.dart';
import 'package:sheet_music_notes/musicXML/parser.dart';

PitchNote q(BaseTones tone, int octave, [int? alter]) => PitchNote(
    1, 1, 1, [], Pitch(tone, octave, alter), NoteLength.quarter, StemValue.up, []);

Score single(List<PitchNote> notes) => Score([
      Part([
        Measure([
          Attributes(1, MusicalKey(CircleOfFifths.G_E.v, KeyMode.major), 1,
              [Clef(1, Clefs.G)], Time(4, 4)),
          ...notes,
        ])
      ])
    ]);

Future<int> rightmostInk(ui.Image image) async {
  final p = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final w = image.width, h = image.height;
  for (var x = w - 1; x >= 0; x--) {
    for (var y = 0; y < h; y++) {
      if (p.getUint8((y * w + x) * 4 + 3) > 16) return x;
    }
  }
  return 0;
}

Future<ui.Image> renderPainter(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  painter.paint(ui.Canvas(recorder), size);
  return recorder.endRecording().toImage(size.width.ceil(), size.height.ceil());
}

/// Verify that the BackgroundPainter's staff lines end at the final barline
/// (within a 2 px anti-aliasing tolerance) and do not extend unnecessarily
/// past it.
Future<void> verify(WidgetTester tester, String name, Score score) async {
  const size = Size(1100, 360);
  const sh = 36.0;
  final opts = MusicLineOptions(score, sh, 1);
  final spacing = sh * 2;

  // The expected end position is the barline right edge.
  final barlineEndX = calculateMusicLineContentWidth(opts, spacing);

  await tester.runAsync(() async {
    final bg = await renderPainter(BackgroundPainter(opts, spacing), size);
    final bgRight = await rightmostInk(bg);

    // Staff lines must reach the barline (≥ barlineEndX - 2 for AA).
    expect(bgRight, greaterThanOrEqualTo(barlineEndX - 2),
        reason: '$name: staff lines (right=$bgRight) fall short of barline '
            '(barlineEndX=${barlineEndX.toStringAsFixed(1)})');

    // Staff lines must not extend more than 2 px past the barline (AA only).
    expect(bgRight, lessThanOrEqualTo(barlineEndX + 2),
        reason: '$name: staff lines (right=$bgRight) extend past barline '
            '(barlineEndX=${barlineEndX.toStringAsFixed(1)})');
  });
}

void main() {
  testWidgets('staff lines cover content (lS buffer)', (tester) async {
    await verify(tester, 'ONE#      ',
        single([q(BaseTones.C, 2, 1), q(BaseTones.D, 2), q(BaseTones.E, 2), q(BaseTones.G, 2)]));
    await verify(tester, 'SHARP+NAT ',
        single([q(BaseTones.C, 2, 1), q(BaseTones.F, 2, 0), q(BaseTones.E, 2), q(BaseTones.F, 2, 0)]));
    await verify(tester, 'MULTI     ',
        single([q(BaseTones.C, 2, 1), q(BaseTones.F, 2, 0), q(BaseTones.C, 2, 1), q(BaseTones.F, 2, 0)]));

    final hanon = parseMusicXML(
        loadMusicXMLFile('./example/hanon-no1-stripped.musicxml'));
    final notes =
        hanon.parts.first.measures.last.contents.whereType<PitchNote>().toList();
    for (var i = 0; i < notes.length; i++) {
      notes[i].pitch =
          Pitch(notes[i].pitch.step, notes[i].pitch.octave, i % 2 == 0 ? 1 : 0);
    }
    await verify(tester, 'HANON+ACC ', hanon);
  });
}

