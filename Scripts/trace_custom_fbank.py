import torch
import warnings
warnings.filterwarnings("ignore")
import coremltools as ct
from speechbrain.inference.speaker import EncoderClassifier

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
sb_fbank = classifier.mods["compute_features"]
sb_cmvn = classifier.mods["mean_var_norm"]
sb_embed = classifier.mods["embedding_model"]

class CustomFbank(torch.nn.Module):
    def __init__(self, sb_fbank, sb_cmvn, sb_embed):
        super().__init__()
        # Precompute window
        self.register_buffer("window", sb_fbank.compute_STFT.window)
        # Precompute mel matrix
        self.register_buffer("mel_basis", sb_fbank.compute_fbanks.fbanks)
        self.n_fft = sb_fbank.compute_STFT.n_fft
        self.hop_length = sb_fbank.compute_STFT.hop_length
        self.win_length = sb_fbank.compute_STFT.win_length
        
        self.embed = sb_embed
        
    def forward(self, wavs):
        # wavs: [batch, time]
        # 1. STFT
        stft = torch.stft(
            wavs,
            n_fft=self.n_fft,
            hop_length=self.hop_length,
            win_length=self.win_length,
            window=self.window,
            center=True,
            pad_mode="reflect",
            normalized=False,
            onesided=True,
            return_complex=True
        )
        # 2. Power
        power = torch.abs(stft) ** 2
        # Transpose to [batch, time, freq]
        power = power.transpose(1, 2)
        # 3. Mel
        mel = torch.matmul(power, self.mel_basis)
        log_mel = torch.log(mel + 1e-14)
        
        # 4. CMVN (mean only over time)
        mean = torch.mean(log_mel, dim=1, keepdim=True)
        feats = log_mel - mean
        
        # 5. Embed
        emb = self.embed(feats, torch.ones(wavs.shape[0]))
        return emb

custom_pipeline = CustomFbank(sb_fbank, sb_cmvn, sb_embed).eval()
example_wav = torch.randn(1, 16000 * 3)

# Test outputs match
orig_feats = sb_fbank(example_wav)
orig_feats = sb_cmvn(orig_feats, torch.ones(1))
orig_emb = sb_embed(orig_feats, torch.ones(1))

cust_emb = custom_pipeline(example_wav)
diff = (orig_emb - cust_emb).abs().max().item()
print(f"Difference between original and custom pipeline: {diff}")

# Trace
traced = torch.jit.trace(custom_pipeline, example_wav)

mlmodel = ct.convert(
    traced,
    inputs=[
        ct.TensorType(
            name="audioSamples",
            shape=(1, 48000), # 3 seconds
            dtype=float,
        )
    ],
    outputs=[ct.TensorType(name="embedding")],
    minimum_deployment_target=ct.target.iOS17,
)
print("Conversion successful!")
mlmodel.save("SpeakerEncoderFull.mlpackage")
