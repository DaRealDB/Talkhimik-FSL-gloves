"""Optional TensorFlow Lite export (C3.6): float32 + full-int8 variants,
rebuilt from weights.json + labels.json.

The training pipeline and the C4 pure-Dart fallback work WITHOUT this
module — it exists only to produce the .tflite artifacts. Requires
`pip install tensorflow`; import errors degrade loudly in train.py.
"""

import csv
import json
import os

import numpy as np

from train import VARIANTS

VALIDATION_INPUTS = 8  # build() call with a few dummy frames


def _build_model(payload):
    import tensorflow as tf

    layers = payload["layers"]
    units = len(payload["input_order"])
    model = tf.keras.Sequential(name="talkhimik_letters")
    for i, layer in enumerate(layers):
        W = np.array(layer["weights"], dtype=np.float32)
        b = np.array(layer["bias"], dtype=np.float32)
        activation = ("softmax" if i == len(layers) - 1 else "relu")
        model.add(tf.keras.layers.Dense(
            W.shape[1], activation=activation, use_bias=True,
            kernel_initializer=tf.keras.initializers.Constant(W),
            bias_initializer=tf.keras.initializers.Constant(b),
            trainable=False, name=f"dense_{i}"))
    # Build the graph; normalization is already baked into layer 1.
    model(tf.zeros((VALIDATION_INPUTS, units), dtype=tf.float32))
    return model


def _representative(clean_csv, variant, count=50):
    cols = VARIANTS[variant]

    def gen():
        i = 0
        with open(clean_csv, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                if i >= count:
                    break
                i += 1
                yield [np.array([float(row[c]) for c in cols],
                                dtype=np.float32)]

    return gen


def export(out_dir, variant, weights_path, labels_path, clean_csv,
           representative_rows=50):
    import tensorflow as tf

    payload = json.load(open(weights_path, encoding="utf-8"))
    model = _build_model(payload)

    # float32 — ship this: the model is tiny, int8 would only cost accuracy.
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_f32 = converter.convert()
    f32_path = os.path.join(out_dir, "talkhimik_letters.tflite")
    with open(f32_path, "wb") as f:
        f.write(tflite_f32)
    print(f"wrote {f32_path} ({len(tflite_f32)} bytes)")

    # int8 — for the future on-glove TFLM stage.
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.representative_dataset = _representative(
        clean_csv, variant, representative_rows)
    tflite_i8 = converter.convert()
    i8_path = os.path.join(out_dir, "talkhimik_letters_int8.tflite")
    with open(i8_path, "wb") as f:
        f.write(tflite_i8)
    print(f"wrote {i8_path} ({len(tflite_i8)} bytes)")
