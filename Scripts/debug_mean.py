import torch
import warnings
warnings.filterwarnings("ignore")
from speechbrain.inference.speaker import EncoderClassifier
classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
fbank = classifier.mods["compute_features"]
cmvn = classifier.mods["mean_var_norm"]
wav = torch.randn(1, 16000 * 3)
sb_feats = fbank(wav)
sb_feats_norm = cmvn(sb_feats, torch.ones(1))
print("Mean of sb_feats:", sb_feats.mean().item())
print("Mean of sb_feats_norm:", sb_feats_norm.mean().item())
