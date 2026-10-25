<!--
  TALKHIMIK — Companion App System Documentation (as built)
  Covers the Flutter app in this repository (talkhimik_app).
  Companion documents:
    - TALKHIMIK_Thesis_Reference.md — consolidated thesis reference
      (system architecture + firmware/web-dashboard code reference)
    - ble-integration-checklist.md — staged glove ↔ app verification
  Where documents disagree about the BLE contract, the checklist's open
  items (SRS open item 2) are the authority until firmware freeze.
-->

# TALKHIMIK — Companion App System Documentation (as built)

| | |
|---|---|
| **App** | `talkhimik_app` — Flutter companion app for the Talkhimik FSL smart glove |
| **Team** | Daryl D. Bacusmo · Dewey Raven S. Cabahug · Sheena Patricia Kaye Caneja · Joppy B. Vargas (Team Sagbotics) |
| **Adviser** | Engr. Nikko D. Alferez |
| **Institution** | Cebu Institute of Technology University — College of Engineering and Architecture |
| **Repo** | `Talkhimik-FSL-gloves` |
| **Version** | 0.1.0+1 · Dart SDK `^3.13.2` |

---

## 1. Role in the Talkhimik System

Talkhimik is a wearable FSL smart glove that translates silent hand gestures
into spoken Filipino/English words. The full system has three layers
(see `TALKHIMIK_Thesis_Reference.md`):

1. **Hardware** — 2 × Seeed XIAO ESP32-S3 gloves, 5 flex sensors + MPU-6050 each
2. **Firmware** — on-glove acquisition, calibration, NimBLE GATT server
   (and, planned, on-glove TensorFlow Lite Micro inference)
3. **Software** — this app

This app is the **software layer**: the BLE GATT client that receives
recognized-gesture packets from the glove, shows them as Filipino text with a
confidence badge, speaks them through TTS, and logs every event for session
export. It also hosts the researcher tooling — calibration profiles, labeled
data collection (Record mode), and CSV export — that feeds the thesis ML
pipeline.

The **development link** (current stage) is the Web Bluetooth dashboard in
`talkhimik-ble/web/index.html`, documented in the thesis reference. This app
is the **production link** (glove → phone).

---

## 2. Tech Stack & Platforms

| Concern | Choice |
|---|---|
| Framework | Flutter (Material 3, dark-first theme) |
| State management | Riverpod 3 (Notifier providers, composition root in `lib/application/providers.dart`) |
| BLE | `flutter_blue_plus` 2.3.12 (Android/iOS only — no Windows/web implementation) |
| TTS | `flutter_tts` 4.2.5 (OS-native engine) |
| Persistence | `hive_ce` 2.19.3 (boxes) + `shared_preferences` 2.5.5 (settings) |
| Permissions | `permission_handler` 12.x (pinned — 13.x exceeds AGP 9.1's max compileSdk) |

| Platform | Role |
|---|---|
| **Android** | Primary target — real BLE glove, TTS, field data collection |
| **Windows** | Dev machine — full UI with the mock glove; no BLE |
| **Web (Chrome/Edge)** | Debug convenience — mock glove; Hive in IndexedDB; no TTS/export (degrades gracefully) |

The connection factory guarantees the BLE client is only constructed on
Android/iOS; everywhere else the app boots with the **mock glove**, which is
also what development, demos, and tests want.

Android toolchain (validated 2026-10): SDK 36 at `D:\Android` + Temurin
JDK 17 at `D:\Android\jdk17`, wired via `flutter config --android-sdk` /
`--jdk-dir`; `flutter build apk` is green and the app has been installed on
a field phone (realme, Android 15).

---

## 3. Repository Layout

```
lib/
├── main.dart                      # bootstrap: Hive init → settings → factory → runApp
├── app.dart                       # MaterialApp, routes, theme
├── core/
│   ├── constants/                 # GATT IDs, reconnect policy, confidence, version
│   ├── strings/                   # centralized user-facing copy (NFR-7 terminology audit)
│   ├── theme/
│   └── utils/csv_exporter.dart    # RFC-4180 CSV (FR-16)
├── domain/
│   ├── models/                    # GestureLogEntry, ParticipantProfile, TranscriptEntry, …
│   ├── repositories/              # interfaces: LogStore, VocabularyRepository, CloudSync
│   └── vocab/                     # FSL vocabulary table (word_id → Filipino/English)
├── data/
│   ├── codec/                     # strict LE decoders: telemetry, device status, CAL_INFO (+ planned label packet)
│   ├── glove/                     # GloveConnection interface + FlutterBlue impl + mock + factory + permissions
│   ├── storage/                   # HiveLogStore, calibration store, settings service
│   ├── tts/                       # FlutterTtsService (degrades, never throws)
│   └── vocab/
├── application/
│   ├── providers.dart             # composition root — every provider in one file
│   ├── glove_controller.dart      # connection phases + auto-reconnect state machine
│   ├── transcript_controller.dart # recognized gestures → bubbles, corrections, TTS, logging
│   ├── tts_controller.dart        # FR-2/FR-15 voice, rate, language, mute
│   ├── settings_controller.dart   # FR-13/FR-15 participant, consent, accessibility
│   ├── calibration_controller.dart# FR-8 per-user calibration profiles
│   ├── data_collection_controller.dart # FR-9 labeled training-data capture
│   └── export_controller.dart     # FR-16 session summaries + CSV export
└── ui/
    ├── screens/                   # home, settings, export, calibration, collect
    └── widgets/                   # transcript bubbles, confidence badge, status bar, demo controls, …
```

Layer rule (from `providers.dart`): **ui → application → domain ← data**.
Domain holds models and repository interfaces; data implements them; UI
touches only controllers.

### Bootstrap (`main.dart`)

```
WidgetsFlutterBinding.ensureInitialized()
  → Hive.init(app support dir | '' on web → IndexedDB)
  → HiveLogStore.init()                    # opens 4 boxes
  → SharedPrefsSettingsService.forceMock()
  → GloveConnectionFactory.create(forceMock)   # BLE on Android/iOS, mock elsewhere
  → ProviderContainer(overrides: logStore, glove)
  → runApp(TalkhimikApp)
  → TTS initialize (non-blocking)
```

---

## 4. Feature Map (SRS codes → implementation)

| Code | Feature | Where |
|---|---|---|
| FR-1 | Recognized gestures rendered as text | `transcript_controller.dart`, `transcript_view.dart` |
| FR-2 | TTS speaks the sign (Filipino/English) | `tts_controller.dart`, `flutter_tts_service.dart` (C-S3) |
| FR-3 | Transcript bubbles with per-entry state | `transcript_entry.dart`, `transcript_bubble.dart` |
| FR-4 | Confidence badge (high/amber/red) | `confidence.dart`, `confidence_badge.dart` |
| FR-5 | Vocabulary lookup (word_id → text) | `vocab/`, `default_vocabulary_repository.dart` |
| FR-6 | User correction of a misrecognized sign | `transcript_controller.dart` (corrected, originalWordId) |
| FR-7 | Type a reply for the signer | `reply_panel.dart` |
| FR-8 | Per-user calibration profiles | `calibration_controller.dart`, `calibration_store.dart` |
| FR-9 | Record mode — labeled training data | `data_collection_controller.dart`, `collect_screen.dart` |
| FR-10 | Local event log + offline sync queue | `hive_log_store.dart` (C-S4 sync queue) |
| FR-12 | Connection status bar | `glove_controller.dart`, `device_status_bar.dart` |
| FR-13 | Participant ID + consent | `settings_controller.dart`, `participant.dart` (DR-4 anonymity) |
| FR-14 | Latency measurement | `latencyMs` in `GestureLogEntry` |
| FR-15 | Settings (language, rate, voice, large text) | `settings_controller.dart`, `tts_controller.dart` |
| FR-16 | Session summary + CSV export | `export_controller.dart`, `csv_exporter.dart` |
| NFR-1 | Gesture → text + speech ≤ 500 ms | `transcript_controller.dart` |
| NFR-7 | Terminology: "Deaf and non-speaking" | `app_strings.dart` (single audit point) |
| NFR-8 | Consent before data collection | `settings_service.dart`, `collect_screen.dart` |
| NFR-9 | "Connection lost" visible within 3 s | `glove_controller.dart` (C-S5) |
| C-F4 | Scan by advertised name prefix (unfiltered scan; service validated at GATT discovery) | `glove_connection_fbp.dart` |
| C-F5 | Command bytes to the glove | `AppCommand` enum + `sendCommand` |
| C-F7 | Stateless glove — reconnect = full re-run | `reconnect() => connect()` |
| C-S1 | BLE permission flow with friendly denial | `ble_permissions.dart` |
| C-S4 | Every event enters the sync queue | `hive_log_store.dart` |

---

## 5. GATT Contract (app side)

Constants in `lib/core/constants/gatt_ids.dart`, aligned 1:1 with the
as-built firmware (`TALKHIMIK_Thesis_Reference.md` §4.4, Code Reference
§5) — the app and the web dashboard now speak the same glove.

| Item | Value |
|---|---|
| Advertised device name | `TALKHIMIK-L` / `TALKHIMIK-R` (matched by prefix) |
| Glove Service | `d84f9c2e-6b1a-4e57-9f3d-2a8c7e5b1f04` |
| Telemetry | `7a3e1b9c-2d4f-48a6-b7e2-5c9d0f8a3b61` — READ + NOTIFY |
| Command | `3f8d2a6b-9c4e-4d7f-a1e3-6b5c8d0e2f49` — WRITE + WRITE-NO-RESPONSE |
| Device Status | `c2b6e8d4-1a7f-4c3e-9d5b-0f2a6e8c4d73` — READ + NOTIFY |
| CAL_INFO | `a1f2c3d4-5e6f-4a7b-8c9d-0e1f2a3b4c5d` — READ + NOTIFY |

### Telemetry — NOTIFY, 29 bytes, little-endian, every 50 ms

u8 hand · u16 seq · u8 flex[5] angles 0–90° · i16 roll/pitch/yaw ×10 ·
u16 raw ADC[5] · u32 calibration_id · u8 quality (bit0..4 valid mask,
bit5 weak span). Decoded by `TelemetryPacketCodec` into `TelemetryPacket`
(exposed through `GloveState.telemetry`). Raw sensor stream only — it
carries no recognized word.

### Device Status — READ + NOTIFY, 5 bytes, every 250 ms

u8 mode (0 streaming, 1 calibrating) · u8 calibration step (0 idle,
1–10 thumb-flat … pinky-90) · u8 battery % (`0xFF` = unknown) · u8 flags
(bit0 = uncalibrated, placeholder angles) · u8 error (1 capture-not-
calibrating · 2 unknown command · 3 90° within 5% of flat · 4 resistance
outside 1k..100k). Decoded by `DeviceStatusCodec`; the status bar shows
battery, an "Uncalibrated" chip (flags bit0), and firmware error labels.

### CAL_INFO — READ + NOTIFY, 104 bytes

The full calibration table (valid/weak masks, calibration_id, per-finger
flat/bent90 ohms + ADC, R_DIV, span counts, firmware version), read once
on connect and refreshed on every notify. Decoded by `CalInfoCodec` into
`CalInfoPacket` (`GloveState.calInfo`).

### App Command — WRITE, 1 opcode byte + optional LE payload (C-F5)

| Opcode | Command | Payload |
|---|---|---|
| 0x01 | startCalibration | — |
| 0x02 | captureFlat | — |
| 0x03 | capture90 | — |
| 0x04 | cancelCalibration | — |
| 0x05 | setRate | u16 LE ms (firmware clamps 20–1000) |
| 0x06 | zeroYaw | — |
| 0x07 | setHand | u8 (0 = L, 1 = R) |
| 0x08 | vibrate | u16 LE ms |

`AppCommand.encode(value:)` serializes opcode + payload (unit-tested).

### Production label packet (planned)

The 7-byte gesture result frame (word_id u16 + confidence u8 +
timestamp_ms u32, SRS Table III-2) is the contract for the on-glove TFLM
stage; `GesturePacketCodec` and its test are in place, and the mock glove
already drives the transcript through it. Until the firmware emits label
packets, a connected real glove feeds telemetry/status/CAL_INFO but no
transcript — the classifier or label-packet firmware is the next
milestone (checklist open item 4).

---

## 6. Connection Lifecycle

```
Connect tap → permissions (C-S1) → adapter on → scan (UNFILTERED; the
  TALKHIMIK name prefix is matched in Dart — OEM stacks throttle/drop
  service-filtered scans, 15 s) → connect (15 s) → discover services → find
  4 characteristics (firmware contract §5) → subscribe (telemetry + status
  + CAL_INFO) → READ status + CAL_INFO once → request balanced connection
  priority → ready
```

- **Phases** (`GloveConnectionPhase`): `disconnected → scanning → connecting
  → discoveringServices → ready` (+ `reconnecting`). The status bar shows
  these; the mock glove drives the same stream in demos/tests.
- **Auto-reconnect** (`GloveController`): on unexpected link loss the
  "connection lost" banner is set **immediately** (within the 3 s C-S5 bound)
  and retries follow `ReconnectPolicy.backoffSeconds` = 1, 2, 4, 8, then cap
  at 30 s. A deliberate disconnect never triggers the banner (C-F7 stateless
  glove; reconnect re-runs the full flow).
- **Failure surfacing**: explicit connect failures show a friendly snackbar
  (permission-denied vs. general); auto-reconnect failures stay silent.
- **After connect**: telemetry/status/CAL_INFO land in `GloveState` (battery,
  mode, calibration step, uncalibrated flag, firmware version, live sensor
  frames). The transcript stays mock-driven until label packets exist.

---

## 7. Persistence

### Hive boxes (hand-written adapters — pure Dart, same on Windows/Android/web)

| Box | Contents |
|---|---|
| `events` | `GestureLogEntry` rows (FR-10 schema: participant, session, word, confidence, latencyMs, glove timestamp, corrected, source, app/model version) |
| `syncQueue` | offline sync queue (C-S4) — every append enqueues; `markSynced` drains |
| `participants` | `ParticipantProfile` (anonymized ID, consent fields) |
| `sessions` | `SessionMeta` (startedAt, newest-first listing) |

Web: IndexedDB (`Hive.init('')` — path ignored). Windows/Android: app support
directory via `path_provider`.

### shared_preferences keys

`settings.outputLanguage` (`fil` default) · `settings.ttsRate` (1.0) ·
`settings.ttsVoice` · `settings.ttsMuted` · `settings.largeText` (on by
default, NFR-7) · `settings.participantId` · `settings.consentGiven` ·
`settings.consentDate` · `settings.forceMock` (dev) · `settings.demoScenario`
(dev).

### Calibration profiles (FR-8)

`SharedPrefsCalibrationProfileStore` — per-user profile JSON in
shared_preferences (overridden with an in-memory store in tests).

---

## 8. Screens

| Route | Screen | Purpose |
|---|---|---|
| `/` | Home | transcript, confidence badges, reply panel, device status bar, demo controls (mock only) |
| `/settings` | Settings | participant ID, consent, output language, TTS voice/rate/mute, large text, Force mock |
| `/calibration` | Calibration | guided per-user profile capture (FR-8) |
| `/collect` | Collect | Record mode — labeled training data (FR-9) |
| `/export` | Export | session summaries + one-tap CSV (FR-16) |

---

## 9. Testing

```
test/
├── unit/       # codecs, controllers, stores, vocabulary, confidence, CSV (11 files)
├── widget/     # every screen + key widgets against fakes (7 files)
├── integration/# smoke_core_loop_test — full mock path end to end
└── helpers/    # FakeGloveConnection, FakeTtsService, in-memory stores, test_overrides
```

`flutter analyze` clean + `flutter test` green covers everything off-device.
Hardware verification is staged in
[`ble-integration-checklist.md`](ble-integration-checklist.md): nRF Connect
first (Stage A), then app static checks (Stage B), end-to-end on Android
(Stage C), regression on the mock path (Stage D).

---

## 10. Platform Notes

- **Windows**: full app via mock glove; BLE classes compile but are never
  constructed off-Android/iOS.
- **Web**: `path_provider` has no web implementation — the bootstrap skips the
  directory lookup (`kIsWeb`) and Hive falls back to IndexedDB; CSV export
  fails fast with `UnsupportedError` (desktop/Android only). TTS degrades to
  `debugPrint` warnings, never crashes.
- **iOS**: target folders exist; not a supported target in the thesis scope.

---

## 11. Integration Status & Open Items

The glove ↔ app link is verified in stages
([`ble-integration-checklist.md`](ble-integration-checklist.md)). The
transport contract is now aligned with the as-built firmware (UUIDs, device
name, packet layouts, command opcodes — §5), so Stage A/B checks use the
firmware values directly. Open items to close with the firmware team:

- Calibration packet contract (FR-8): the app shell sends
  START/CANCEL_CALIBRATION but does not yet drive the firmware wizard steps
  (STATUS.calibrationStep → CAPTURE_FLAT/CAPTURE_90) — see
  `calibration_controller.dart`.
- Raw sensor stream contract for FR-9 (labeled streams vs. labeled result
  packets — see `data_collection_controller.dart`).
- The production label packet (word_id + confidence): firmware stage after
  on-glove TFLM; the mock models it today.

---

## 12. Companion Documents

| Document | Covers |
|---|---|
| [`TALKHIMIK_Thesis_Reference.md`](TALKHIMIK_Thesis_Reference.md) | Consolidated thesis reference: system architecture (what & why) + as-built firmware and web dashboard (what runs today) |
| [`ble-integration-checklist.md`](ble-integration-checklist.md) | Staged glove ↔ app verification and the open contract items |
| `README.md` (repo root) | Getting started, build, test commands |
