#!/usr/bin/env python3
"""
convert_speaker_model.py
Beaming — CoreML Speaker Verification Model Conversion

Converts the pre-trained ECAPA-TDNN speaker encoder from SpeechBrain
(speechbrain/spkrec-ecapa-voxceleb, trained on VoxCeleb2) to a CoreML
package that Xcode can bundle directly.

Output:  SpeakerEncoder.mlpackage
         → Drop this into Xcode > your target membership.

CoreML interface produced:
  Input  "audioFeatures"  float32 [1, 80, 300]
  Output "embedding"      float32 [192]

Requirements (run once in a Python 3.10+ venv):
  pip install speechbrain torch torchaudio coremltools

Usage:
  python3 Scripts/convert_speaker_model.py
  # Then drag the generated SpeakerEncoder.mlpackage into Xcode.
"""

import os
import torch
import coremltools as ct
from speechbrain.pretrained import EncoderClassifier

# ── 1. Load pre-trained SpeechBrain ECAPA-TDNN ──────────────────────────────
import warnings
warnings.filterwarnings("ignore")
from speechbrain.inference.speaker import EncoderClassifier

print("Downloading speechbrain/spkrec-ecapa-voxceleb …")
classifier = EncoderClassifier.from_hparams(
    source="speechbrain/spkrec-ecapa-voxceleb",
    savedir="tmp_speechbrain_model",
    run_opts={"device": "cpu"},
)
encoder = classifier.mods["embedding_model"].eval()

# ── 2. Trace the encoder ─────────────────────────────────────────────────────
# Input: log-mel spectrogram [batch=1, time_frames=300, mel_bins=80]
# ECAPA-TDNN expects shape [batch, time, features] → [1, 300, 80]
example_input = torch.zeros(1, 300, 80)

print("Tracing encoder with torch.jit.trace …")
with torch.no_grad():
    traced = torch.jit.trace(encoder, example_input)

# ── 3. Convert to CoreML ─────────────────────────────────────────────────────
print("Converting to CoreML …")
mlmodel = ct.convert(
    traced,
    inputs=[
        ct.TensorType(
            name="audioFeatures",
            shape=(1, 300, 80),
            dtype=float,
        )
    ],
    outputs=[ct.TensorType(name="embedding")],
    minimum_deployment_target=ct.target.iOS17,
    compute_precision=ct.precision.FLOAT16,   # fp16 — faster Neural Engine
    compute_units=ct.ComputeUnit.CPU_AND_NE,
)

# ── 4. Metadata ──────────────────────────────────────────────────────────────
mlmodel.short_description = "ECAPA-TDNN speaker embedding encoder for Beaming"
mlmodel.input_description["audioFeatures"] = (
    "Log-mel spectrogram [1 × 300 frames × 80 mel bins ≈ 3 s @ 16 kHz]"
)
mlmodel.output_description["embedding"] = (
    "L2-normalised 192-d speaker embedding (cosine similarity ready)"
)

# ── 5. Save ──────────────────────────────────────────────────────────────────
out_path = "SpeakerEncoder.mlpackage"
mlmodel.save(out_path)
print(f"\n✅  Saved: {os.path.abspath(out_path)}")
print("\nNext steps:")
print("  1. Open Xcode → drag SpeakerEncoder.mlpackage into the project navigator")
print("  2. Make sure 'Add to targets: Beaming' is checked")
print("  3. Build & run — SpeakerVerificationManager will load the model automatically")
print()
print("Note: The model output dimension is 192 (ECAPA-TDNN default).")
print("If your model outputs a different dimension, update `embeddingDim` in")
print("SpeakerVerificationManager.swift to match.")
