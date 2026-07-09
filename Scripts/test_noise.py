import torch
import warnings
warnings.filterwarnings("ignore")
from speechbrain.inference.speaker import EncoderClassifier
import torch.nn.functional as F

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})

def get_embed(feats):
    feats = classifier.mods.mean_var_norm(feats, torch.ones(1))
    emb = classifier.mods.embedding_model(feats, torch.ones(1))
    return F.normalize(emb.squeeze(), p=2, dim=0)

# Feed zeros
zeros = torch.zeros(1, 300, 80)
emb_zeros = get_embed(zeros)

# Feed noise
noise1 = torch.randn(1, 300, 80)
emb_noise1 = get_embed(noise1)

noise2 = torch.randn(1, 300, 80)
emb_noise2 = get_embed(noise2)

print("Cosine(Zeros, Zeros):", F.cosine_similarity(emb_zeros, emb_zeros, dim=0).item())
print("Cosine(Zeros, Noise1):", F.cosine_similarity(emb_zeros, emb_noise1, dim=0).item())
print("Cosine(Noise1, Noise2):", F.cosine_similarity(emb_noise1, emb_noise2, dim=0).item())
