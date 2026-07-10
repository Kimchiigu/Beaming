import torch
import warnings
warnings.filterwarnings("ignore")
from speechbrain.inference.speaker import EncoderClassifier

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
sb_fbank = classifier.mods["compute_features"]

# 1. Extract Window (400 samples)
window = sb_fbank.compute_STFT.window.numpy().tolist()

# 2. Extract Mel Filterbank (201 x 80) -> We need 257 x 80 if we use 512 FFT
# Wait! If SpeechBrain uses n_fft=400, the STFT output has 400/2 + 1 = 201 bins.
# In Swift, nFFT=512, so STFT output has 257 bins.
# How do we map PyTorch's 201 bins to Swift's 257 bins?
# If we feed 400 samples zero-padded to 512 into an FFT, the frequency resolution changes!
# 400-point FFT bins: k * Fs / 400
# 512-point FFT bins: k * Fs / 512
# We CANNOT easily use PyTorch's exact 201x80 matrix on a 512-point FFT output!
print("Wait, n_fft mismatch makes it hard to use exact matrix.")
