import warnings
warnings.filterwarnings("ignore")
from speechbrain.inference.speaker import EncoderClassifier

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
fbank = classifier.mods["compute_features"]
print("f_min =", fbank.compute_fbanks.f_min)
print("f_max =", fbank.compute_fbanks.f_max)
