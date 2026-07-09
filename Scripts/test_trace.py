import torch
import warnings
warnings.filterwarnings("ignore")
from speechbrain.inference.speaker import EncoderClassifier
classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
encoder = classifier.mods["embedding_model"].eval()
example_input = torch.zeros(1, 300, 80)
try:
    traced = torch.jit.trace(encoder, example_input)
    print("Trace successful!")
except Exception as e:
    print(f"Trace failed: {e}")
