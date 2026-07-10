import torch
import warnings
warnings.filterwarnings("ignore")
import coremltools as ct
from speechbrain.inference.speaker import EncoderClassifier

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})

class FullPipeline(torch.nn.Module):
    def __init__(self, classifier):
        super().__init__()
        self.compute_features = classifier.mods["compute_features"]
        self.mean_var_norm = classifier.mods["mean_var_norm"]
        self.embedding_model = classifier.mods["embedding_model"]
        
    def forward(self, wavs):
        # wavs: [batch, time]
        feats = self.compute_features(wavs)
        # Note: we drop wav_lens for tracing, assume full length
        feats = self.mean_var_norm(feats, torch.ones(wavs.shape[0]))
        embeddings = self.embedding_model(feats, torch.ones(wavs.shape[0]))
        return embeddings

pipeline = FullPipeline(classifier).eval()
example_wav = torch.zeros(1, 48000)  # 3 seconds at 16kHz

try:
    traced = torch.jit.trace(pipeline, example_wav)
    print("Full pipeline trace successful!")
except Exception as e:
    print(f"Full pipeline trace failed: {e}")
