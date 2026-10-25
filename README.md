# talkhimik_app

Talkhimik companion app — FSL smart glove (Team Sagbotics, CIT-U).
Flutter, Android-tested (NFR-10).

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart `^3.13.2`) and an Android toolchain.

```
git clone https://github.com/DaRealDB/Talkhimik-FSL-gloves.git
cd Talkhimik-FSL-gloves
flutter pub get
flutter run        # device or emulator; BLE needs a physical phone
```

To get the installable app instead of running from source:

```
flutter build apk --release
```

The APK lands at
`build/app/outputs/flutter-apk/app-release.apk` — copy it to a phone and
install (allow "install unknown apps"), or `flutter install` with the
device connected.

## Structure

- `lib/domain` — models, sensor math, vocabulary table, repository interfaces
- `lib/data` — Hive log store, shared-prefs settings, BLE glove connection
  (real `FlutterBlueGloveConnection` + `MockGloveConnection`), codecs,
  dataset writer
- `lib/application` — Riverpod controllers (transcript, glove, live,
  calibration wizard, dataset recorder, settings, export)
- `lib/ui` — screens and widgets (home, live, calibration, collect, export)

## Tests

```
flutter analyze
flutter test
```

The mock glove and in-memory fakes cover everything off-device; hardware
verification is staged in
[`docs/TALKHIMIK.md`](docs/TALKHIMIK.md) §8 (nRF Connect first, then this
client).

## Documentation

- [`docs/TALKHIMIK.md`](docs/TALKHIMIK.md) — the single doc: byte-exact
  glove contract, architecture, live screen, calibration wizard, dataset
  recorder, testing, definition of done, and thesis pointers.
