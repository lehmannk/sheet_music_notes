import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_music_notes/graphics/music-line.dart';
import 'package:sheet_music_notes/musicXML/data.dart';

/// A single-measure score in C major (no key accidentals) whose only note is
/// [note], carrying a background highlight so the band is rendered.
Score highlighted(PitchNote note) => Score([
      Part([
        Measure([
          Attributes(1, MusicalKey(CircleOfFifths.C_A.v, KeyMode.major), 1,
              [Clef(1, Clefs.G)], Time(4, 4)),
          note,
        ])
      ])
    ]);

PitchNote note(BaseTones tone, int octave, StemValue stem, [int? alter]) =>
    PitchNote(1, 1, 1, [], Pitch(tone, octave, alter), NoteLength.quarter, stem, [],
        highlight: const NoteHighlight(NoteHighlightStyle.background, Colors.blue));

/// A single-measure score in C major whose only element is a highlighted quarter rest.
Score highlightedRest() => Score([
      Part([
        Measure([
          Attributes(1, MusicalKey(CircleOfFifths.C_A.v, KeyMode.major), 1,
              [Clef(1, Clefs.G)], Time(4, 4)),
          RestNote(1, 1, 1, [],
              highlight:
                  const NoteHighlight(NoteHighlightStyle.background, Colors.blue)),
        ])
      ])
    ]);

/// Renders [painter] over an opaque white background so semi-transparent band
/// pixels composite to a detectable light blue.
Future<ui.Image> render(CustomPainter painter, Size size) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
  painter.paint(canvas, size);
  return recorder.endRecording().toImage(size.width.ceil(), size.height.ceil());
}

class _Box {
  int left = 1 << 30, top = 1 << 30, right = -1, bottom = -1;
  bool get isEmpty => right < 0;
  void add(int x, int y) {
    if (x < left) left = x;
    if (x > right) right = x;
    if (y < top) top = y;
    if (y > bottom) bottom = y;
  }

  @override
  String toString() => 'LTRB($left,$top,$right,$bottom)';
}

/// Renders the highlighted note, then returns the bounding box of the blue band
/// ink and of the black note ink that falls within the band's horizontal span
/// (which excludes the clef/time signature at the far left of the measure).
Future<(_Box band, _Box note)> boxes(Score score) async {
  const size = Size(500, 640);
  const sh = 40.0;
  final opts = MusicLineOptions(score, sh, 4); // topMargin = 160px of head-room
  final img = await render(ForegroundPainter(opts, sh * 2), size);
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final w = img.width, h = img.height;

  int r(int x, int y) => data.getUint8((y * w + x) * 4);
  int g(int x, int y) => data.getUint8((y * w + x) * 4 + 1);
  int b(int x, int y) => data.getUint8((y * w + x) * 4 + 2);

  bool isBluish(int x, int y) =>
      b(x, y) > r(x, y) + 12 && b(x, y) > g(x, y) + 12;
  bool isDark(int x, int y) => r(x, y) < 100 && g(x, y) < 100 && b(x, y) < 100;

  final band = _Box();
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (isBluish(x, y)) band.add(x, y);
    }
  }
  expect(band.isEmpty, isFalse, reason: 'no highlight band was rendered');

  final note = _Box();
  for (var y = 0; y < h; y++) {
    for (var x = band.left; x <= band.right; x++) {
      if (isDark(x, y)) note.add(x, y);
    }
  }
  expect(note.isEmpty, isFalse, reason: 'no note ink found inside the band column');
  return (band, note);
}

void main() {
  const tol = 2; // anti-aliasing slack

  Future<void> expectEnclosed(String name, Score score) async {
    final (band, note) = await boxes(score);
    expect(note.top, greaterThanOrEqualTo(band.top - tol),
        reason: '$name: note top ${note.top} pokes above band ${band.top}');
    expect(note.bottom, lessThanOrEqualTo(band.bottom + tol),
        reason: '$name: note bottom ${note.bottom} pokes below band ${band.bottom}');
    expect(note.left, greaterThanOrEqualTo(band.left - tol),
        reason: '$name: note left ${note.left} pokes left of band ${band.left}');
    expect(note.right, lessThanOrEqualTo(band.right + tol),
        reason: '$name: note right ${note.right} pokes right of band ${band.right}');
  }

  testWidgets('background band encloses the whole note (head, stem, accidental)',
      (tester) async {
    await tester.runAsync(() async {
      // Violin low G on the G string (G3): head sits far below the staff on ledger lines.
      await expectEnclosed('low G3', highlighted(note(BaseTones.G, 1, StemValue.up)));
      // Low G with a sharp: the accidental must be enclosed too.
      await expectEnclosed(
          'low G#3', highlighted(note(BaseTones.G, 1, StemValue.up, 1)));
      // A high note above the staff, stem pointing down into the staff.
      await expectEnclosed('high E6', highlighted(note(BaseTones.E, 4, StemValue.down)));
      // A note inside the staff still stays enclosed (default frame, stem up).
      await expectEnclosed('mid B4', highlighted(note(BaseTones.B, 2, StemValue.up)));
    });
  });

  testWidgets('background band wraps a rest horizontally symmetrically',
      (tester) async {
    await tester.runAsync(() async {
      final (band, rest) = await boxes(highlightedRest());
      // The rest glyph must sit inside the band...
      expect(rest.left, greaterThanOrEqualTo(band.left - tol),
          reason: 'rest left ${rest.left} pokes left of band ${band.left}');
      expect(rest.right, lessThanOrEqualTo(band.right + tol),
          reason: 'rest right ${rest.right} pokes right of band ${band.right}');
      // ...and the left/right breathing space must be (near) equal, i.e. centred.
      final leftGap = rest.left - band.left;
      final rightGap = band.right - rest.right;
      expect((leftGap - rightGap).abs(), lessThanOrEqualTo(tol + 1),
          reason: 'asymmetric band: left gap $leftGap vs right gap $rightGap');
    });
  });
}
