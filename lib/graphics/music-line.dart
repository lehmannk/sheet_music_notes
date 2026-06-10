import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../ExtendedCanvas.dart';
import '../musicXML/data.dart';
import 'generated/engraving-defaults.dart';
import 'generated/glyph-advance-widths.dart';
import 'generated/glyph-definitions.dart';
import 'render-functions/DrawingContext.dart';
import 'render-functions/common.dart';
import 'render-functions/glyph.dart';
import 'render-functions/measure.dart';
import 'render-functions/staff.dart';

class MusicLineOptions {
  MusicLineOptions(this.score, this.staffHeight, double topMarginFactor,
      {this.staffSpacingFactor = 2})
      : topMargin = staffHeight * topMarginFactor;

  final Score score;
  final double staffHeight;
  final double topMargin;
  final double staffSpacingFactor;

  @override
  bool operator ==(Object other) {
    return other is MusicLineOptions &&
        identical(other.score, score) &&
        other.topMargin == topMargin &&
        other.staffHeight == staffHeight;
  }

  @override
  int get hashCode => staffHeight.hashCode ^ topMargin.hashCode ^ identityHashCode(score);
}

class MusicLine extends StatefulWidget {
  const MusicLine({super.key, required this.options});

  final MusicLineOptions options;

  @override
  _MusicLineState createState() => _MusicLineState();
}

class _MusicLineState extends State<MusicLine> {
  double staffsSpacing = 0;

  @override
  void initState() {
    super.initState();
    staffsSpacing =
        widget.options.staffHeight * widget.options.staffSpacingFactor;
  }

  @override
  void didUpdateWidget(MusicLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      staffsSpacing =
          widget.options.staffHeight * widget.options.staffSpacingFactor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final newWidth = constraints.widthConstraints().maxWidth;
      final newHeight = constraints.heightConstraints().maxHeight;
      final size = Size(newWidth, newHeight);

      return Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            child: CustomPaint(
              size: size,
              painter: BackgroundPainter(widget.options, staffsSpacing),
            ),
          ),
          Positioned(
            child: CustomPaint(
              size: size,
              painter: ForegroundPainter(widget.options, staffsSpacing),
            ),
          ),
        ],
      );
    });
  }
}

class BackgroundPainter extends CustomPainter {
  BackgroundPainter(this.options, this.staffsSpacing)
      : lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);
    xCanvas.save();

    /// Clipping and offsetting staff, so that the top line is seen completely
    xCanvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height),
        doAntiAlias: false);

    xCanvas.translate(0, options.topMargin);

    final drawC = DrawingContext(options.score, options.staffHeight,
        options.topMargin, xCanvas, size, staffsSpacing);

    /// Determine where the music content ends, so that the staff lines stop
    /// there instead of extending to the window width.
    final contentEndX = calculateMusicLineContentWidth(options, staffsSpacing);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      paintGlyph(
          drawC.copyWith(staffHeight: options.staffHeight * 2 + staffsSpacing),
          Glyph.brace,
          yOffset: (options.staffHeight * 2 + staffsSpacing) / 2);
      xCanvas.translate(lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation, 0);
    }

    paintBarLine(drawC, Barline(BarLineTypes.regular), true);

    paintStaffLines(drawC, true, endX: contentEndX);

    if ((drawC.latestAttributes.staves ?? 1) > 1) {
      xCanvas.translate(0, options.staffHeight + staffsSpacing);
      paintStaffLines(drawC, false, endX: contentEndX);
      xCanvas.translate(0, -options.staffHeight - staffsSpacing);
    }

    xCanvas.restore();
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) {
    return options != oldDelegate.options ||
        staffsSpacing != oldDelegate.staffsSpacing;
  }
}

class ForegroundPainter extends CustomPainter {
  ForegroundPainter(this.options, this.staffsSpacing)
      : lineSpacing = getLineSpacing(options.staffHeight);

  final MusicLineOptions options;
  final double staffsSpacing;
  final double lineSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    final xCanvas = XCanvas(canvas);
    xCanvas.translate(0, options.topMargin);

    final drawC = DrawingContext(options.score, options.staffHeight,
        options.topMargin, xCanvas, size, staffsSpacing);

    paintMusicLineContent(drawC, lineSpacing);
  }

  @override
  bool shouldRepaint(ForegroundPainter oldDelegate) {
    return options != oldDelegate.options ||
        staffsSpacing != oldDelegate.staffsSpacing;
  }
}

/// Lays out and paints the brace, all measures and their barlines onto the
/// canvas of [drawC]. Returns the x-coordinate where the content ends, i.e. the
/// right edge of the last barline (in the painter's root coordinate space).
double paintMusicLineContent(DrawingContext drawC, double lineSpacing) {
  if ((drawC.latestAttributes.staves ?? 1) > 1) {
    // The brace in front of the whole music line takes up horizontal space. That
    // space is determined by the width of the brace, which in turn is determined by
    // heights of the staffs and the space between the staff.
    final staffsSpacingLineSpacing = getLineSpacing(drawC.staffsSpacing);
    drawC.canvas.translate(
        GLYPH_ADVANCE_WIDTHS[Glyph.brace]! *
                (lineSpacing * 2 + staffsSpacingLineSpacing) +
            lineSpacing * ENGRAVING_DEFAULTS.barlineSeparation * 2,
        0);
  }
  final measures = drawC.score.parts.first.measures.toList();
  double lastBarlineRightEdge = drawC.canvas.getTranslation().dx;
  measures.forEachIndexed((index, measure) {
    drawC.currentMeasure = index;
    if (index > 0) {
      drawC.canvas.translate(drawC.lS * 1, 0);
    }
    paintMeasure(measure, drawC);

    drawC.canvas.translate(drawC.lS * 1, 0);

    lastBarlineRightEdge = paintBarLine(drawC, measure.barline, false);
  });

  return lastBarlineRightEdge;
}

/// Runs the same layout as [paintMusicLineContent] against a throwaway canvas
/// in order to measure the width of the rendered music, i.e. the x-coordinate
/// of the right edge of the last barline. This is used to limit the staff lines
/// so they stop at the last barline instead of extending to the window width.
double calculateMusicLineContentWidth(
    MusicLineOptions options, double staffsSpacing) {
  final recorder = ui.PictureRecorder();
  final measuringCanvas = XCanvas(ui.Canvas(recorder));
  measuringCanvas.translate(0, options.topMargin);

  final drawC = DrawingContext(options.score, options.staffHeight,
      options.topMargin, measuringCanvas, Size.zero, staffsSpacing);
  final lineSpacing = getLineSpacing(options.staffHeight);

  final barlineEndX = paintMusicLineContent(drawC, lineSpacing);

  // Discard the recorded drawing operations; we only needed the measurement.
  recorder.endRecording().dispose();

  return barlineEndX;
}
