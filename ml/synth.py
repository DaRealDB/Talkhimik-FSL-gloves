"""Synthetic dataset generator (C3.7): clustered fake angles per letter in
the C2 export format (CSV + sidecar), so the whole pipeline is verifiable
without real data.

Cluster centers follow the C1 threshold rules; noise is +/-3 deg angles,
+/-5 deg roll/pitch. The REST cluster sits in a rule-free region so it
never collides with a letter class.
"""

import json
import os

import numpy as np

FINGERS = ["thumb", "pointer", "middle", "ring", "pinky"]

CLUSTERS = {
    "A":  [55, 72, 72, 72, 72],   # FIST
    "B":  [75, 12, 12, 12, 12],
    "F":  [20, 12, 12, 12, 12],
    "D":  [60, 12, 72, 72, 72],   # D-G-L
    "V":  [75, 12, 12, 72, 72],
    "U":  [20, 12, 12, 72, 72],   # U-K-P
    "W":  [35, 12, 12, 12, 65],
    "I":  [75, 72, 72, 72, 12],
    "Y":  [12, 72, 72, 72, 12],
    "C":  [40, 40, 40, 40, 40],
    "_rest": [10, 45, 10, 10, 10],  # matches no rule (see train docs)
}

ANGLE_NOISE = 3.0
RP_NOISE = 5.0
ROWS_PER_TAKE = 40


def _sidecar(session_id, signer, hand, cal_id, rows, valid_mask=0x1F):
    return {
        "session_id": session_id,
        "signer_id": signer,
        "hand": hand,
        "calibration_id": cal_id,
        "sample_rate_hz": 5,
        "firmware_version": "1.2.0",
        "recorded_at": "2026-11-01T00:00:00.000",
        "rows": rows,
        "dropped_frames": 0,
        "dropped": {"adcRail": 0, "seqGap": 0},
        "r_div": [10000.0] * 5,
        "fingers": {
            f: {"valid": bool(valid_mask & (1 << i)), "weak": False,
                "flat_ohm": 10000.0, "bent90_ohm": 30000.0,
                "flat_adc": 500, "bent90_adc": 1500, "span_counts": 1000}
            for i, f in enumerate(FINGERS)
        },
    }


def _csv_lines(session_id, signer, hand, cal_id, label, take_id,
               rows, rp, bad_every=0, rng=None):
    """Rows for one take (fixed header written by the caller)."""
    lines = []
    for i, (r, (roll, pitch)) in enumerate(zip(rows, rp)):
        quality = 0x1F
        if bad_every and rng is not None and i % bad_every == 0:
            quality = 0x1E  # pinky bit cleared -> loader must drop it
        raw = [int(np.clip(a, 0, 90) / 90 * 4095) for a in r]
        ohm = ["%.2f" % (10000.0 * (4095 - a) / max(a, 1)) for a in raw]
        fields = ([str(1000 + i * 200), session_id, signer, hand,
                   str(cal_id), label, str(take_id)]
                  + [str(a) for a in raw] + ohm
                  + ["%.2f" % a for a in r]
                  + ["%.1f" % roll, "%.1f" % pitch, "0.0",
                     str(quality)])
        lines.append(",".join(fields))
    return lines


def _header():
    return (["timestamp_ms", "session_id", "signer_id", "hand",
             "calibration_id", "label", "take_id"]
            + [f"raw_{f}" for f in FINGERS]
            + [f"ohm_{f}" for f in FINGERS]
            + [f"ang_{f}" for f in FINGERS]
            + ["roll", "pitch", "yaw", "quality_flag"])


def generate(out_dir, signers=("P-001", "P-002"), seed=7,
             sessions_per_label=2, takes_per_session=2,
             hands=("L", "R"), bad_row_every=0):
    """Writes C2-format CSV+sidecar pairs under out_dir. Returns the dir."""
    os.makedirs(out_dir, exist_ok=True)
    rng = np.random.default_rng(seed)
    header_line = ",".join(_header())
    for signer in signers:
        for label, center in CLUSTERS.items():
            center = np.array(center, dtype=float)
            for s in range(sessions_per_label):
                hand = hands[s % len(hands)]
                cal_id = 3 + (0 if hand == "L" else 4)
                session_id = f"S-{signer}-{label}-{s}"
                lines = [header_line]
                row_count = 0
                for t in range(takes_per_session):
                    take = np.clip(
                        rng.normal(center, ANGLE_NOISE,
                                   (ROWS_PER_TAKE, 5)),
                        0, 90)
                    rp = rng.uniform(-RP_NOISE, RP_NOISE,
                                     (ROWS_PER_TAKE, 2))
                    lines += _csv_lines(session_id, signer, hand, cal_id,
                                        label, t + 1, take, rp,
                                        bad_every=bad_row_every, rng=rng)
                    row_count += len(take)
                base = f"talkhimik_{hand}_{session_id}_cal{cal_id}"
                with open(os.path.join(out_dir, base + ".csv"), "w",
                          encoding="utf-8") as f:
                    f.write("\r\n".join(lines) + "\r\n")
                with open(os.path.join(out_dir,
                                       base + "_sidecar.json"), "w",
                          encoding="utf-8") as f:
                    json.dump(_sidecar(session_id, signer, hand, cal_id,
                                       row_count), f, indent=2)
    return out_dir
