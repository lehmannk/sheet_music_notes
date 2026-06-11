import 'package:flutter/material.dart';
import '../graphics-model/measure.dart';
import 'common.dart';
import 'beam.dart';
import '../music-line.dart';
import '../../ExtendedCanvas.dart';
import '../../musicXML/data.dart';
import '../notes.dart';

class DrawingContext extends MusicLineOptions {
  DrawingContext(
    super.score,
    super.staffHeight,
    super.topMargin,
    this.canvas,
    this.size,
    this.staffsSpacing, {
    this.spacingFactor = 1.0,
  })   : _currentAttributes = score.parts.first.measures.first.attributes!,
        measuresPerPart = List.filled(
            score.parts.length, List.empty(growable: true),
            growable: false);

  final XCanvas canvas;
  final Size size;
  final double staffsSpacing;

  /// Multiplier applied to the stretchable horizontal gaps (between note columns
  /// and between measures) to justify a line to a forced width. 1.0 keeps the
  /// natural spacing.
  final double spacingFactor;
  get lS => getLineSpacing(staffHeight);
  int currentPart = 0;
  int _currentMeasure = 0;
  int get currentMeasure => _currentMeasure;
  set currentMeasure(int newMeasure) {
    _currentMeasure = newMeasure;
    // Reset within-measure accidental carry-over state at every bar line.
    _measureAccidentals.clear();
    final newMeasureAttributes =
        score.parts[currentPart].measures.elementAt(newMeasure).attributes;
    if (newMeasureAttributes != null) {
      _currentAttributes =
          _currentAttributes.copyWithObject(newMeasureAttributes);
    }
  }

  Attributes _currentAttributes;
  Attributes get latestAttributes => _currentAttributes;
  Map<int, Map<int, List<BeamPoint>>> currentBeamPointsPerID = {};
  final List<List<MeasureGeometry>> measuresPerPart;

  void debugDrawBB(Rect boundingBox) {
    canvas.executeGlobally(() {
      canvas.drawRect(boundingBox, debugPaint(Colors.red));
    });
  }

  DrawingContext copyWith(
      {Score? score,
      double? staffHeight,
      double? topMargin,
      XCanvas? canvas,
      Size? size,
      double? staffsSpacing,
      double? spacingFactor}) {
    return DrawingContext(
      score ?? this.score,
      staffHeight ?? this.staffHeight,
      topMargin ?? this.topMargin,
      canvas ?? this.canvas,
      size ?? this.size,
      staffsSpacing ?? this.staffsSpacing,
      spacingFactor: spacingFactor ?? this.spacingFactor,
    );
  }

  /// Tracks accidentals explicitly written within the current measure.
  /// Key: encoded as `(staff.index << 24) | (tone.index << 16) | octave`
  /// Value: the [Accidentals] that was last written for this pitch in this bar.
  final Map<int, Accidentals> _measureAccidentals = {};

  static int _accidentalKey(Clefs staff, BaseTones tone, int octave) =>
      (staff.index << 24) | (tone.index << 16) | octave;

  /// Returns the accidental explicitly set for [tone]/[octave] in the current
  /// measure on [staff], or `null` if none has been written yet this bar.
  Accidentals? getMeasureAccidental(Clefs staff, BaseTones tone, int octave) =>
      _measureAccidentals[_accidentalKey(staff, tone, octave)];

  /// Records that an accidental sign was rendered for [tone]/[octave] on
  /// [staff] in the current measure so subsequent notes can suppress theirs.
  void registerMeasureAccidental(
      Clefs staff, BaseTones tone, int octave, Accidentals accidental) {
    _measureAccidentals[_accidentalKey(staff, tone, octave)] = accidental;
  }
}
