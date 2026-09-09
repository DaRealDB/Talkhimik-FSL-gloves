# talkhimik_app

Talkhimik companion app — FSL smart glove (Team Sagbotics, CIT-U).
Flutter, Android-tested (NFR-10).

## Structure

- `lib/domain` — models, vocabulary table, repository interfaces
- `lib/data` — Hive log store, shared-prefs settings, BLE glove connection
  (real `FlutterBlueGloveConnection` + `MockGloveConnection`), codecs
- `lib/application` — Riverpod controllers (transcript, glove, settings,
  export, calibration, data collection)
- `lib/ui` — screens and widgets

## Tests

```
flutter analyze
flutter test
```

The mock glove and in-memory fakes cover everything off-device; hardware
verification is staged in
[`docs/ble-integration-checklist.md`](docs/ble-integration-checklist.md)
(nRF Connect first, then this client).
