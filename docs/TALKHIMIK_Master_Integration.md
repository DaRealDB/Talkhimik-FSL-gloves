<!--
  TALKHIMIK — MASTER INTEGRATION SPEC
  Merges the "Glove/Dashboard system" (ESP32 firmware + Web Bluetooth dashboard)
  INTO the "Flutter companion app" (talkhimik_app).

  Sources merged:
    A. TALKHIMIK_System_Concept.md        (stack-independent ideas)
    B. TALKHIMIK_Code_Reference.md        (as-built firmware + dashboard, byte-exact)
    C. TALKHIMIK_System_Architecture.md   (thesis rationale)
    D. TALKHIMIK_App_System.md            (target: Flutter app, as built)

  This file is self-contained: an engineer or AI agent can implement the merge
  from this file alone. Where it conflicts with D on the four override areas
  (§1), THIS FILE WINS. Everywhere else, D wins.
-->

# TALKHIMIK — Master Integration Spec

## 0. How to read this document

| If you are… | Read |
|---|---|
| Implementing | §1 → §2 → §3 → §4 → §5 → §6 → §7 → §9 → §10 (in order) |
| Reviewing a conflict | §8 |
| Checking "is this done?" | §10 (phases + definition of done) and §11 (tests) |

**Precedence rule (non-negotiable):**

1. The **override areas** in §1.1 are defined by this file. If `TALKHIMIK_App_System.md`
   (D) describes them differently, D is superseded for those areas only.
2. Everything in §1.2 (the **keep areas**) stays exactly as D describes it. Do not
   refactor, rename, or "improve" it.
3. The **byte-level glove contract** (§2) is identical in B, C and D. If any code
   in the repo disagrees with §2, the code is wrong — fix the code, not §2
   (exception: if the firmware team has changed the firmware, §2 must be updated first).

---

## 1. Scope of the merge

**Goal:** the Flutter app (`talkhimik_app`) gains the glove-system's four core
features, replacing the app's thinner placeholders for them:

| # | Feature (from the glove system) | Replaces in the app |
|---|---|---|
| **O1** | **Sensor values** — live per-hand telemetry view (angles, raw ADC, IMU, calibration id, quality, connection health) | nothing today (telemetry is decoded into `GloveState` but never shown) |
| **O2** | **Hand animation** — two animated hands driven by live finger angles + IMU | nothing today |
| **O3** | **Calibration** — firmware-driven 10-step wizard, glove-authoritative, versioned by `calibration_id`, with quality gates | `calibration_controller.dart`, `calibration_store.dart` (shared_prefs profiles), `/calibration` screen (FR-8 shell that only sends START/CANCEL) |
| **O4** | **Dataset** — calibration-aware recorder, CSV + sidecar JSON per session | `data_collection_controller.dart`, `/collect` screen (FR-9 with undefined stream contract) |

### 1.1 Override areas (this file is the authority)

O1–O4 above, plus the **multi-glove (L + R) connection model** they require (§7.3).

### 1.2 Keep areas (D is the authority — do NOT touch)

Transcript bubbles, confidence badge, vocabulary (FR-1…FR-7), TTS (FR-2/FR-15),
settings/participant/consent (FR-13, NFR-8), Hive event log + sync queue (FR-10,
C-S4), session summary + event CSV export (FR-16, `csv_exporter.dart`), the
connection lifecycle and backoff (§6 of D), permissions (C-S1), theme, strings
audit (NFR-7), mock-glove demo controls, existing tests that cover those.

> The existing **event** export (`export_controller.dart`, session summaries of
> recognized gestures) and the new **dataset** export (§5) are two different
> things with two different schemas. Both stay. Do not merge them.

### 1.3 Explicitly out of scope for this merge

- On-glove TFLM / the 7-byte production label packet (D §5 "planned") — stays planned.
- Firmware changes. The glove firmware is frozen at `FW_VERSION 1.2.0` for this work.
- Wi-Fi/MQTT, cloud sync, iOS-specific work.
- The 10-class threshold classifier is **optional** (§9, Phase 7). It is not part of O1–O4.

---

## 2. The glove contract (byte-exact, little-endian everywhere)

Already implemented on the app side by `TelemetryPacketCodec`, `DeviceStatusCodec`,
`CalInfoCodec`, `AppCommand`. **Verify them against this section; do not rewrite
them if they match.**

### 2.1 GATT

| Item | Value |
|---|---|
| Device name (prefix match) | `TALKHIMIK-L` (hand 0) / `TALKHIMIK-R` (hand 1) |
| Service | `d84f9c2e-6b1a-4e57-9f3d-2a8c7e5b1f04` |
| TELEMETRY (read+notify) | `7a3e1b9c-2d4f-48a6-b7e2-5c9d0f8a3b61` |
| COMMAND (write / write-no-resp) | `3f8d2a6b-9c4e-4d7f-a1e3-6b5c8d0e2f49` |
| STATUS (read+notify) | `c2b6e8d4-1a7f-4c3e-9d5b-0f2a6e8c4d73` |
| CAL_INFO (read+notify) | `a1f2c3d4-5e6f-4a7b-8c9d-0e1f2a3b4c5d` |

One central per glove. Firmware requests MTU 247 (29 B and 104 B frames need it).
Finger order everywhere: **thumb, pointer, middle, ring, pinky** (index 0–4).

### 2.2 TELEMETRY — 29 bytes, every 50 ms (SET_RATE 20–1000 ms)

| Off | Type | Field |
|---|---|---|
| 0 | u8 | hand (0 = L, 1 = R) |
| 1–2 | u16 | seq (wraps at 65536) |
| 3–7 | u8 ×5 | flex angle 0–90° |
| 8–9 | i16 | roll ×10 |
| 10–11 | i16 | pitch ×10 |
| 12–13 | i16 | yaw ×10 |
| 14–23 | u16 ×5 | raw 12-bit ADC |
| 24–27 | u32 | calibration_id (0 = never calibrated) |
| 28 | u8 | quality: bit0..4 = finger valid, bit5 = any weak span |

IMU angles in degrees = value / 10.0. Reject any frame whose length ≠ 29.

### 2.3 STATUS — 5 bytes, every 250 ms

| Off | Type | Field |
|---|---|---|
| 0 | u8 | mode (0 streaming, 1 calibrating) |
| 1 | u8 | calibration step (0 idle; 1–10) |
| 2 | u8 | battery % (`0xFF` = unknown — the glove currently always sends this) |
| 3 | u8 | flags (bit0 = uncalibrated → angles are placeholders) |
| 4 | u8 | error: 0 none · 1 capture while not calibrating · 2 unknown command · 3 90° within 5% of flat (redo) · 4 resistance outside 1k..100k (finger fault) |

### 2.4 CAL_INFO — 104 bytes, read on connect + notified on every save

| Off | Type | Field |
|---|---|---|
| 0 | u8 | valid mask (bit0..4) |
| 1 | u8 | weak mask (bit0..4, span < 100 counts) |
| 2–5 | u32 | calibration_id |
| 6–25 | f32 ×5 | flat_ohm |
| 26–45 | f32 ×5 | bent90_ohm |
| 46–55 | u16 ×5 | flat_adc |
| 56–65 | u16 ×5 | bent90_adc |
| 66–85 | f32 ×5 | R_DIV (values used for this profile) |
| 86–95 | u16 ×5 | span_counts |
| 96–103 | u8 ×8 | firmware version, ASCII, zero-padded |

### 2.5 COMMAND — u8 opcode + optional LE payload

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

---

## 3. Sensor math (concept C1 — keep exactly)

Wiring: 3.3 V → flex sensor → ADC pin → `R_DIV` → GND. So:

```
R_sensor = R_DIV × (4095 − adc) / adc          // adc ≤ 0 → huge; adc ≥ 4095 → ~0
angle    = clamp( 90 × (R − R_flat) / (R_bent90 − R_flat), 0, 90 )   // degenerate span → 0
```

- Works whether resistance rises **or** falls with bend (sign cancels in the ratio).
- `R_flat`, `R_bent90`, `R_DIV` come from **CAL_INFO** (per finger). Never hard-code 10 kΩ in the app.
- The firmware already sends angles in TELEMETRY. The app uses the **telemetry angle for display** (O1/O2) and
  **recomputes ohm + angle from raw ADC + CAL_INFO for the dataset** (O4), exactly as the dashboard does —
  this keeps the recorded data reproducible from `raw` + sidecar alone.

**Golden vectors** (must be unit tests):

| Case | Input | Expected |
|---|---|---|
| ohms | R_DIV 10000, adc 1365 | 20000.0 Ω |
| ohms | R_DIV 10000, adc 2048 | ≈ 9995.12 Ω |
| angle, rising | flat 10000, bent90 30000, R 20000 | 45.0° |
| angle, falling | flat 30000, bent90 10000, R 20000 | 45.0° |
| clamp | flat 10000, bent90 30000, R 40000 | 90.0° |
| clamp | flat 10000, bent90 30000, R 5000 | 0.0° |
| degenerate | flat == bent90 | 0.0° |

---

## 4. Calibration (O3)

### 4.1 Principles (concepts C2 + C4)

1. **The glove is the authority.** The profile lives in the glove's NVS. The app
   never invents, edits, or locally persists a "profile" as truth. It **mirrors CAL_INFO**.
2. Calibration is **versioned data**: `calibration_id` (u32) bumps on every
   saved calibration; every recorded sample carries it.
3. **Quality gates** are enforced by the firmware; the app only *surfaces* them (§4.3).
4. Changing the firmware's `R_DIV[]` invalidates the stored profile → glove
   reports `flags.bit0 = 1` / `calibration_id = 0` → the app shows "Uncalibrated"
   and the wizard CTA.

### 4.2 Wizard state machine (app side)

Per hand (L and R calibrate independently, one at a time).

```
IDLE ──[Start]──► send 0x01 ──► wait STATUS.mode==1 && step==1
  step odd  (1,3,5,7,9)  = finger (step-1)/2, waiting FLAT   → user flattens finger → [Capture] → send 0x02
  step even (2,4,6,8,10) = finger (step-2)/2, waiting 90°     → user bends 90°       → [Capture] → send 0x03
  after step 10 capture: firmware quality-gates → saves to NVS → STATUS.mode==0, step==0
                         → CAL_INFO notify with NEW calibration_id → DONE
[Cancel] at any time → send 0x04 → previous profile kept
```

Rules for the UI:

- **Never advance locally.** The current step shown is always `STATUS.calibrationStep`.
  Send a capture command only when the user taps Capture; wait for the next STATUS
  to move on. (Firmware auto-advances after a good `CAPTURE_90`.)
- Finger index from step: `finger = (step - 1) ~/ 2`; phase = flat if `step.isOdd` else bent90.
- Prompt copy per step: "Hold your **<finger>** flat" / "Bend your **<finger>** to 90°"
  (all copy goes through `app_strings.dart`; keep NFR-7 terminology).
- The capture takes ~300 ms on the glove (30 samples × 10 ms). Disable the
  Capture button until the next STATUS arrives (or 1.5 s timeout → re-enable with a hint).
- Wizard completion is detected by: `mode` returns to 0 **and** CAL_INFO's
  `calibration_id` is greater than the id seen at wizard start.

### 4.3 Error handling (STATUS.error)

| Code | Meaning | UI behavior |
|---|---|---|
| 3 | 90° within 5% of flat | Capture rejected. **Stay on the same step.** Message: "Bend further and try again." Do not advance. |
| 4 | resistance outside 1k–100k Ω | Finger marked invalid on the glove (excluded from recordings). Wizard **advances** (firmware does not loop). Show a "check wiring" warning on that finger in the summary. |
| 1 | capture while not calibrating | Out-of-sequence; ignore and resync to STATUS. |
| 2 | unknown command | Log; show generic error. |

Weak span (CAL_INFO weak mask / telemetry quality bit5) → **accepted**, show an amber "weak signal" chip on that finger.

### 4.4 Calibration summary (shown at the end and on the Live screen)

Per finger: valid ✓/✗, weak ⚠, flat Ω, 90° Ω, span counts. Header: `calibration_id`,
firmware version, R_DIV. Source: the mirrored `CalInfoPacket` — never anything else.

### 4.5 What happens to the app's old calibration code

- `calibration_controller.dart` → **rewritten** as the wizard state machine above.
- `calibration_store.dart` / `SharedPrefsCalibrationProfileStore` → **removed as a source of truth.**
  Replace with a thin **CalInfo cache** (`last known CalInfoPacket per hand`, for showing the
  last profile while the glove is disconnected, and for dataset sidecars). Hive box `calinfo`
  (key = `L` / `R`) or shared_preferences JSON — implementer's choice, must be pure Dart.
- FR-8 in D's feature map is **redefined** as "Per-glove calibration wizard (this section)".

---

## 5. Dataset recorder (O4)

### 5.1 Rules (concept C3 — the ones that make data trainable)

| Rule | Detail |
|---|---|
| Sample rate | **200 ms (5 Hz)** per connected glove, taken from the latest telemetry frame |
| One session per (hand, calibration_id) | `ensureSession()` compares the live telemetry `calibration_id` with the active session; on change → **close** that session (finalize files) and open a new one. Files never mix calibrations. |
| Never record uncalibrated | `calibration_id == 0` → recording disabled, UI says why |
| Frame drop: ADC rail | raw == 0 or raw == 4095 on any **valid** finger → drop, count `adcRail` |
| Frame drop: seq gap | gap > 3 → drop, count `seqGap`. Gap = `(seq − lastSeq − 1) mod 65536`. Wrap-safe. |
| Invalid fingers | fingers with valid-mask bit = 0 are **excluded** from the recording (no columns) |
| Signer ID | Default = the anonymized `participantId` from Settings (FR-13); if blank → generated `anon-XXXX`. Never a real name. |
| Take | Each Start press increments `take_id` within the session (new session → 1) |
| Consent gate | Recording requires `consentGiven == true` (NFR-8). Keep that gate unchanged. |
| Label | Free-text/selectable label per take (e.g. `A`, `KUMUSTA`). Take cannot start with an empty label. |
| Both gloves | If both gloves are connected, record both; each hand has its own session/files. |

### 5.2 CSV (one file per session)

Header (the `*_thumb` columns exist **only if** the session's valid mask has bit0 set, and are placed first within each group):

```
timestamp_ms,session_id,signer_id,hand,calibration_id,label,take_id,
raw_thumb,raw_pointer,raw_middle,raw_ring,raw_pinky,
ohm_thumb,ohm_pointer,ohm_middle,ohm_ring,ohm_pinky,
ang_thumb,ang_pointer,ang_middle,ang_ring,ang_pinky,
roll,pitch,yaw,quality_flag
```

(Written on one line in the file. Any finger with valid bit = 0 loses its three columns.)

- `raw_*` = ADC from telemetry; `ohm_*` / `ang_*` = **recomputed** by §3 from raw + the session's CAL_INFO.
- `roll/pitch/yaw` in degrees (telemetry ÷ 10). `quality_flag` = telemetry byte 28.
- RFC-4180 quoting; reuse `lib/core/utils/csv_exporter.dart`.
- `hand` column: `L` / `R`.

### 5.3 Sidecar JSON (one per session)

```json
{
  "session_id": "S-...",
  "signer_id": "anon-XXXX",
  "hand": "L",
  "calibration_id": 3,
  "sample_rate_hz": 5,
  "firmware_version": "1.2.0",
  "recorded_at": "ISO-8601",
  "rows": 240,
  "dropped_frames": 2,
  "dropped": { "adcRail": 1, "seqGap": 1 },
  "r_div": [10000, 10000, 10000, 10000, 10000],
  "fingers": {
    "thumb":   { "valid": true, "weak": false, "flat_ohm": 0, "bent90_ohm": 0,
                 "flat_adc": 0, "bent90_adc": 0, "span_counts": 0 },
    "pointer": {}, "middle": {}, "ring": {}, "pinky": {}
  }
}
```

All values come from the mirrored CAL_INFO. `fingers.*` includes invalid fingers
(with `valid:false`) so the sidecar documents *why* columns are missing.

### 5.4 File names and storage

`talkhimik_<L|R>_<session_id>_cal<calibration_id>.csv` and `..._sidecar.json`.

- Buffer rows in memory **and** append to a file in the app-support directory as
  they are recorded (so a crash/disconnect does not lose a take).
- Export = share sheet / save to a user-visible location on Android. On web/Windows
  without a path provider the export fails gracefully (same `UnsupportedError`
  convention as D §10).
- Sessions list (newest first): hand, signer, calibration_id, rows, dropped, size, [Share] [Delete].

---

## 6. Sensor values + hand animation (O1 + O2)

### 6.1 Live screen — route `/live` (new)

Layout (per hand; two hands side by side on wide screens, tabbed L/R on phones):

| Element | Source | Notes |
|---|---|---|
| **Hand view** (animated) | telemetry angles + IMU | §6.2 |
| Finger angle bars ×5 | telemetry `flex[i]` | 0–90°, numeric label; invalid finger = hatched/dimmed; weak = amber |
| Raw ADC ×5 (collapsible "Details") | telemetry `raw[i]` | also show recomputed Ω from §3 |
| Roll / Pitch / Yaw tiles | telemetry ÷ 10, 1 decimal, `°` | |
| **Zero yaw** button | COMMAND 0x06 | yaw is gyro-only and drifts (no magnetometer) |
| Calibration chip | `calibration_id` + "Uncalibrated" if `flags.bit0` | taps → calibration wizard / summary |
| Connection badges | derived | **freshness** (ms since last frame; stale > 500 ms), **packet loss %** (from seq gaps, rolling), **update rate** (frames/s) |
| Battery | STATUS | show "—" when `0xFF` |
| Vibrate test | COMMAND 0x08 | optional, small |
| Record button | → `/collect` | shows active session state |

Add entry points: a "Live" action on Home and in navigation. Existing Home content is unchanged.

### 6.2 Hand animation spec (CustomPainter)

> The original SVG hands live in `talkhimik-ble/web/index.html`, which was **not**
> provided with this spec. The behavior below is derived from its documented
> behavior (SVG hands, left mirrored, per-finger bend, IMU tilt). If the exact
> look matters, attach that file and port its geometry; otherwise implement as follows.

- One `HandPainter extends CustomPainter` driven by `HandPose { List<double> fingerDeg(5), roll, pitch, yaw, handedness, invalid mask }`.
- Palm = rounded shape; each finger = **3 segments** (proximal, middle, distal) hinged at the palm. Distribute the 0–90° input across joints (suggested 40 % / 40 % / 20 % of the total flexion; thumb has 2 segments and rotates across the palm).
- **Left hand = right hand mirrored** (`canvas.scale(-1, 1)`), same painter.
- Tilt: apply roll/pitch as a perspective-ish skew/rotation of the whole hand; yaw as in-plane rotation. Clamp so the hand never leaves the canvas.
- Smoothing: data arrives at ~20 Hz; animate toward the target at 60 fps with a simple low-pass (e.g. `v += (target − v) × 0.35` per tick, or an `AnimationController`/`Ticker`). Do not call `setState` per packet — use `Listenable`/`ValueNotifier` + `RepaintBoundary`.
- Visual states: **invalid finger** → outline only/grey with ✗; **uncalibrated** → whole hand desaturated + "Uncalibrated" label; **stale/disconnected** → hand frozen at 40 % opacity.
- Pure rendering: no business logic in the painter. Give it plain values.

---

## 7. Flutter mapping

### 7.1 Concept → implementation

| Concept (stack-independent) | Flutter implementation |
|---|---|
| Sense/Acquire/Edge | firmware — untouched |
| Transport (4 channels) | `flutter_blue_plus` via existing `GloveConnection` — extended to 2 hands (§7.3) |
| Host state | Riverpod `Notifier`s; one `HandState` per hand |
| Calibration store | glove NVS (authoritative) + CalInfo cache (Hive/prefs) |
| Dashboard SVG hands | `CustomPainter` |
| Dataset files | `path_provider` app-support dir + share sheet |
| Simulate toggle | existing **MockGloveConnection**, extended (§9 Phase 6) |
| Threshold classifier (optional) | `lib/domain/classifier/` pure Dart |

### 7.2 Files — add / replace / keep

Layer rule is unchanged: **ui → application → domain ← data**.

| Action | Path | Notes |
|---|---|---|
| **ADD** | `lib/domain/sensing/sensor_math.dart` | §3 functions, pure Dart, no Flutter imports |
| **ADD** | `lib/domain/models/hand_state.dart` | latest telemetry, status, calInfo, health counters for one hand |
| **ADD** | `lib/domain/models/calibration_table.dart` | typed view over `CalInfoPacket` (per-finger records) |
| **ADD** | `lib/domain/models/dataset_session.dart`, `dataset_row.dart` | |
| **ADD** | `lib/data/storage/calinfo_cache.dart` | replaces calibration profile store |
| **ADD** | `lib/data/dataset/dataset_file_writer.dart` | CSV/sidecar writer (uses `csv_exporter.dart`) |
| **ADD** | `lib/application/live_controller.dart` | exposes `HandState` per hand, health metrics (freshness/loss/rate) |
| **ADD** | `lib/application/dataset_recorder_controller.dart` | §5 engine |
| **ADD** | `lib/ui/screens/live_screen.dart`, `lib/ui/widgets/hand_view.dart`, `finger_bar.dart`, `imu_tiles.dart`, `connection_badges.dart` | §6 |
| **REPLACE** | `lib/application/calibration_controller.dart` | §4 state machine |
| **REPLACE** | `lib/ui/screens/calibration_screen.dart` | wizard UI |
| **REPLACE** | `lib/application/data_collection_controller.dart` → thin facade over `dataset_recorder_controller.dart` (or delete and repoint) | |
| **REPLACE** | `lib/ui/screens/collect_screen.dart` | recorder UI + sessions list |
| **REMOVE** | `calibration_store.dart` / `SharedPrefsCalibrationProfileStore` usage | superseded by `calinfo_cache.dart` |
| **EXTEND** | `lib/application/providers.dart` | register new providers (still the single composition root) |
| **EXTEND** | `lib/app.dart` | add `/live` route |
| **EXTEND** | `lib/core/strings/app_strings.dart` | all new copy |
| **KEEP** | everything in §1.2 | |

### 7.3 Multi-glove connection model (required by O1–O4)

The dashboard talks to **two gloves at once** (one connection per hand). D describes a single
`GloveConnection` / `GloveController`. Required end state:

- A connection **per hand** (`L` and `R`), each with its own phase, auto-reconnect backoff (D §6 policy), and `HandState`.
- Provider shape (suggested): `gloveControllerProvider.family<Hand>` or a `GlovesController` holding `Map<Hand, GloveController>`.
- Scanning: still unfiltered + prefix match; the prefix **decides the hand** (`TALKHIMIK-L` → left). A glove whose telemetry `hand` byte disagrees with its name → trust the telemetry byte, show a warning.
- The home-screen status bar (FR-12) shows the aggregate (both ready / one ready / none) without changing its current single-glove look when only one is connected.
- The transcript path (mock-driven today) is unaffected; it keeps using whatever it uses now.

> **Unknown until the repo is inspected:** how much of this already exists. Phase 0 must
> answer it before any code is written (§9).

### 7.4 Core Dart sketch (reference, not mandatory)

```dart
// lib/domain/sensing/sensor_math.dart
const adcMax = 4095;

double adcToOhms(double rDiv, int adc) {
  if (adc <= 0) return double.maxFinite;
  if (adc >= adcMax) return 0.0;
  return rDiv * (adcMax - adc) / adc;
}

double ohmsToAngle(double r, double flat, double bent90) {
  final span = bent90 - flat;
  if (span == 0) return 0.0;
  return (90 * (r - flat) / span).clamp(0.0, 90.0).toDouble();
}

/// Wrap-safe: frames missed between two sequence numbers.
int seqGap(int last, int now) => (now - last - 1) & 0xFFFF;
```

Decoding rule: use `ByteData.sublistView(bytes)` with `Endian.little` for every
multi-byte field, including `getFloat32`. Reject wrong-length frames (do not throw into the UI).

---

## 8. Conflict resolution table

| # | Topic | App doc (D) says | Glove system says | **Decision** |
|---|---|---|---|---|
| 1 | Where the calibration profile lives | per-user JSON in shared_preferences (FR-8) | glove NVS + CAL_INFO, versioned by id | **Glove NVS.** App mirrors CAL_INFO only (§4.5). |
| 2 | Calibration flow | app sends START/CANCEL, wizard steps "not yet driven" | 10-step wizard driven by STATUS.step | **Wizard per §4.** |
| 3 | Raw stream contract for FR-9 | open item (labeled streams vs. labeled results) | labeled **streams**, 5 Hz from telemetry | **Labeled streams (§5).** Closes D §11 open item 2. |
| 4 | Recording & calibration | not versioned | one session per (hand, calibration_id) | **Versioned (§5.1).** |
| 5 | Telemetry display | decoded, not shown | dashboard visualizer | **New `/live` screen (§6).** |
| 6 | Reconnect policy | 1, 2, 4, 8 s, cap 30 s, indefinite | 0.5–8 s, 5 attempts | **D's policy.** Keep area. |
| 7 | Number of gloves | one connection | two (L + R) | **Two (§7.3).** |
| 8 | Platform | Flutter (Android primary) | Web Bluetooth / Chrome | **Flutter.** Web Bluetooth dashboard remains as the dev tool; it is not ported. |
| 9 | "Android app: Kotlin/Java" in architecture doc (C §6.2) | Flutter/Dart | — | **D wins** (stale text in C). |
| 10 | iOS "out of scope" (C §3.3) | iOS folders exist, unsupported | — | **Unsupported; no iOS work.** |
| 11 | Classifier | label packet from glove (planned) | phone-side 10-class threshold rules | **Optional Phase 7**; never replaces the label-packet path. |
| 12 | Event CSV vs dataset CSV | FR-16 event export | dataset CSV | **Two separate exports, two schemas.** |
| 13 | Battery | status bar shows battery | glove always sends `0xFF` | Show "—" for `0xFF`. Not a bug. |
| 14 | IMU yaw | — | gyro-only, drifts | Provide Zero-yaw; label yaw as "relative". |

---

## 9. Implementation phases

Every phase ends with `flutter analyze` clean and `flutter test` green. Do not start
the next phase on a red tree. Commit per phase.

| Phase | Name | Output |
|---|---|---|
| **0** | **Recon (read-only)** | Report: (a) how `GloveConnection`/`GloveController` handle multiple gloves today; (b) whether existing codecs match §2 byte-for-byte; (c) current shape of `GloveState`; (d) how `export_controller`/`csv_exporter` write & share files; (e) mock glove capabilities; (f) any dependency missing (share sheet). **No code changes.** |
| **1** | Sensor core | `sensor_math.dart`, `hand_state`, `calibration_table`, codec fixes if Phase 0 found drift; golden-vector tests (§11) |
| **2** | Two-glove model | per-hand connection/controller/state; status bar aggregate; reconnect tests per hand |
| **3** | Live screen + hand animation | `/live`, `HandPainter`, finger bars, IMU tiles, badges, zero-yaw; widget tests |
| **4** | Calibration wizard | §4 controller + screen; `calinfo_cache`; remove old profile store; tests with `FakeGloveConnection` scripting STATUS/CAL_INFO |
| **5** | Dataset recorder | §5 engine, writer, `/collect` screen, sessions list, share/export; tests |
| **6** | Mock parity | `MockGloveConnection` emulates: 29 B telemetry with moving fingers/IMU, STATUS wizard progression (steps 1→10, errors 3 and 4 on demand), CAL_INFO with incrementing id, periodic loss burst (~every 7 s), per hand. Integration test covering calibrate → record → export on the mock. |
| **7** *(optional)* | Phone-side classifier | 10-class rules + 20-sample ring, majority ≥ 10, as a debug overlay on `/live`; **not** wired into the transcript. |
| **8** | Docs | Update `TALKHIMIK_App_System.md` (§3 layout, §4 feature map FR-8/FR-9, §8 screens, §11 open items) to match what was built. |

### Definition of done

- [ ] On a real Android phone with a real glove: connect L, see the hand move, run the 10-step wizard, see `calibration_id` increment, record a labeled take, export CSV + sidecar, and the CSV re-derives to the same ohm/angle values from raw + sidecar.
- [ ] Both gloves connected simultaneously, independently calibrated and recorded.
- [ ] Changing calibration mid-recording closes the session and starts a new file (no mixed-calibration file ever produced).
- [ ] Everything in §1.2 behaves exactly as before; existing tests unchanged and green.
- [ ] The app works with **zero connectivity** (concept C6): no network calls added.
- [ ] Mock glove demonstrates every state above on Windows/web without hardware.

---

## 10. Concept checklist (do not lose these in the port)

| ID | Idea | Where enforced |
|---|---|---|
| C1 | divider → ohms → two-point linear angle, per user | §3 |
| C2 | calibration is versioned data with quality gates | §4 |
| C3 | every sample provably tied to its calibration; drops counted | §5 |
| C4 | sensing / edge / host separation; byte-level contract only | §2, §7 |
| C5 | gated output: "unrecognized" beats wrong; exclude faulty fingers, don't guess | §4.3, §5.1 |
| C6 | edge-first, no cloud dependency | §9 DoD |

---

## 11. Test plan

**Unit**

- `sensor_math`: all golden vectors in §3; `seqGap` wrap (`last=65535, now=0 → 0`; `last=10, now=14 → 3`; `last=10, now=15 → 4`).
- Codecs, with hand-built byte arrays:
  - TELEMETRY: hand=1, seq=0x0102, flex=[0,10,20,30,90], roll×10=−1234, raw=[4095,0,1365,2048,100], cal_id=3, quality=0b101101 → each field decodes; length 28 → rejected.
  - CAL_INFO: floats LE; version bytes `1.2.0\0\0\0` → "1.2.0".
  - STATUS: battery `0xFF` → unknown.
- Wizard: step→(finger, phase) mapping for 1…10; error 3 keeps the step; error 4 advances; cancel keeps prior id; completion detection by id increase.
- Recorder: (a) cal_id change closes + opens a new session; (b) `cal_id == 0` blocks recording; (c) adc 0/4095 on a valid finger drops, on an invalid finger does not; (d) seq gap 4 drops, 3 keeps; (e) invalid thumb → no thumb columns; (f) take_id increments; (g) consent off → blocked; (h) CSV header and sidecar match §5.2/§5.3 exactly.

**Widget:** Live screen renders both hands from a fake stream; freshness goes stale; uncalibrated chip; calibration wizard prompts per step; collect screen disabled states.

**Integration:** mock glove end-to-end — calibrate → `calibration_id` bumps → record → stop → files exist and re-derive.

**Hardware (staged, per D's `ble-integration-checklist.md`):** nRF Connect read of all four characteristics first, then app on Android.

---

## 12. Assumptions & open questions

1. **Flutter source was not available** when this spec was written; only docs. File names in §7.2 come from D's layout. Phase 0 reconciles any differences — adapt names, keep responsibilities.
2. `index.html` (dashboard) was not provided → hand geometry in §6.2 is specified, not ported. Attach it if pixel-faithful hands are wanted.
3. Share-sheet/save dependency (`share_plus` or equivalent) may need adding; confirm against existing export implementation in Phase 0.
4. Whether both gloves can be held simultaneously by the phone's BLE stack (most Android 8+ devices: yes, typically ≥ 4 connections) — verify on the realme test phone.
5. Dataset label vocabulary: free-text vs. picker from the FSL vocabulary table (`domain/vocab/`). Default: picker with a free-text fallback.
6. Retention/privacy of dataset files on the phone (DR-4 anonymity): files contain only the anonymous signer id; no names, no device identifiers.
