<!--
  TALKHIMIK — single source of documentation (2026-10, post-merge).
  Absorbs: TALKHIMIK_App_System.md, TALKHIMIK_Master_Integration.md §2–§9,
  ble-integration-checklist.md, and the thesis reference (originals remain
  in the thesis folder: Desktop/thesis sep4/).
-->

# TALKHIMIK — FSL Smart Glove System

**"Bridging silent gestures to spoken Filipino words"**

| | |
|---|---|
| **Team** | Daryl D. Bacusmo · Dewey Raven S. Cabahug · Sheena Patricia Kaye Caneja · Joppy B. Vargas (Team Sagbotics) |
| **Adviser** | Engr. Nikko D. Alferez — CIT University |
| **App** | `talkhimik_app` (Flutter) · **Firmware** | `talkhimik-ble` fw 1.2.0 (ESP32-S3 ×2) |
| **App version** | 0.1.0+1 · Dart `^3.13.2` |

**Current stage:** two Seeed XIAO ESP32S3 BLE gloves (5 flex sensors +
MPU-6050/6500 each) stream telemetry to the app over BLE; the app renders
two animated hands, drives the firmware calibration wizard, and records
calibration-aware datasets (CSV + sidecar). On-glove TFLM label packets are
the next firmware stage (planned).

---

## 1. Glove contract (byte-exact, little-endian) — SINGLE COPY

| Item | Value |
|---|---|
| Device name | `TALKHIMIK-L` (hand 0) / `TALKHIMIK-R` (hand 1) — full-name scan match |
| Service | `d84f9c2e-6b1a-4e57-9f3d-2a8c7e5b1f04` |
| TELEMETRY (read+notify) | `7a3e1b9c-2d4f-48a6-b7e2-5c9d0f8a3b61` |
| COMMAND (write / write-no-resp) | `3f8d2a6b-9c4e-4d7f-a1e3-6b5c8d0e2f49` |
| STATUS (read+notify) | `c2b6e8d4-1a7f-4c3e-9d5b-0f2a6e8c4d73` |
| CAL_INFO (read+notify) | `a1f2c3d4-5e6f-4a7b-8c9d-0e1f2a3b4c5d` |

One central per glove. MTU 247. Finger order everywhere: **thumb, pointer,
middle, ring, pinky** (0–4).

### TELEMETRY — 29 bytes, every 50 ms (SET_RATE 20–1000)

| Off | Type | Field |
|---|---|---|
| 0 | u8 | hand (0 = L, 1 = R) |
| 1–2 | u16 | seq (wraps at 65536) |
| 3–7 | u8 ×5 | flex angle 0–90° |
| 8–9 / 10–11 / 12–13 | i16 ×3 | roll / pitch / yaw ×10 (degrees = value / 10) |
| 14–23 | u16 ×5 | raw 12-bit ADC |
| 24–27 | u32 | calibration_id (0 = never calibrated) |
| 28 | u8 | quality: bit0..4 = finger valid, bit5 = any weak span |

Reject frames ≠ 29 bytes.

### STATUS — 5 bytes, every 250 ms

| Off | Type | Field |
|---|---|---|
| 0 | u8 | mode (0 streaming, 1 calibrating) |
| 1 | u8 | calibration step (0 idle; 1–10) |
| 2 | u8 | battery % (`0xFF` = unknown — the glove always sends this) |
| 3 | u8 | flags (bit0 = uncalibrated → placeholder angles) |
| 4 | u8 | error: 0 none · 1 capture-not-calibrating · 2 unknown command · 3 90° within 5% of flat (redo) · 4 resistance outside 1k..100k (finger fault) |

### CAL_INFO — 104 bytes, read on connect + notify on every save

| Off | Type | Field |
|---|---|---|
| 0 / 1 | u8 | valid mask / weak mask (bit0..4) |
| 2–5 | u32 | calibration_id |
| 6–25 | f32 ×5 | flat_ohm |
| 26–45 | f32 ×5 | bent90_ohm |
| 46–55 | u16 ×5 | flat_adc |
| 56–65 | u16 ×5 | bent90_adc |
| 66–85 | f32 ×5 | R_DIV (values used for this profile) |
| 86–95 | u16 ×5 | span_counts |
| 96–103 | u8 ×8 | firmware version, ASCII, zero-padded |

### COMMAND — u8 opcode + optional LE payload

| Op | Name | Payload |
|---|---|---|
| 0x01 | START_CALIBRATION | — |
| 0x02 | CAPTURE_FLAT | — |
| 0x03 | CAPTURE_90 | — |
| 0x04 | CANCEL_CALIBRATION | — |
| 0x05 | SET_RATE | u16 ms (clamped 20–1000) |
| 0x06 | ZERO_YAW | — |
| 0x07 | SET_HAND | u8 (0 L / 1 R; name updates on reboot) |
| 0x08 | VIBRATE | u16 ms |

### Production label packet (planned)

7 bytes: word_id u16 + confidence u8 + timestamp_ms u32 (SRS Table III-2).
`GesturePacketCodec` + test are in place; the mock drives the transcript
through it. Until the firmware sends labels (or the optional phone-side
classifier lands), the transcript works only with the mock glove.

---

## 2. Sensor math

Wiring: 3.3 V → flex sensor → ADC pin → `R_DIV` → GND.

```
R_sensor = R_DIV × (4095 − adc) / adc        // adc ≤ 0 → huge; adc ≥ 4095 → ~0
angle    = clamp( 90 × (R − R_flat) / (R_bent90 − R_flat), 0, 90 )   // degenerate span → 0
seqGap(last, now) = (now − last − 1) & 0xFFFF                        // wrap-safe
```

`R_flat`/`R_bent90`/`R_DIV` always come from CAL_INFO. Telemetry angles are
for display; the dataset recomputes ohm/angle from raw + CAL_INFO so files
re-derive from raw + sidecar alone. Golden vectors are unit-tested.

---

## 3. Architecture

Layers: **ui → application → domain ← data**. Composition root:
`lib/application/providers.dart`.

```
lib/
├── main.dart                      # Hive init → settings → 2 glove connections → runApp
├── core/constants/gatt_ids.dart   # §1 contract + reconnect policy (1,2,4,8,30 s)
├── domain/
│   ├── sensing/sensor_math.dart   # §2
│   ├── models/                    # HandState, CalInfoPacket, TelemetryPacket, DatasetSession, …
│   ├── repositories/              # LogStore, VocabularyRepository, CloudSync
│   └── vocab/                     # 28 letters + phrases (word_id → fil/eng)
├── data/
│   ├── codec/                     # telemetry/status/CAL_INFO + planned label packet
│   ├── dataset/dataset_file_writer.dart
│   ├── glove/                     # GloveConnection (BLE/mock/factory/permissions)
│   ├── storage/                   # HiveLogStore, CalInfo cache, settings
│   └── tts/
├── application/                   # controllers: glove, live, calibration, recorder, …
└── ui/screens/                    # home, live, calibration, collect, export, settings
```

### Two-glove model

- One connection per hand. The keep-area primary (`gloveConnectionProvider`)
  is the **left** glove (transcript/demo path); `rightGloveConnectionProvider`
  + `rightGloveControllerProvider` serve the right glove.
- Scans are UNFILTERED and match the full advertised name
  (`TALKHIMIK-L` / `-R`); GATT discovery validates the service.
- A telemetry `hand` byte disagreeing with the glove name → data trusted,
  mismatch badge shown.
- Factory: BLE on Android/iOS only; mock everywhere else (and with the
  Settings "Force mock" flag). Mock auto-connects both hands on web/Windows.
- Reconnect per hand: backoff 1→2→4→8→30 s, "connection lost" banner ≤ 3 s,
  stateless glove re-runs the full flow (C-F7).

### Feature map

| Code | Feature | Where |
|---|---|---|
| FR-1..7 | Transcript, TTS, bubbles, confidence, vocabulary, corrections, reply | transcript/tts controllers (keep areas) |
| FR-8 | Firmware-driven 10-step calibration wizard, glove-authoritative | `calibration_controller.dart`, `calinfo_cache.dart` |
| FR-9 | Dataset recorder — 5 Hz labeled streams, CSV + sidecar | `dataset_recorder_controller.dart`, `dataset_file_writer.dart` |
| FR-10 | Hive event log + sync queue (C-S4) | `hive_log_store.dart` (boxes: events, syncQueue, sessions) |
| FR-12 | Status bar (both gloves aggregate) | `device_status_bar.dart` |
| FR-13 | Anonymized participant id + consent (shared_preferences only) | `settings_controller.dart`, `settings_service.dart` |
| FR-15 | TTS/settings | tts/settings controllers |
| FR-16 | Event CSV export | `export_controller.dart` |
| NFR-1/7/8/9 | Latency ≤ 500 ms · terminology · consent gate · 3 s banner | transcript, strings, recorder, glove |

---

## 4. Live screen (`/live`)

Two hand panels (side-by-side wide, tabbed L/R on phones), driven by
`liveControllerProvider` (HandState per hand: latest packets, wrap-safe
seq-gap loss, trailing-second update rate, mismatch flag):

- **HandView** — CustomPainter, 3-segment fingers, mirrored left, yaw
  in-plane + roll/pitch skew, ticker low-pass, invalid ✗ / uncalibrated
  desaturated / stale 40 % opacity
- Finger bars (0–90°, invalid dimmed, weak amber) · raw ADC + Ω details
  (collapsed expander; recomputed via §2) · IMU tiles (yaw labelled
  relative — gyro-only)
- One merged health line: freshness (> 500 ms = stale), packet loss %,
  update rate — plus a stale chip and the hand-mismatch warning when they
  apply. Battery is hidden until the firmware actually reports it.
- Actions: Zero yaw (0x06), Record → `/collect`, calibration chip
  (cal_id + fw version) → `/calibration`

---

## 5. Calibration wizard (glove-authoritative)

- **The glove is the authority.** NVS holds the profile; the app mirrors
  CAL_INFO into `SharedPrefsCalInfoCache` (`calinfo.L` / `calinfo.R`) —
  shown while disconnected, never edited.
- Flow: Start (0x01) → step driven by STATUS (1–10; odd = flat → 0x02,
  even = 90° → 0x03) → after step 10 the firmware saves and pushes CAL_INFO
  with a bumped `calibration_id` → mode returns to 0 → **done**.
- The app never advances locally; Capture re-enables on the next STATUS or
  after a 1.5 s fallback. Completion = mode 0 **and** id greater than at
  start (0 → 1 works for first calibration).
- Errors: 3 → stay on step, "Bend further and try again." · 4 → firmware
  advances, "check wiring" noted on that finger · 1/2 → informational.
- Cancel (0x04) keeps the previous profile. Summary: per-finger
  valid/weak/flat Ω/90° Ω/span + header (cal_id, fw, R_DIV).

---

## 6. Dataset recorder (5 Hz, calibration-aware)

- One session per (hand, calibration_id) — a change closes the file and
  opens a new one; files never mix calibrations. `cal_id == 0` blocks
  recording.
- Drops counted, never kept: raw 0/4095 on a **valid** finger (`adcRail`),
  wrap-safe seq gap > 3 (`seqGap`). Invalid fingers lose their columns.
- Takes: each Start press increments `take_id` (new session → 1); rows only
  flow while a labeled take runs; empty label blocked. Signer id =
  participantId (FR-13) or `anon-XXXX`. Consent gate unchanged (NFR-8).
- Files (app-support `talkhimik_dataset/`):
  `talkhimik_<L|R>_<session_id>_cal<cal_id>.csv` + `_sidecar.json`.
  CSV header (§ thumb columns only if valid bit0, first in each group):
  `timestamp_ms, session_id, signer_id, hand, calibration_id, label,
  take_id, raw_*, ohm_*, ang_*, roll, pitch, yaw, quality_flag`.
  Sidecar: session/signer/hand/cal_id/rate/fw/recorded_at/rows/dropped
  {adcRail, seqGap}/r_div/fingers{valid,weak,flat/bent ohm+adc,span}.
- Rows are appended as recorded (crash-safe); sessions list newest first
  with size, Share (`share_plus`) and Delete. Web/Windows without path
  provider: recording unsupported (graceful `UnsupportedError`).

---

## 7. Persistence & settings

- **Hive** (pure Dart; IndexedDB on web): `events`, `syncQueue` (C-S4),
  `sessions`. Participant id/consent live in shared_preferences only.
- **shared_preferences**: language/rate/voice/mute, large text,
  participantId, consentGiven/Date, forceMock + demoScenario (in the
  Settings "Developer" section), calinfo.L/R.
- **Mock glove** (dev/demo/test): transcript scenarios (alphabet sweep,
  mixed confidence, random disconnect), animated telemetry, wizard with
  forced errors 3/4, loss bursts every 7 s, per hand.

---

## 8. Testing

155 tests, `flutter analyze` clean, per-phase commits.

- **Unit**: sensor-math golden vectors + seqGap wrap · codecs vs §1 ·
  wizard step/error/completion · recorder rules (cal change, cal 0 gate,
  rail/gap drops, take_id, consent, label) · writer goldens (exact header,
  sidecar keys, ohm/angle re-derive)
- **Widget**: live screen (both hands, stale, uncalibrated, mismatch,
  zero-yaw target) · calibration wizard prompts · collect gates
- **Integration**: mock end-to-end — calibrate → record → export →
  re-derive from raw + sidecar

### Hardware verification (staged, nRF Connect first)

- **A.** nRF Connect: `TALKHIMIK-L/R` advertising §1 service; four
  characteristics; 29/5/104-byte frames; opcodes 0x01–0x08; stateless
  reconnect.
- **B.** App static: BLE manifest permissions; Force mock off; analyze +
  tests green; `flutter build apk --debug`.
- **C.** Phone + glove: permissions → Scanning…→ Connected; battery "—"
  and Uncalibrated chip; Live hand moves; wizard steps 1–10 with `cal_id`
  bump; record labeled take → CSV + sidecar; connection-lost banner ≤ 3 s
  with 1→2→4→8→30 s backoff; walk out of range and back — no dupes.
- **D.** Regression: Force mock on → demo still works end-to-end.

---

## 9. Definition of done

- ✅ Mock demonstrates every state on Windows/web without hardware.
- ✅ Keep areas (transcript/TTS/settings/Hive log/export/reconnect) behave
  as before; existing tests green.
- ✅ Zero connectivity — no network calls.
- ⚠️ Real glove flow (connect → live → wizard → record → export → re-derive)
  passes on the mock; hardware verification pending (§8 A–C).
- ⚠️ Both gloves simultaneously: code + tests ready; realme multi-connection
  unverified.

### Open items

- Production label packet (planned §1) — transcript from the real glove
  needs it or the optional phone-side classifier.
- Hardware verification on the realme phone with real gloves.

---

## 10. Dev environment & platforms

- **Android** (primary): SDK 36 + Temurin JDK 17 at `D:\Android`
  (`flutter config --android-sdk/--jdk-dir`); `flutter build apk` green;
  app installed on the realme field phone. BLE needs a physical phone.
- **Windows**: dev machine — mock gloves, full UI.
- **Web (`flutter run -d chrome`)**: mock gloves only; Hive in IndexedDB;
  TTS degrades; dataset recording unsupported. Demo: Home scenarios + Live
  two animated hands + mock wizard.
- **iOS**: no target — out of thesis scope.

---

## 11. Thesis pointers

The thesis-level narrative (architecture, phases, budget, ML pipeline) lives
in the thesis folder: `Desktop/thesis sep4/` — `TALKHIMIK_System_Architecture.md`,
`TALKHIMIK_Code_Reference.md`, and the firmware repo `talkhimik-ble/`
(README: wiring, build steps, packet quickstart).

---

## 12. Design system (2026-10 refresh)

Source of truth: `lib/core/theme/app_theme.dart` (`AppColors` + the
`TalkhimikTokens` ThemeExtension). LIGHT is the primary theme; dark derives
from the same hues.

| Token | Light | Role |
|---|---|---|
| primary | `#067A4C` | App bar, filled buttons, active tab (white text, AA) |
| secondary | `#17713F` | Diagonal corner, outlines |
| tertiary | `#7CA526` | Header bands; on-band text `#1C280A` (AA — white fails) |
| background / surface | `#D6D4CD` / `#EAE8E2` | Warm-gray page / cards |
| success / warning / error | `#1B7A3D` / `#B26A00` / `#B3261E` | State colors |
| finger gradient | `#D8D0C4` → `#7CA526` | Flexion fill (neutral → lime) |

Radius: cards 16 · controls 12 · pills 999. Elevation: cards 1 (soft
shadow), app bar 0. Confidence badges are **outline-style** (dot + border +
tint) so they never read as brand surfaces; finger states keep non-color
cues (✗ hatch, ⚠ amber, desaturation, 40 % opacity). Shared `HeaderBand`
(olive-lime band + diagonal corner + chip) heads every panel; pill tabs
switch L/R and navigation. "Reduce motion" is respected by the hand
animation.

### Typography & motion

- **Font**: Inter 400/500/600/700, bundled (`assets/fonts/`, OFL) — never
  fetched at runtime (C6). Full M3 TextTheme (display 36 → label 11) plus
  `TalkhimikText` extension: `bandTitle` 16/700, `transcriptWord` 32/600
  (the product's main text), `metric`/`id` with tabular figures.
- **Motion** (`TalkhimikMotion`): 100/180/280/420 ms ·
  easeOutCubic/easeOut/easeIn/easeInOutCubicEmphasized/elasticOut.
  `resolve()` zeroes every duration under reduce-motion.
- **What animates**: Live (stale fade, cal_id chip pulse, finger bars,
  tabular metrics) · status bar (busy dot pulse, label crossfade) ·
  wizard (step slide+fade, flat↔90 icon, error-3 shake, checkmark pop +
  cal_id count-up) · recorder (recording dot, haptics on start/stop,
  session-card entrance) · transcript (bubble entrance, corrected flash,
  badge color ease) · shared fade-through page transitions, brand ripples,
  pressed-scale microinteraction. Haptics: capture accepted, calibration
  complete, recording start/stop.
- **Rejected for perf/accessibility**: skeleton shimmer (would need a
  loading-state flag = logic change), TTS "speaking" bars (no completion
  signal without protocol changes), session-card exit choreography
  (AnimatedList too invasive; deletion stays instant), painter-level
  desaturation tween (label/chip fades cover the state change).
- **Large text**: verified at 1.0/1.3/2.0 × on 360 dp for all six screens
  (test/widget/typography_scale_test.dart); bands and chips ellipsize.
