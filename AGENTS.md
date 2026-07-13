# AGENTS.md

Project-specific instructions for AI agents working in this repository.

## Tooling: FVM is required

This project uses [FVM (Flutter Version Management)](https://fvm.app/). You **must**
prefix every Flutter and Dart command with `fvm`.

Do:

```sh
fvm flutter pub get
fvm flutter test
fvm flutter run
fvm flutter clean
fvm dart format .
fvm dart analyze
```

Don't:

```sh
flutter pub get   # ❌ wrong – bypasses the pinned SDK
dart analyze      # ❌ wrong
```

This applies to all subdirectories too (e.g. `example/`).

## Quick commands

- Run library tests: `fvm flutter test`
- Run a single test file: `fvm flutter test test/<file>.dart`
- Run the example app: `cd example && fvm flutter clean && fvm flutter pub get && fvm flutter run`


## Rendering architecture (pointers)

- Two painters per `MusicLine`: a background painter draws the staff lines, a foreground
  painter draws all content (clef, key/time, notes, rests, beams, bar lines, highlights).
- `DrawingContext` carries the mutable render state across a line: current attributes,
  within-measure accidental carry-over (`getMeasureAccidental` / `registerMeasureAccidental`,
  reset at every bar line) and the beam pipeline state (`BeamRenderState` in
  `lib/graphics/render-functions/beam.dart`).
- Beamed groups render in two passes (see `lib/graphics/render-functions/note.dart`):
  the base pass collects `BeamPoint`s per `Beam.id` and, once the group is complete, paints
  beams + stems and stashes their geometry; the chord-overlay pass
  (`paintBeamedChordOverlay`) then recolours per-note stems — and the connecting beam(s)
  when all overlays share one non-black colour.
- Accidental rendering rules live in `shouldPaintAccidental` (standard notation incl.
  carry-over) and `accidentalIsIntrinsicallyRequired` (coloured chord-overlay repaint).

## Key test suites

- `test/note_highlight_band_test.dart` — highlight band encloses the whole note ink
  (pixel-colour inspection).
- `test/colored_accidental_overlay_test.dart` — accidental suppression/repaint rules.
- `test/beam_parallel_test.dart` — secondary beams stay parallel to the primary beam.
- `test/staffline_covers_content_test.dart` — staff lines end at the final bar line when
  `lineWidth` is set.
