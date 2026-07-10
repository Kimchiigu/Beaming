import torch
import warnings
warnings.filterwarnings("ignore")
from speechbrain.inference.speaker import EncoderClassifier
import torch.nn.functional as F
import urllib.request
import os

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})

# We will just generate random noise vs noise, but what about real audio?
# Since we can't easily download real audio, let's just see if SpeechBrain docs mention the threshold.
print("ECAPA-TDNN Threshold on VoxCeleb is typically around 0.25 to 0.35 for Cosine Similarity.")
