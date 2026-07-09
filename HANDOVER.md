# Beaming - Speaker Verification Handover

## 1. The End Goal
The core objective of the **Beaming** app is to provide visual feedback (flashlight) indicating *who* is currently speaking during a meeting. 

**The specific use-case and constraint:**
If two users (e.g., Axel and Christo) are sitting very close to each other in a meeting room, and Axel speaks, **only Axel's phone should light up**. Christo's phone must recognize that the voice it hears does *not* belong to Christo, and keep its flashlight off.

## 2. The Current Approach (Hybrid System)
Because sitting closely together means both phones will pick up the same audio volume, a simple Mic Sensitivity (RMS) threshold is not enough. We implemented a **Hybrid Approach**:
1. **VAD (Voice Activity Detection):** Uses RMS volume to detect *if* a sound is occurring.
2. **Speaker Verification (CoreML):** Uses an AI model to determine *whose* voice it is.

We are currently using the **ECAPA-TDNN** model (trained on VoxCeleb by SpeechBrain). The model takes a Log-Mel Spectrogram and outputs a 192-dimensional vector (embedding) representing a unique "voice fingerprint."

### Calibration & Live Flow
1. **Calibration:** The user speaks for 3.5 seconds. `AudioManager` passes the raw PCM buffers to `SpeakerVerificationManager`. The app computes the Log-Mel Spectrogram, runs it through the CoreML model, and saves the resulting 192-d embedding to `UserDefaults` as the enrolled profile.
2. **Live Meeting:** When `AudioManager` detects sound above the RMS threshold, it gates the audio into a 1.5s sliding window (`verificationPCM`). This window is repeatedly processed by CoreML. The resulting live embedding is compared to the enrolled profile using **Cosine Similarity**. If the similarity is above the threshold (e.g., `0.70`), it triggers `claimSpeaker()` and the flashlight turns on.

## 3. Why the Current Approach is Failing
The ECAPA-TDNN model fundamentally works, but the current implementation suffers from **Feature Drift** between the iOS environment and the PyTorch training environment, leading to false positives and threshold collapse.

1. **The Feature Mismatch:** The PyTorch model expects highly specific Kaldi-like `Fbank` features (400-point STFT, Hamming window, exact Mel filterbank matrix, mean-only normalization). In iOS, we compute this manually using Apple's `vDSP` (Accelerate framework), which forces a 512-point FFT grid and slightly different math.
2. **Embedding Space Collapse:** Because the features passed to the CoreML model are slightly out-of-distribution (compared to the VoxCeleb training data), the model treats the audio as noisy/distorted. In ECAPA-TDNN, distorted inputs map to a default, origin-biased cluster. 
3. **Threshold Failure:** Because both Axel's voice and Christo's voice are slightly distorted by the iOS feature extractor, the model outputs embeddings for both of them that are very similar to each other. Both speakers end up scoring around `0.60 - 0.70` similarity against the enrolled profile. This makes it mathematically impossible to set a reliable threshold that accepts Axel but rejects Christo.

## 4. Key Files to Check

- **`Beaming/ViewModel/SpeakerVerificationManager.swift`**
  - *Purpose:* The heart of the problem. This file contains the manual `vDSP` math (`computeLogMelSpectrogram`) and the CoreML `MLModel` inference.
  - *Look here for:* The sliding window logic, the VAD gating (`processAudioBuffer`), the cyclic frame repetition to handle 1.5s vs 3.0s window mismatches, and the Cosine Similarity calculation.
  
- **`Beaming/ViewModel/MeetingViewModel.swift`**
  - *Purpose:* Manages the meeting state.
  - *Look here for:* How `startCalibration()` is triggered, and how `audioManager.onSpeakingStateChanged` uses `speakerVerificationManager.isMyVoice` to gate the `claimSpeaker()` function (the flashlight).
  
- **`Beaming/ViewModel/AudioManager.swift`**
  - *Purpose:* Handles raw microphone input via `AVAudioEngine`.
  - *Look here for:* The RMS calculation and the continuous buffer callback (`onAudioBufferCaptured`) that feeds the verification manager.

- **`Scripts/convert_speaker_model.py`**
  - *Purpose:* The Python script used to download the SpeechBrain ECAPA-TDNN model and convert it to `SpeakerEncoder.mlpackage` using `coremltools`.

## 5. Recommendations for the Next Approach
To achieve the end goal, the next developer should abandon the manual `vDSP` feature extraction and try one of the following approaches:

1. **End-to-End CoreML Model:** Create a new Python conversion script that wraps the raw audio feature extraction (`torchaudio.transforms.MelSpectrogram`) **inside** the PyTorch model before converting it to CoreML. This allows the iOS app to pass raw `[Float]` audio directly into CoreML, ensuring the model computes its own features exactly as it expects.
2. **Wav2Vec2 / HuBERT:** Switch to a different speaker recognition model that accepts raw waveforms by default (skipping spectrograms entirely).
3. **Apple's Built-in Speech APIs:** Investigate if `SFSpeechRecognizer` or the new iOS 17/18 `SoundAnalysis` updates provide any undocumented speaker-diarization/identification flags that could replace the custom CoreML model entirely.
