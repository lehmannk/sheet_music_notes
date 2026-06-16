import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheet_music_notes/graphics/render-functions/beam.dart';

double _slope(Offset a, Offset b) => (b.dy - a.dy) / (b.dx - a.dx);

void main() {
  group('parallelBeamSegment', () {
    test('secondary beam is parallel to the primary beam (sloped group)', () {
      // Primary beam spans the whole group: first note low, last note high.
      const primaryStart = Offset(0, 100);
      const primaryEnd = Offset(120, 40);
      final primarySlope = _slope(primaryStart, primaryEnd);

      // Secondary (sixteenth) beam covers only the inner notes, whose own pitch
      // contour differs from the group endpoints. It must still be parallel.
      const levelGap = 8.0;
      final (s, e) = parallelBeamSegment(primaryStart, primaryEnd, 40, 120, -levelGap);

      expect(_slope(s, e), closeTo(primarySlope, 1e-9));
    });

    test('the segment is shifted by exactly the requested vertical offset', () {
      const primaryStart = Offset(0, 100);
      const primaryEnd = Offset(120, 40);
      const shift = -8.0;

      // At an x that lies on the primary line, the shifted segment endpoint must
      // be exactly [shift] away vertically.
      final (s, _) = parallelBeamSegment(primaryStart, primaryEnd, 0, 60, shift);
      expect(s.dy, closeTo(primaryStart.dy + shift, 1e-9));
    });

    test('all levels of a group share one slope (eighth + two sixteenths)', () {
      // Mimic the renderer: primary across all three notes, secondary across the
      // two sixteenths only, with a jumping pitch contour.
      const primaryStart = Offset(0, 90); // eighth (first note)
      const primaryEnd = Offset(160, 30); // last sixteenth (last note)
      const levelGap = 7.5;

      final (p1s, p1e) = parallelBeamSegment(primaryStart, primaryEnd, 0, 160, 0); // primary
      final (p2s, p2e) = parallelBeamSegment(primaryStart, primaryEnd, 80, 160, -levelGap); // secondary

      expect(_slope(p2s, p2e), closeTo(_slope(p1s, p1e), 1e-9));
    });

    test('horizontal primary beam stays horizontal at every level', () {
      const primaryStart = Offset(0, 50);
      const primaryEnd = Offset(100, 50);
      final (s, e) = parallelBeamSegment(primaryStart, primaryEnd, 30, 70, -8);
      expect(s.dy, closeTo(e.dy, 1e-9));
      expect(s.dy, closeTo(42, 1e-9));
    });

    test('degenerate single-x primary beam does not divide by zero', () {
      const p = Offset(10, 20);
      final (s, e) = parallelBeamSegment(p, p, 10, 10, -8);
      expect(s.dy, closeTo(12, 1e-9));
      expect(e.dy, closeTo(12, 1e-9));
    });
  });

  group('beamLevelShift (primary beam stays outermost)', () {
    const levelGap = 8.0;

    test('primary beam (lowest key) has zero shift on both stem directions', () {
      expect(beamLevelShift(1, 1, levelGap, true), 0.0);
      expect(beamLevelShift(1, 1, levelGap, false), 0.0);
    });

    test('stem-up: shorter secondary beams shift towards heads (downwards, +y)', () {
      expect(beamLevelShift(2, 1, levelGap, true), closeTo(levelGap, 1e-9));
      expect(beamLevelShift(3, 1, levelGap, true), closeTo(2 * levelGap, 1e-9));
    });

    test('stem-down: shorter secondary beams shift towards heads (upwards, -y)', () {
      expect(beamLevelShift(2, 1, levelGap, false), closeTo(-levelGap, 1e-9));
      expect(beamLevelShift(3, 1, levelGap, false), closeTo(-2 * levelGap, 1e-9));
    });

    test('the longest (primary) beam is always the outermost of the group', () {
      // Outer = away from heads. For stem-up that is smaller y, so the primary
      // (shift 0) must be above every secondary (positive shift).
      final primary = beamLevelShift(1, 1, levelGap, true);
      final secondary = beamLevelShift(2, 1, levelGap, true);
      expect(primary, lessThan(secondary));

      // For stem-down outer = larger y, primary (shift 0) must be below.
      final primaryDown = beamLevelShift(1, 1, levelGap, false);
      final secondaryDown = beamLevelShift(2, 1, levelGap, false);
      expect(primaryDown, greaterThan(secondaryDown));
    });
  });
}
