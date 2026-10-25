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
| Sharing | `share_plus` 13.3.1 (dataset share sheet, master §5.4) |

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
│   ├── models/                    # HandState, CalInfoPacket, DatasetSession, GestureLogEntry, …
│   ├── repositories/              # interfaces: LogStore, VocabularyRepository, CloudSync
│   ├── vocab/                     # FSL vocabulary table (word_id → Filipino/English)
│   └── sensing/sensor_math.dart   # divider → ohms → angle + wrap-safe seq gap (master §3)
├── data/
│   ├── codec/                     # strict LE decoders: telemetry, device status, CAL_INFO (+ planned label packet)
│   ├── dataset/                   # DatasetFileWriter — CSV + sidecar per session (master §5)
│   ├── glove/                     # GloveConnection interface + FlutterBlue impl + mock + factory + permissions
│   ├── storage/                   # HiveLogStore, CalInfo cache (mirror), settings service
│   ├── tts/                       # FlutterTtsService (degrades, never throws)
│   └── vocab/
├── application/
│   ├── providers.dart             # composition root — every provider in one file
│   ├── glove_controller.dart      # connection phases + auto-reconnect state machine
│   ├── transcript_controller.dart # recognized gestures → bubbles, corrections, TTS, logging
│   ├── tts_controller.dart        # FR-2/FR-15 voice, rate, language, mute
│   ├── settings_controller.dart   # FR-13/FR-15 participant, consent, accessibility
│   ├── live_controller.dart       # per-hand HandState: loss, rate, mismatch (master §6)
│   ├── calibration_controller.dart# firmware-driven 10-step wizard (master §4)
│   ├── dataset_recorder_controller.dart # 5 Hz calibration-aware recorder (master §5)
│   └── export_controller.dart     # FR-16 session summaries + CSV export
└── ui/
    ├── screens/                   # home, live, settings, export, calibration, collect
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
| FR-8 | Firmware-driven 10-step calibration wizard (glove-authoritative CAL_INFO) | `calibration_controller.dart`, `calinfo_cache.dart` |
| FR-9 | Dataset recorder — labeled 5 Hz streams, CSV + sidecar | `dataset_recorder_controller.dart`, `dataset_file_writer.dart` |
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

**Single source of truth: `TALKHIMIK_Master_Integration.md` §2** — service/characteristic
UUIDs, all four packet layouts (29/5/104 bytes), and the COMMAND opcode table live
there and in `lib/core/constants/gatt_ids.dart` + the codecs. This section
deliberately holds no copy of those tables.

### Production label packet (planned)

The 7-byte gesture result frame (word_id u16 + confidence u8 +
timestamp_ms u32, SRS Table III-2) is the contract for the on-glove TFLM
stage; `GesturePacketCodec` and its test are in place, and the mock glove
already drives the transcript through it. Until the firmware emits label
packets, a connected real glove feeds telemetry/status/CAL_INFO but no
transcript — the classifier or label-packet firmware is the next
milestone (checklist open item).

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
| `sessions` | `SessionMeta` (startedAt, newest-first listing) |

Web: IndexedDB (`Hive.init('')` — path ignored). Windows/Android: app support
directory via `path_provider`.

### shared_preferences keys

`settings.outputLanguage` (`fil` default) · `settings.ttsRate` (1.0) ·
`settings.ttsVoice` · `settings.ttsMuted` · `settings.largeText` (on by
default, NFR-7) · `settings.participantId` · `settings.consentGiven` ·
`settings.consentDate` · `settings.forceMock` (dev) · `settings.demoScenario`
(dev).

### Calibration mirror (master §4.5)

`SharedPrefsCalInfoCache` — last-known CAL_INFO per hand (`calinfo.L` /
`calinfo.R` JSON). Mirror only: the glove's NVS is the calibration
authority; the cache shows the last profile while disconnected and feeds
dataset sidecars. The LiveController owns the mirror write.

### Dataset files (master §5.4)

App-support dir `talkhimik_dataset/` — `talkhimik_<L|R>_<session>_cal<id>.csv`
+ `..._sidecar.json` per session, rows appended as recorded; the sessions
list is rebuilt from sidecars (newest first) and files are shared via
`share_plus`.

---

## 8. Screens

| Route | Screen | Purpose |
|---|---|---|
| `/` | Home | transcript, confidence badges, reply panel, device status bar, demo controls (mock only), Live entry |
| `/live` | Live | both gloves: animated hands, angle bars, raw ADC + Ω, IMU tiles, health badges, zero-yaw/vibrate (master §6) |
| `/settings` | Settings | participant ID, consent, output language, TTS voice/rate/mute, large text, Force mock |
| `/calibration` | Calibration | firmware-driven 10-step wizard + CAL_INFO summary (master §4) |
| `/collect` | Collect | dataset recorder: labeled takes, sessions list, share/delete (master §5) |
| `/export` | Export | FR-16 event session summaries + one-tap CSV |

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
transport contract is aligned with the as-built firmware (master §2), and
the master integration (§4 wizard, §5 recorder) is implemented and covered
by unit/widget/mock end-to-end tests. Open items:

- Production label packet: the 7-byte gesture result contract
  (`gesture_packet_codec.dart`, SRS Table III-2) vs. the raw telemetry
  stream — until the firmware sends labels (or the optional phone-side
  classifier lands, master Phase 7), the transcript works only with the
  mock glove.
- Hardware verification (checklist Stages A/C) on the realme test phone
  with a real glove — the mock covers everything off-device.

---

## 12. Companion Documents

| Document | Covers |
|---|---|
| [`TALKHIMIK_Thesis_Reference.md`](TALKHIMIK_Thesis_Reference.md) | Consolidated thesis reference: system architecture (what & why) + as-built firmware and web dashboard (what runs today) |
| [`ble-integration-checklist.md`](ble-integration-checklist.md) | Staged glove ↔ app verification and the open contract items |
| `README.md` (repo root) | Getting started, build, test commands |
