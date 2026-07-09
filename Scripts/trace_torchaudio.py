import torch
import warnings
warnings.filterwarnings("ignore")
import torchaudio
import coremltools as ct
from speechbrain.inference.speaker import EncoderClassifier

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
sb_embed = classifier.mods["embedding_model"]

class EndToEndModel(torch.nn.Module):
    def __init__(self, embed):
        super().__init__()
        # Use torchaudio MelSpectrogram which is easily traced
        self.mel = torchaudio.transforms.MelSpectrogram(
            sample_rate=16000,
            n_fft=400,
            win_length=400,
            hop_length=160,
            f_min=0.0,
            f_max=8000.0,
            n_mels=80,
            window_fn=torch.hamming_window,
            normalized=False,
            center=False
        )
        self.embed = embed
        
    def forward(self, wavs):
        # 1. Mel
        mel = self.mel(wavs) # [batch, n_mels, time]
        mel = mel.transpose(1, 2) # [batch, time, n_mels]
        log_mel = torch.log(mel + 1e-14)
        
        # 2. CMVN (mean only)
        mean = torch.mean(log_mel, dim=1, keepdim=True)
        norm_mel = log_mel - mean
        
        # 3. Embed
        # embed_model expects [batch, time, n_mels]
        return self.embed(norm_mel, torch.ones(wavs.shape[0]))

model = EndToEndModel(sb_embed).eval()
example_wav = torch.randn(1, 48000)

traced = torch.jit.trace(model, example_wav)
mlmodel = ct.convert(
    traced,
    inputs=[ct.TensorType(name="audioSamples", shape=(1, 48000), dtype=float)],
    outputs=[ct.TensorType(name="embedding")],
    minimum_deployment_target=ct.target.iOS17,
)
print("SUCCESS!")
mlmodel.save("SpeakerEncoderFull.mlpackage")
