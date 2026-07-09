import torch
import warnings
warnings.filterwarnings("ignore")
import numpy as np
from speechbrain.inference.speaker import EncoderClassifier

# 1. Load SpeechBrain
classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
fbank = classifier.mods["compute_features"]
cmvn = classifier.mods["mean_var_norm"]
embed = classifier.mods["embedding_model"]

# Generate a random "speech-like" waveform
wav = torch.randn(1, 16000 * 3) # 3 seconds of noise

# 2. Get SpeechBrain's exact features
sb_feats = fbank(wav)
sb_feats_norm = cmvn(sb_feats, torch.ones(1))
sb_emb = embed(sb_feats_norm, torch.ones(1)).squeeze()
import torch.nn.functional as F
sb_emb = F.normalize(sb_emb, p=2, dim=0)

print(f"SpeechBrain features shape: {sb_feats.shape}")
print(f"SpeechBrain feats min/max: {sb_feats.min().item():.3f} / {sb_feats.max().item():.3f}")

# 3. Simulate Swift's vDSP logic
# nFFT = 512, win = 400, hop = 160
import librosa
mel_basis = librosa.filters.mel(sr=16000, n_fft=512, n_mels=80, fmin=0.0, fmax=8000.0, htk=True, norm=None)

# In Swift, the window is a Hamming window of 400, padded to 512.
window = np.zeros(512)
hamm = np.hamming(400) # vDSP_hamm_window is similar to np.hamming
window[56:456] = hamm

# We will apply this window manually to framing.
wav_np = wav.squeeze().numpy()
frames = []
for start in range(0, len(wav_np) - 512 + 1, 160):
    frame = wav_np[start:start+512] * window
    # FFT
    sp = np.fft.rfft(frame)
    # Power
    power = np.abs(sp)**2
    frames.append(power)
power_frames = np.stack(frames) # [time, 257]

# Mel
mel_energies = np.dot(power_frames, mel_basis.T) # [time, 80]

# Log compression
log_mel = np.log(np.maximum(mel_energies, 1e-10))

# CMVN (Mean only)
swift_feats = log_mel - np.mean(log_mel, axis=0, keepdims=True)

swift_tensor = torch.tensor(swift_feats).unsqueeze(0).float()
print(f"Swift features shape: {swift_tensor.shape}")
print(f"Swift feats min/max: {swift_tensor.min().item():.3f} / {swift_tensor.max().item():.3f}")

swift_emb = embed(swift_tensor, torch.ones(1)).squeeze()
swift_emb = F.normalize(swift_emb, p=2, dim=0)

sim = F.cosine_similarity(sb_emb, swift_emb, dim=0)
print(f"Cosine Similarity between SpeechBrain Pipeline and Swift Pipeline: {sim.item():.4f}")
