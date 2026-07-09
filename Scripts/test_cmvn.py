import warnings
warnings.filterwarnings("ignore")
from speechbrain.inference.speaker import EncoderClassifier

classifier = EncoderClassifier.from_hparams(source="speechbrain/spkrec-ecapa-voxceleb", run_opts={"device": "cpu"})
print("std_norm =", classifier.mods["mean_var_norm"].std_norm)
print("norm_type =", classifier.mods["mean_var_norm"].norm_type)

fbank = classifier.mods["compute_features"]
print("n_fft =", fbank.compute_STFT.n_fft)
print("win_length =", fbank.compute_STFT.win_length)
print("hop_length =", fbank.compute_STFT.hop_length)
print("n_mels =", fbank.compute_fbanks.n_mels)
