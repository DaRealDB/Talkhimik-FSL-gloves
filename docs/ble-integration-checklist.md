# Talkhimik — BLE Integration Checklist (Glove ↔ App)

Staged verification for the ESP32-S3 glove ↔ Flutter app link. Work through
the stages in order; each box is a gate for the next. Companion guide:
`Talkhimik_BLE_Integration_Steps.md` (firmware setup, GATT design, staging
rationale). SRS codes: C-F4/C-F5/C-F7, C-S1, C-S5, NFR-9, Table III-1/III-2.

## Stage A — Firmware validation with nRF Connect (no app code involved)

> Isolates firmware bugs from app bugs (Steps doc, stage 1–2).

- [ ] A.1 Glove advertises: nRF Connect shows device name **Talkhimik-Glove**
      and service `4fafc201-1fb5-459e-8fcc-c5c9c331914b`.
- [ ] A.2 Connect from nRF Connect; discover the **three characteristics**
      (Gesture Result `…9d42` NOTIFY, Device Status `…9d43` READ+NOTIFY,
      App Command `…9d44` WRITE) — SRS Table III-1.
- [ ] A.3 Subscribe to Gesture Result; a test gesture produces a **7-byte
      packet** (word_id u16 + confidence u8 + timestamp_ms u32, LE) — Table III-2.
- [ ] A.4 Subscribe/read Device Status; payload is **3 bytes** (battery, mode,
      error) matching `device_status_codec.dart` — confirm or update the
      codec with the firmware team (SRS open item 2).
- [ ] A.5 Write command bytes to App Command; firmware reacts to
      start/stop-stream, calibrate, sleep, query-status (C-F5).
- [ ] A.6 Power-cycle the glove: after reconnect it resumes with **no stored
      state** (C-F7).

## Stage B — App static checks (no device needed)

- [ ] B.1 `AndroidManifest.xml` declares BLUETOOTH_SCAN (neverForLocation),
      BLUETOOTH_CONNECT, legacy BLUETOOTH/BLUETOOTH_ADMIN/FINE_LOCATION
      (≤ SDK 30), and the `bluetooth_le` feature.
- [ ] B.2 Settings → **Force mock** is off, so the factory builds
      `FlutterBlueGloveConnection` on Android.
- [ ] B.3 `flutter analyze` clean and `flutter test` green (mock glove and
      fakes still cover everything off-device).
- [ ] B.4 App builds and installs: `flutter build apk --debug`.

## Stage C — App end-to-end on Android (glove powered, in range)

- [ ] C.1 On first Connect tap the **permission dialog** appears
      (nearby devices); denying it shows the C-S1 snackbar and does not
      crash.
- [ ] C.2 Status bar shows **Scanning… → Connecting… → Discovering
      services… → Connected** and the glove name "Talkhimik Glove".
- [ ] C.3 Battery % and mode appear from the Device Status characteristic.
- [ ] C.4 A test gesture on the glove → transcript bubble (FR-1) + TTS
      (FR-2) + a log row (FR-10) within the **≤ 500 ms** NFR-1 target
      (stopwatch it).
- [ ] C.5 Low-confidence gesture shows an amber/red badge (FR-4).
- [ ] C.6 Calibration and Record mode send `calibrate`/`startStream`/
      `stopStream` command bytes; the glove's mode flips accordingly.
- [ ] C.7 Power off the glove mid-session: the **"connection lost" banner**
      appears within 3 s (C-S5, NFR-9) and auto-reconnect retries with
      backoff 1→2→4→8→30 s.
- [ ] C.8 Power the glove back on: the link restores without app restart
      (C-F7).
- [ ] C.9 Session logs → export CSV: rows contain glove source, latency,
      confidence (FR-16).
- [ ] C.10 Walk out of range and back; repeat C.7–C.8 twice — no duplicate
      transcript entries, no lost rows, no crash.

## Stage D — Regression (mock path still intact)

- [ ] D.1 Settings → **Force mock** on → restart app: auto-connect + demo
      scenarios still work end-to-end.
- [ ] D.2 Full test suite green after any Stage C fix.

## Open items to close with the firmware team (SRS open item 2)

- [ ] Final UUID values for service + three characteristics.
- [ ] Device Status byte layout confirmed against `device_status_codec.dart`.
- [ ] Calibration packet contract (FR-8 shell note in
      `calibration_controller.dart`).
- [ ] Raw sensor stream contract for FR-9 (labeled streams vs. labeled
      result packets — see `data_collection_controller.dart`).
