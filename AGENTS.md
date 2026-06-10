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

