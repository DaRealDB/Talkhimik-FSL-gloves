<!--
  TALKHIMIK — Consolidated Thesis Reference
  Derived from (Desktop/thesis sep4/):
    - TALKHIMIK_System_Architecture.md — thesis-level architecture (the "what & why")
    - TALKHIMIK_Code_Reference.md     — as-built firmware + web dashboard (the "what runs today")
  Companion documents in this repo:
    - TALKHIMIK_App_System.md          — the Flutter companion app (production link)
    - ble-integration-checklist.md     — staged glove ↔ app verification
  Where documents disagree, the Code Reference describes the code; items the
  thesis does not specify are marked [PROPOSED].
-->

# TALKHIMIK — Consolidated Thesis Reference

**"FSL Smart Glove Bridging Silent Gestures to Spoken Filipino Words"**

| | |
|---|---|
| **Team** | Daryl D. Bacusmo · Dewey Raven S. Cabahug · Sheena Patricia Kaye Caneja · Joppy B. Vargas |
| **Adviser** | Engr. Nikko D. Alferez |
| **Institution** | Cebu Institute of Technology University — College of Engineering and Architecture |

**Current stage:** two Seeed XIAO ESP32S3 BLE gloves (5 flex sensors +
MPU-6050/6500 each) streaming to a single-file Web Bluetooth dashboard.
No Wi-Fi, no MQTT, no Android app, no on-glove TFLM yet — those are later
phases (§6.1).

---

## 1. Project Overview

Talkhimik is a wearable Filipino Sign Language (FSL) smart glove that
translates silent hand gestures into spoken Filipino/English words in real
time. Sensor data is classified on-glove by a quantized TensorFlow Lite Micro
neural network on the ESP32-S3, and the recognized sign is delivered over BLE
to an Android app that displays the text and speaks it through TTS.

**Key numbers**

- Vocabulary: complete 28-letter FSL manual alphabet + curated high-frequency
  phrases (educational & healthcare contexts)
- Sensing: 10 flex sensors (5 per glove) + 2 MPU-6050 IMUs; current prototype:
  2 BLE gloves × 5 sensors + IMU (§4)
- Processing: ESP32-S3 on-glove — acquisition + TFLM inference, no external
  processor
- Wireless: BLE 5.0 LE end to end; no cloud dependency
- Output: Filipino/English text + synthesized speech, per-prediction
  confidence badge
- Budget: ₱ 7,640 (§6.2)
- Legal alignment: Republic Act No. 11106 (Filipino Sign Language Act)

## 2. High-Level Architecture

Three layers — hardware (sensing + feedback), firmware (on-glove acquisition
+ TFLM inference), software (companion app) — linked by one BLE link to the
phone plus a Web Bluetooth telemetry link to the development dashboard.

```
┌──────────────────────────────────────────────────────────┐
│  SOFTWARE LAYER — Android App (production) / Dashboard   │
│                                                          │
│  BLE GATT Client → Packet Validation → UI Display        │
│                                  (Filipino text +        │
│                                   confidence badge)      │
│  Text-to-Speech Engine → spoken Filipino / English       │
│  Session History Log → Session Summary & Export          │
│  Web dashboard (dev): Web Bluetooth → live hands + telemetry │
└──────────────────────────▲───────────────────────────────┘
                           │ BLE 5.0 LE: label + confidence
                           │ + timestamp (production)
                           │ BLE: telemetry + commands (dev)
┌──────────────────────────┴───────────────────────────────┐
│  FIRMWARE LAYER — ESP32-S3 on the glove                  │
│                                                          │
│  Boot Init → BLE Stack → Load Calibration (NVS flash)    │
│                                                          │
│  Polling Loop:                                           │
│   ADC + I²C Acquisition → Sliding Window Buffer          │
│      → TFLM Inference (INT8) → Label + Confidence        │
│   Confidence ≥ Threshold? ─yes→ Dispatch BLE Packet      │
│                          └no→ Discard & Re-poll          │
│                                                          │
│  Feedback Control: LED indicators + vibration motor      │
└──────────────────────────▲───────────────────────────────┘
                           │ analog + I²C (on-board)
┌──────────────────────────┴───────────────────────────────┐
│  HARDWARE LAYER — Talkhimik Smart Glove (×2 hands)       │
│                                                          │
│  5× Flex Sensors (finger bends) → 12-bit SAR ADC         │
│  MPU-6050 IMU (wrist orientation/motion) → I²C           │
│                                                          │
│  Power: LiPo battery → onboard regulator                 │
│  Feedback: 2× LED indicators, 1× vibration motor         │
└──────────────────────────────────────────────────────────┘
```

**End-to-end pipeline**

```
Gesture Input → Sensor Acquisition → ML Classification → BLE Transmission → App Output → TTS Speech
```

## 3. Feature Set

| # | Feature | Description |
|---|---------|-------------|
| F1 | FSL gesture capture | 5 flex sensors per glove + wrist IMU capture handshape and motion |
| F2 | Real-time classification | Quantized TFLM model on the glove's own ESP32-S3 — no external PC, cloud, or Pi |
| F3 | 28-letter FSL alphabet | Full Filipino Sign Language manual alphabet |
| F4 | Phrase recognition | Curated high-frequency phrases for education and healthcare |
| F5 | Text output | Filipino text + confidence badge |
| F6 | Speech synthesis | TTS speaks the recognized sign in Filipino/English |
| F7 | Wireless link | Single BLE hop: glove → app (production) · glove → web dashboard (dev) |
| F8 | Per-user calibration | Per-finger flat/90° baselines, spans, R_DIV, validity mask, calibration_id |
| F9 | Confidence gating | Below-threshold predictions reported as "unrecognized" |
| F10 | Session history | Every translation logged; sessions end with summary + export |
| F11 | Portable power | LiPo battery, wearable and untethered |
| F12 | Edge privacy | All processing on local devices — no cloud round-trip |

**Out of scope:** Non-Manual Signals; vocabulary beyond alphabet + phrase
set; continuous/rapid stylized signing; iOS; offline buffering during BLE
disconnects.

---

## 4. Current Prototype Stage (as built) — BLE Gloves

Two **Seeed XIAO ESP32S3** gloves (`talkhimik-ble/`), one per hand, each with
5 flex sensors and an MPU-6050/6500 IMU, streaming over BLE to the web
dashboard (Web Bluetooth API, Chrome/Edge). Earlier stages (pointer + thumb
over MQTT, 4-finger USB-serial glove) are superseded.

### 4.1 Hardware & Wiring

| Finger | XIAO pin | GPIO | ADC channel |
|--------|----------|------|-------------|
| Thumb | D0 | 1 | ADC1_CH0 |
| Pointer | D1 | 2 | ADC1_CH1 |
| Middle | D3 | 4 | ADC1_CH3 |
| Ring | D8 | 7 | ADC1_CH6 |
| Pinky | D9 | 8 | ADC1_CH7 |

- IMU on I²C: SDA D4 (GPIO5), SCL D5 (GPIO6). Status LED onboard GPIO21
  (active-low). Vibration motor D10 (GPIO9) via PWM → 47 kΩ → NPN base +
  flyback diode.
- All flex pins on **ADC1** (ADC2 is unusable while the BLE radio is on;
  D2/GPIO3 is a strapping pin and is avoided).
- Per-finger **10 kΩ voltage divider** (3.3 V → sensor → ADC pin → R_DIV →
  GND); `R_DIV[]` in `config.h` holds 10000 per channel and is the **one
  place** to edit divider values — it feeds the ohms math, the boot log, and
  the NVS calibration signature (changing it invalidates the saved
  calibration).
- Battery sensing disabled (the XIAO's VBAT divider is on ADC2) → STATUS
  battery = `0xFF` unknown.

### 4.2 Firmware (`talkhimik-ble/firmware/glove-esp32/`)

Arduino sketch (C/C++), NimBLE-Arduino 2.x + MPU6050_light. Board:
`XIAO_ESP32S3`, **OPI PSRAM**, USB CDC On Boot disabled. Per-hand flashing via
`HAND_DEFAULT 0/1` in `config.h`, or COMMAND `0x07 SET_HAND` (NVS, name
updates on reboot). Serial 115200 is debug-only.

| File | Responsibility |
|---|---|
| `config.h` | ALL pins, UUIDs, packet layouts, timing, enums — single source of truth |
| `glove-esp32.ino` | setup/loop, packet builders, command handling, LED/motor |
| `flex.h/.cpp` | ADC reads (settle → average 8 samples), `R = R_DIV × (4095 − adc) / adc` |
| `imu.h/.cpp` | MPU-6050/6500 roll/pitch/yaw via MPU6050_light; yaw is gyro-only (drifts) |
| `calibration.h/.cpp` | flat/90° state machine + quality checks + NVS + CAL_INFO |
| `ble_link.h/.cpp` | NimBLE GATT server (TELEMETRY/STATUS/CAL_INFO/COMMAND) |

**Loop scheduler** — fully `millis()`-based, no `delay()`:

| Task | Cadence |
|---|---|
| command queue drain (`blePopCommand` + `applyCommand`) | every loop |
| `imuUpdate()` | 10 ms (≥100 Hz) |
| one flex channel (round-robin) | 10 ms → full 5-finger scan ≈ 50 ms |
| `sendTelemetry()` | 50 ms (COMMAND 0x05 overrides, clamp 20–1000) |
| `sendStatus()` | 250 ms |
| `ledUpdate()` / `motorUpdate()` | every loop (blink while advertising, solid on connect; PWM 180/255 while `motorUntilMs`) |

### 4.3 Calibration (firmware)

State machine driven by COMMAND writes from the dashboard wizard:

```
START → step 1 (thumb, waiting FLAT) → CAPTURE_FLAT → step 2 (thumb, waiting 90)
      → CAPTURE_90 → step 3 (pointer, FLAT) → … → step 10 (pinky 90)
      → CAPTURE_90 → quality-gate → save to NVS → mode streaming, step 0
```

Quality checks (thresholds at the top of `calibration.cpp`):

| Check | Rule | Action |
|---|---|---|
| Resistance range | flat or 90° outside **1 kΩ–100 kΩ** | finger invalid (excluded from recordings), STATUS error 4 |
| 5% span | 90° within **5%** of flat | capture rejected — wizard stays for a redo, STATUS error 3 |
| Span counts | `|bent90_adc − flat_adc|` < **100 counts** | accepted with a warning (weak mask bit) |

Angle map is linear and works whether resistance rises or falls with bend:
`a = clamp(90 × (R − flat) / (bent90 − flat), 0, 90)`.
`calibrationLoad()` rejects a stored profile when its `R_DIV` differs from
the current `R_DIV` by > 1 Ω per channel (forces recalibration) or when keys
are missing. Uncalibrated gloves stream placeholder angles flagged by a
STATUS bit.

**NVS layout** (Preferences namespace `talkhimik`):

| Key | Type | Meaning |
|---|---|---|
| `hand` | u8 | 0 = L, 1 = R (SET_HAND override; wins at boot) |
| `flat_<finger>` / `bend_<finger>` | float | flat / 90° resistance (ohms) |
| `flata_<finger>` / `benda_<finger>` | u16 | raw ADC at flat / 90° |
| `span_<finger>` | u16 | `|bent90_adc − flat_adc|` |
| `rdiv_<finger>` | float | R_DIV used at capture (signature) |
| `cal_id` | u32 | calibration id — bumps on every saved calibration |
| `valid` | u8 | bitmask, bit0..4 = finger passed quality checks |

### 4.4 BLE GATT Contract (firmware ↔ dashboard)

> ✅ The Flutter app's GATT contract (`TALKHIMIK_App_System.md` §5) is
> aligned to these exact UUIDs, packet layouts, and opcodes — app and
> dashboard speak the same glove. The one unresolved app-side contract is
> the production label packet (SRS Table III-2), which arrives with the
> on-glove TFLM stage.

| Characteristic | UUID | Properties |
|---|---|---|
| Service | `d84f9c2e-6b1a-4e57-9f3d-2a8c7e5b1f04` | — |
| TELEMETRY | `7a3e1b9c-2d4f-48a6-b7e2-5c9d0f8a3b61` | read + notify |
| COMMAND | `3f8d2a6b-9c4e-4d7f-a1e3-6b5c8d0e2f49` | write + write-without-response |
| STATUS | `c2b6e8d4-1a7f-4c3e-9d5b-0f2a6e8c4d73` | read + notify |
| CAL_INFO | `a1f2c3d4-5e6f-4a7b-8c9d-0e1f2a3b4c5d` | read + notify |

Device name `TALKHIMIK-L` / `TALKHIMIK-R`; MTU 247; one central per glove;
advertising restarts automatically after disconnect.

**TELEMETRY — notify, 29 bytes, little-endian, every 50 ms**

| Offset | Type | Field |
|---|---|---|
| 0 | u8 | hand (0 = left, 1 = right) |
| 1–2 | u16 | seq (wraps; dashboard detects gaps) |
| 3–7 | u8 ×5 | flex angles 0–90°, order thumb…pinky |
| 8–9 / 10–11 / 12–13 | i16 ×3 | roll / pitch / yaw ×10 |
| 14–23 | u16 ×5 | raw 12-bit ADC, same finger order |
| 24–27 | u32 | calibration_id (0 = never calibrated) |
| 28 | u8 | quality (bit0..4 = finger valid, bit5 = any weak span) |

**STATUS — notify, 5 bytes, every 250 ms**

| Offset | Type | Field |
|---|---|---|
| 0 | u8 | mode (0 = streaming, 1 = calibrating) |
| 1 | u8 | calibration step (0 idle; 1–10 = thumb-flat … pinky-90) |
| 2 | u8 | battery % (0xFF = unknown) |
| 3 | u8 | flags (bit0 = uncalibrated, placeholder angles in use) |
| 4 | u8 | error: 0 none · 1 capture while not calibrating · 2 unknown command · 3 90° within 5% of flat (redo) · 4 resistance outside 1k..100k (finger fault) |

**COMMAND — write / write-no-response: u8 opcode + optional payload**

| Opcode | Name | Payload |
|---|---|---|
| 0x01 | START_CALIBRATION | — |
| 0x02 | CAPTURE_FLAT | — |
| 0x03 | CAPTURE_90 | — (auto-advances) |
| 0x04 | CANCEL_CALIBRATION | — |
| 0x05 | SET_RATE | u16 LE ms (clamped 20–1000) |
| 0x06 | ZERO_YAW | — |
| 0x07 | SET_HAND | u8 (0 = L, 1 = R; NVS, name updates on reboot) |
| 0x08 | VIBRATE | u16 LE ms |

**CAL_INFO — read + notify, 104 bytes** (pushed after every calibration
save; stored for READ even while disconnected)

| Offset | Type | Field |
|---|---|---|
| 0 | u8 | valid mask (bit0..4 = finger passed quality checks) |
| 1 | u8 | weak mask (bit0..4 = span < 100 counts) |
| 2–5 | u32 | calibration_id |
| 6–25 | float ×5 | flat_ohm (thumb..pinky) |
| 26–45 | float ×5 | bent90_ohm |
| 46–55 | u16 ×5 | flat_adc |
| 56–65 | u16 ×5 | bent90_adc |
| 66–85 | float ×5 | R_DIV (values used for this profile) |
| 86–95 | u16 ×5 | span_counts |
| 96–103 | u8 ×8 | firmware version (ASCII, zero-padded; currently `1.2.0`) |

### 4.5 Dashboard (`talkhimik-ble/web/index.html`)

One self-contained file, no build step, no dependencies: `CONFIG`/`PKT`
mirrors of `config.h` (`SEQ_GAP_MAX = 3`); per-hand state (`newHand()`);
`ingestTelemetry`/`ingestStatus`/`parseCalInfo`; connect with device chooser
(namePrefix filter) + auto-reconnect (0.5 s..8 s exponential backoff, 5
attempts); SVG hand rendering + angle bars + roll/pitch/yaw tiles + zero-yaw
button; editable gesture classifier; calibration wizard (COMMAND + STATUS);
calibration-aware dataset recorder; simulate toggle (`fakePacket` + demo loss
burst).

### 4.6 Prototype Gesture Classifier (dashboard)

With all five finger angles, the 28-letter FSL alphabet collapses into ten
separable threshold classes (0–90° per finger, editable JSON, majority vote
over a 20-sample ring):

| Class | Rule (thumb / pointer / middle / ring / pinky) | FSL letters |
|-------|-----------------------------------------------|-------------|
| FIST | 45 / 65 / 65 / 65 / 65 min | A · E · O · S · M · N · T · X |
| B | thumb ≥ 65, fingers < 25 | B |
| F | all < 45/25/25/25/25 | F |
| D-G-L | thumb ≥ 45, pointer < 25, rest ≥ 65 | D · G · L |
| V | thumb ≥ 65, pointer + middle < 25, rest ≥ 65 | V |
| U-K-P | thumb < 45, pointer + middle < 25, rest ≥ 65 | U · H · K · P · R |
| W | thumb < 65, pointer + middle + ring < 25, pinky ≥ 45 | W |
| I | thumb ≥ 65, pinky < 25, rest ≥ 65 | I |
| Y | thumb < 25, pinky < 25, rest ≥ 65 | Y |
| C | all in 25–65 | C |

Letters differing only in thumb abduction/orientation (U·H·K·P·R, D·G·L) and
dynamic letters (J, Z — need the IMU trajectory) still merge; the client-side
classifier is temporary until the on-glove TFLM model replaces it.

### 4.7 Dataset Recorder Contract

- Samples every **200 ms (5 Hz)** per connected glove.
- **One session per (hand, calibration_id)** — `ensureSession()` closes and
  restarts on a calId change, so files never mix calibrations.
- **Frame drop rules** (counted per session, live, written to the sidecar):
  raw ADC 0 or 4095 on any valid finger (`adcRail`); seq gap > 3 (`seqGap`).
- **Signer ID** — anonymous free text, auto `anon-XXXX` when blank.
- **Take** — each Start press increments `take_id` within the session.

**CSV columns:** `timestamp_ms, session_id, signer_id, hand, calibration_id,
label, take_id, raw_pointer…raw_pinky, ohm_pointer…ohm_pinky,
ang_pointer…ang_pinky, roll, pitch, yaw, quality_flag` — thumb columns
inserted only when the thumb passes the quality check. `ohm`/`ang` are
computed dashboard-side from raw ADC + the session's CAL_INFO.

**Sidecar JSON** (one per session): session/signer/hand/cal_id,
`sample_rate_hz`, `firmware_version`, `recorded_at`, `rows`,
`dropped_frames`, per-finger `{valid, weak, flat_ohm, bent90_ohm, flat_adc,
bent90_adc, span_counts}`, `r_div`.

File names: `talkhimik_<L|R>_<session_id>_cal<cal_id>.csv` /
`..._sidecar.json`.

### 4.8 End-to-End Data Flow (current)

```
flex sensors ──ADC1──► flexReadAdc (×8 avg) ──► adcToResistance ──► mapResistanceToAngle
MPU-6050 ────I2C────► imuUpdate (100 Hz) ──► roll/pitch/yaw
                                        │
        TELEMETRY 29 B (50 ms): angles + raw ADC + cal_id + quality
        STATUS      5 B (250 ms): mode/step/battery/flags/error
        CAL_INFO  104 B (on change): full calibration table
                                        │  BLE (NimBLE ↔ Web Bluetooth)
                                        ▼
        dashboard: visualizer · classifier · calibration wizard · dataset recorder
                                        │
                                        ▼
        CSV per (hand, calibration_id) session + sidecar JSON
```

---

## 5. Planned Stages

### 5.1 On-Glove TFLM Inference (firmware, Phase 3–4)

```
loop:
    samples[0..4] = adc_read(flex_sensor[0..4])   # 12-bit SAR ADC
    imu_data      = i2c_read(mpu6050)
    window.append(normalize(samples, imu_data, profile))
    features = extract_features(window)
    label, confidence = tflm_model(features)      # quantized INT8

    if confidence >= THRESHOLD:
        feedback(success)                          # LED + vibration
        ble_send(label, confidence, timestamp)     # → Android app
    else:
        discard()                                  # no false outputs
```

The Recognition Confidence Threshold is a project-defined constant; below it
the system reports "unrecognized". The `.tflite` model ships with the
firmware and is updated by re-flashing (OTA updates are future work).

### 5.2 Software Layer — Companion App

The production link (glove → phone) is the Flutter app in this repository —
see [`TALKHIMIK_App_System.md`](TALKHIMIK_App_System.md) for the as-built
documentation (GATT client, packet validation, transcript + TTS, session
logging/export, calibration, Record mode). The thesis's Kotlin/Java app
module description is superseded by this Flutter implementation. The
production recognition packet is *[PROPOSED]*:

```json
{ "label": "KUMUSTA", "confidence": 0.94, "ts_ms": 1725460000123, "model": "lstm_v2" }
```

### 5.3 Machine Learning Pipeline

- **Dataset** — Talkhimik Gesture Dataset: raw flex (ADC + ohm + angle) and
  IMU time-series, every sample tied to its calibration profile (session_id,
  anonymous signer_id, calibration_id, take_id, quality_flag), sidecar JSON
  per session, rail/gap frames dropped and counted.
- **Preprocessing** — per-user calibration normalization (linear
  resistance→angle map), sliding window, time-series feature extraction.
- **Models** — MLP for static handshapes; 1D CNN and/or LSTM for
  motion/phrase-level signs. Related-work baselines: camera-ANN ≈ 87.5%
  (FSL subset), CyberGlove+HMM ≈ 96.5%, glove+LSTM ≈ 93.51% (20 ASL words).
- **Deployment** — PyTorch (PC) → ONNX → TensorFlow Lite → INT8 quantization
  (few hundred KB; ~1–2% accuracy cost) → flash with firmware.
- **Metrics** — accuracy, precision, recall, F1, confusion matrix;
  cross-user validation phase to address generalization.

---

## 6. Implementation Plan

### 6.1 Phases (thesis Gantt, §2.3.2)

| Phase | Window | Tasks |
|-------|--------|-------|
| 3 — Hardware Development | Jun–Sep 2026 | Glove fabrication & sensor mounting · ESP32 firmware & BLE setup · Circuit integration & power management · Hardware prototype ready · Hardware unit testing |
| 4 — ML & Software *(parallel)* | Jun–Sep 2026 | FSL data collection & labeling · Model training · Companion app development · TTS integration · ML model deployed |
| 5 — Integration & Testing | Sep–Nov 2026 | System integration · User testing with FSL community · Calibration & accuracy evaluation · System evaluation complete |
| 6 — Final Documentation & Defense | Sep 2026–Jan 2027 | Chapter 3 (Results & Analysis) · Chapter 4 (Conclusion) · Full documentation & revisions · Final manuscript submission · Final defense (Nov 2026) |

### 6.2 Budget

| Material/Resource | Qty | Cost (₱) |
|---|---|---|
| Flex sensors | 10 | 6,000 |
| MPU-6050 / MPU-9250 IMU | 2 | 300 |
| ESP32-S3 | 2 | 600 |
| LiPo battery | 1 | 250 |
| Vibration motor | 1 | 80 |
| LED indicators | 2 | 10 |
| Wearable glove base | 1 | 200 |
| Jumper wires / connectors | 1 set | 150 |
| Resistors / passive components | 1 set | 50 |
| **Total** | | **₱ 7,640** |

### 6.3 Repository Layout *[PROPOSED]*

```
talkhimik/
├── talkhimik-ble/              # current stage: BLE gloves + Web Bluetooth dashboard
│   ├── firmware/glove-esp32/   # XIAO ESP32S3: ADC + I²C + NimBLE GATT server
│   ├── web/index.html          # dashboard: telemetry, wizard, recorder
│   └── README.md               # wiring, packet formats, build steps
├── ml/
│   ├── data/                   # Talkhimik Gesture Dataset (labeled, anonymized)
│   ├── train/                  # PyTorch training & evaluation scripts
│   └── models/                 # .pth → ONNX → .tflite (quantized)
├── app/                        # companion app (this Flutter repo)
└── docs/                       # test protocols, calibration guide, data sheets
```

---

## 7. Testing & Evaluation Strategy

| Test | Focus | Key outputs |
|------|-------|-------------|
| Unit (§2.7.1) | Sensors, BLE, app, TTS in isolation | Pass/fail per component |
| Integration (§2.7.2) | Sensor→TFLM→BLE→App→TTS cohesion | Packet loss, sync errors, delays |
| Functional (§2.7.3) | Requirements in Table 2.6 | Met / partially met / not met |
| Non-functional (§2.7.4) | Accuracy, latency, calibration stability, reliability, usability, battery | Accuracy %, ms latency, drift %, runtime hours |
| ML evaluation (§2.7.5) | Model quality on held-out data | Accuracy, precision, recall, F1, confusion matrix, cross-user |
| UAT (§2.7.6) | 5-point Likert: ease, comfort, responsiveness, accuracy, satisfaction | Mean scores per criterion |
| System (§2.7.7) | Full end-to-end pipeline in classroom/clinic simulations | Trial success rate |
| Stress (§2.7.8) | Prolonged operation, repeated signs, long BLE sessions | Overheating, degradation, stability |

Target metrics are recorded in Chapter 3 (Results & Analysis) once data
gathering is complete.

---

## 8. Known Limitations & Risks

| Limitation (§1.4) | Risk | Mitigation / Status |
|---|---|---|
| No Non-Manual Signals | Simplified translations | Documented scope; future work (§9) |
| Fixed vocabulary | Signs outside set unrecognized | Curated alphabet + phrases for target settings |
| Flex-sensor drift / hysteresis, IMU bias | Accuracy decay over time | Per-user calibration profiles; recalibration interval from stability testing |
| Battery-limited runtime | Interruptions | LiPo + onboard regulator; battery test in §2.7.4 |
| BLE dependency, no offline buffering | Lost translation on disconnect | Documented error mode; future work (§9) |
| Android only | No iOS coverage | Future work (§9) |
| Small training population | Cross-user generalization | Cross-user validation phase + calibration (§3.5.3) |
| Rapid/continuous signing | Lower accuracy | Out of scope; LSTM as future direction |
| INT8 quantization | ~1–2% accuracy cost | Accepted trade for on-glove inference; quantified in §3.5.1 |

---

## 9. Future Work / Roadmap

1. **Non-Manual Signals** (facial expression, head tracking) for fuller
   translations
2. **Expand vocabulary** and support continuous signing (LSTM/sequential
   decoding)
3. Grow the **training dataset** (more signers) for cross-user generalization
4. Upgrade **sensors** to reduce drift (calibration-free bend sensors,
   additional axes)
5. **Offline buffering + automatic BLE reconnection**
6. **iOS / cross-platform** companion app
7. **Over-the-air (OTA) model updates** — retrain and redeploy the on-glove
   TFLite model without re-flashing firmware
8. **Deployment studies** in partner schools/hospitals with certified FSL
   interpreters

---

## 10. Document Map

| Document | Covers | Relation |
|---|---|---|
| `TALKHIMIK_App_System.md` (this repo) | Flutter companion app — as built | Production software layer |
| `ble-integration-checklist.md` (this repo) | Staged glove ↔ app verification, open contract items | Gate between §4 and the app |
| `TALKHIMIK_Code_Reference.md` (thesis folder) | Firmware + dashboard, file-by-file | Source for §4 |
| `TALKHIMIK_System_Architecture.md` (thesis folder) | Thesis-level architecture | Source for §1–3, §5–9 |
| `talkhimik-ble/README.md` | Wiring, packet contract, build steps | Firmware quickstart |

**Mapping to the thesis document**

| This document | Thesis section |
|---------------|----------------|
| §1 Overview | Abstract, §1.1–1.2 |
| §2 High-Level Architecture | §2.1 System Architecture, §2.2 Block Diagram |
| §3 Feature Set | §2.1.3, §2.6.3, Fig 2.6.1–2.6.3 |
| §4 Current Prototype (as built) | §2.4 Prototype Design, §2.5 Circuit Design, §1.5.2 |
| §5.1 On-Glove TFLM | §2.1.2, §2.6 flowcharts, §1.5.4 |
| §5.3 ML Pipeline | §1.5.3, §2.7.5, §1.7 |
| §6 Implementation Plan | §2.3 Project Management |
| §7 Testing & Evaluation | §2.7 Testing and Data Gathering |
| §8 Limitations & Risks | §1.4 Scopes and Limitations |
| §9 Future Work | §4.3 Recommendations for Future Work |
