# Talkhimik — BLE Integration Checklist (Glove ↔ App)

Staged verification for the ESP32-S3 glove ↔ Flutter app link. Work through
the stages in order; each box is a gate for the next. Companion guide:
`Talkhimik_BLE_Integration_Steps.md` (firmware setup, GATT design, staging
rationale). SRS codes: C-F4/C-F5/C-F7, C-S1, C-S5, NFR-9, Table III-1/III-2.

## Stage A — Firmware validation with nRF Connect (no app code involved)

> Isolates firmware bugs from app bugs (Steps doc, stage 1–2).
> The app now implements the firmware contract (Code Reference §5), so these
> checks validate the contract the app speaks.

- [ ] A.1 Glove advertises: nRF Connect shows device name **TALKHIMIK-L/R**
      and service `d84f9c2e-6b1a-4e57-9f3d-2a8c7e5b1f04`.
- [ ] A.2 Connect from nRF Connect; discover the **four characteristics**
      (Telemetry `7a3e…` READ+NOTIFY, Command `3f8d…` WRITE+WRITE-NO-RESPONSE,
      Device Status `c2b6…` READ+NOTIFY, CAL_INFO `a1f2…` READ+NOTIFY) —
      Code Reference §5.1.
- [ ] A.3 Subscribe to Telemetry; a bend produces **29-byte frames** at
      ~50 ms (u8 hand · u16 seq · u8 angles[5] · i16 roll/pitch/yaw ×10 ·
      u16 raw ADC[5] · u32 calibration_id · u8 quality, LE) — §5.2,
      `telemetry_packet_codec.dart`.
- [ ] A.4 Subscribe/read Device Status; payload is **5 bytes** (mode,
      calibration step, battery %, flags, error) matching
      `device_status_codec.dart` — §5.3.
- [ ] A.5 Write command bytes to Command; firmware reacts to
      START_CALIBRATION, CAPTURE_FLAT/90, CANCEL, SET_RATE, ZERO_YAW,
      SET_HAND, VIBRATE (opcodes 0x01–0x08) — §5.4, `AppCommand`.
- [ ] A.6 Read CAL_INFO: **104-byte** table with valid/weak masks,
      calibration_id, per-finger baselines, R_DIV, firmware version —
      §5.5, `cal_info_codec.dart`.
- [ ] A.7 Power-cycle the glove: after reconnect it resumes with **no stored
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
- [ ] C.3 Battery % and mode appear from the Device Status characteristic;
      an uncalibrated glove shows the **Uncalibrated** chip.
- [ ] C.4 Telemetry frames flow into `GloveState` (angles/IMU/raw ADC) and
      CAL_INFO shows the firmware version. Note: the glove does not emit
      word labels yet, so the transcript stays mock-driven until the label
      packet (open item below) — C.4's gesture→bubble check is blocked on it.
- [ ] C.5 Low-confidence gesture shows an amber/red badge (FR-4) — mock
      path until the label packet exists.
- [ ] C.6 Calibration and Record mode send `startCalibration` /
      `cancelCalibration` / `setRate(50)` command bytes; the glove's mode
      flips accordingly.
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

## Open items to close with the firmware team

- [ ] Production label packet: the 7-byte gesture result contract
      (`gesture_packet_codec.dart`, SRS Table III-2) vs. the raw telemetry
      stream — until the firmware sends labels (or the app classifies),
      the transcript works only with the mock glove.
- [ ] Calibration packet contract (FR-8): driving the firmware wizard steps
      (STATUS.calibrationStep → CAPTURE_FLAT/CAPTURE_90) from the app's
      calibration flow — see `calibration_controller.dart`.
- [ ] Raw sensor stream contract for FR-9 (labeled streams vs. labeled
      result packets — see `data_collection_controller.dart`).
