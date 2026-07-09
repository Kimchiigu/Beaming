import torch
import warnings
warnings.filterwarnings("ignore")
import coremltools as ct
from speechbrain.inference.speaker import EncoderClassifier

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
sb_fbank = classifier.mods["compute_features"]
sb_embed = classifier.mods["embedding_model"]

class CoreMLFbank(torch.nn.Module):
    def __init__(self, sb_fbank, sb_embed):
        super().__init__()
        # Precompute constants
        self.register_buffer("window", sb_fbank.compute_STFT.window.clone())
        
        # sb_fbank.compute_fbanks.filter_shape? Let's just use the output of a dummy pass to grab the matrix!
        dummy = torch.randn(1, 16000)
        stft = sb_fbank.compute_STFT(dummy)
        # stft is [batch, time, freq, 2] usually
        power = sb_fbank.compute_STFT.power(stft)
        # Let's get the mel matrix by inspecting the fbanks module
        # It's usually self.compute_fbanks.fbanks or something similar.
        # But wait, speechbrain.lobes.features.Filterbank doesn't expose it easily?
        
        # Let's dynamically create the Mel matrix by doing an impulse response!
        # A one-hot power spectrum for each frequency bin!
        n_freqs = power.shape[-1]
        n_mels = sb_fbank.compute_fbanks.n_mels
        mel_matrix = torch.zeros(n_freqs, n_mels)
        for i in range(n_freqs):
            impulse = torch.zeros(1, 1, n_freqs)
            impulse[0, 0, i] = 1.0
            mel = sb_fbank.compute_fbanks(impulse) # [1, 1, n_mels]
            mel_matrix[i, :] = mel[0, 0, :]
            
        self.register_buffer("mel_matrix", mel_matrix)
        
        self.n_fft = sb_fbank.compute_STFT.n_fft
        self.hop_length = sb_fbank.compute_STFT.hop_length
        self.win_length = sb_fbank.compute_STFT.win_length
        self.embed = sb_embed
        
    def forward(self, wavs):
        # STFT
        # CoreML requires complex STFT to be manually computed or uses built-in if supported.
        # Let's try torch.stft
        stft_complex = torch.stft(
            wavs,
            n_fft=self.n_fft,
            hop_length=self.hop_length,
            win_length=self.win_length,
            window=self.window,
            center=False, # SpeechBrain uses False by default if not specified? Wait, let's check.
            pad_mode="constant",
            return_complex=True
        )
        # Power
        power = torch.abs(stft_complex) ** 2
        power = power.transpose(1, 2)
        
        # Mel
        mel = torch.matmul(power, self.mel_matrix)
        log_mel = torch.log(mel + 1e-14)
        
        # CMVN
        mean = torch.mean(log_mel, dim=1, keepdim=True)
        norm_mel = log_mel - mean
        
        # Embed
        return self.embed(norm_mel, torch.ones(wavs.shape[0]))

model = CoreMLFbank(sb_fbank, sb_embed).eval()
example_wav = torch.randn(1, 16000 * 3)

traced = torch.jit.trace(model, example_wav)
mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="audioSamples", shape=(1, 48000), dtype=float)],
    outputs=[ct.TensorType(name="embedding")],
    minimum_deployment_target=ct.target.iOS17,
)
print("SUCCESS!")
mlmodel.save("SpeakerEncoderFull.mlpackage")
