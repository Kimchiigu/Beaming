import torchaudio
import warnings
warnings.filterwarnings("ignore")
import urllib.request
import os

url = "https://raw.githubusercontent.com/speechbrain/speechbrain/develop/samples/audio_samples/example1.wav"
urllib.request.urlretrieve(url, "example1.wav")

from speechbrain.dataio.dataio import read_audio
sig = read_audio("example1.wav")
print("Max absolute value:", sig.abs().max().item())
