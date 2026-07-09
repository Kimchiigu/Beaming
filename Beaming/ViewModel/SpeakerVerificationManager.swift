//
//  SpeakerVerificationManager.swift
//  Beaming
//
//  End-to-end CoreML speaker verification.
//
//  During calibration → enrols the user's voice by extracting a speaker
//  embedding from the ECAPA-TDNN CoreML model and persisting it to
//  UserDefaults.
//
//  During the meeting → gates every speaker-claim so a phone only lights
//  up when the LOCAL user's voice is detected (cosine similarity ≥ threshold).
//
//  Required bundle asset: SpeakerEncoderE2E.mlpackage  (or .mlmodelc)
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Input  "waveform"    MLMultiArray [1, 56000]               │
//  │          raw 16 kHz mono PCM (3.5 seconds)                  │
//  │  Output "embedding"   MLMultiArray [1, 1, 192]              │
//  │          L2-normalised speaker embedding                    │
//  └─────────────────────────────────────────────────────────────┘
//  Run Scripts/convert_e2e_speaker_model.py once to generate the model,
//  then drag SpeakerEncoderE2E.mlpackage into Xcode → your target.
//

import Foundation
import CoreML
import Accelerate
import AVFoundation

// ---------------------------------------------------------------------------
// MARK: - SpeakerVerificationManager
// ---------------------------------------------------------------------------

class SpeakerVerificationManager {

    // MARK: - Public State

    /// True once a voice profile is enrolled and ready for comparison.
    private(set) var hasVoiceProfile: Bool = false

    /// Most-recent cosine similarity score (0 … 1). Logged for debugging.
    private(set) var lastSimilarityScore: Float = 0.0

    /// Whether the currently heard voice matches the enrolled profile.
    /// Returns `true` unconditionally when no profile / no model exists (safe fallback).
    var isMyVoice: Bool {
        guard hasVoiceProfile, model != nil else { return true }
        return lastSimilarityScore >= similarityThreshold
    }

    // MARK: - Configuration

    private let targetSampleRate: Double  = 16_000
    /// The model expects exactly this many samples (3.5s @ 16kHz).
    private let modelInputSamples         = 56_000
    private let embeddingDim              = 192
    private let similarityThreshold: Float = 0.70

    /// Minimum RMS energy to consider a buffer as containing speech.
    /// Below this, the buffer is treated as noise/silence and skipped.
    private let noiseGateRMS: Float       = 0.01

    /// Throttle live inference to at most once per this interval.
    private let inferenceIntervalSeconds: Double = 0.5

    /// How many seconds of speech audio to accumulate before running live inference.
    private let liveWindowSeconds: Double = 2.0

    // MARK: - CoreML Model

    private var model: MLModel?

    // MARK: - Enrolled Embedding

    private var enrolledEmbedding: [Float]?
    private let embeddingDefaultsKey = "beaming_voice_embedding_e2e_v2"

    // MARK: - Enrollment Buffers

    private var isEnrolling = false
    private var enrollmentPCM: [Float] = []   // 16 kHz mono accumulation

    // MARK: - Live-Verification Sliding Window

    /// Accumulates only speech-gated audio (RMS > noiseGateRMS).
    private var verificationPCM: [Float] = []
    private var lastInferenceTime: Date = .distantPast
    private var isInferencePending = false

    // MARK: - Background Inference Queue

    private let inferenceQueue = DispatchQueue(
        label: "com.beaming.speakerVerification",
        qos: .userInitiated
    )

    // MARK: - Init

    init() {
        loadModel()
        loadPersistedEmbedding()
    }

    // MARK: - Model Loading

    private func loadModel() {
        // Try the new end-to-end model first, then fall back to old model name
        let candidateNames = ["SpeakerEncoderE2E", "SpeakerEncoder"]
        let candidateExtensions = ["mlmodelc", "mlpackage"]

        for name in candidateNames {
            for ext in candidateExtensions {
                guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { continue }
                do {
                    let cfg = MLModelConfiguration()
                    cfg.computeUnits = .cpuAndNeuralEngine
                    model = try MLModel(contentsOf: url, configuration: cfg)
                    print("[SpeakerVerification] ✅ CoreML model loaded: \(url.lastPathComponent)")
                    return
                } catch {
                    print("[SpeakerVerification] ⚠️ Could not load \(url.lastPathComponent): \(error)")
                }
            }
        }
        print("[SpeakerVerification] ⚠️ No speaker model found in bundle — using RMS-only fallback")
    }

    // -----------------------------------------------------------------------
    // MARK: - Enrollment
    // -----------------------------------------------------------------------

    /// Call when AudioManager.startCalibration() is called.
    func startEnrollment() {
        enrollmentPCM = []
        isEnrolling   = true
        print("[SpeakerVerification] Enrollment started")
    }

    /// Global entry point for all audio buffers. Routes to enrollment or live verification.
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, isSpeaking: Bool) {
        if isEnrolling {
            appendEnrollmentBuffer(buffer)
        } else if isSpeaking {
            processLiveBuffer(buffer)
        }
    }

    /// Feed every raw PCM buffer received during calibration.
    private func appendEnrollmentBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isEnrolling else { return }
        let mono = resampleToMono16k(buffer)
        enrollmentPCM.append(contentsOf: mono)
    }

    /// Call when AudioManager's onCalibrationComplete fires.
    func finishEnrollment() {
        isEnrolling = false
        guard let mdl = model else {
            print("[SpeakerVerification] No model — skipping embedding extraction")
            return
        }

        let minSamples = Int(targetSampleRate * 2.0)
        guard enrollmentPCM.count >= minSamples else {
            print("[SpeakerVerification] ⚠️ Not enough enrollment audio (\(enrollmentPCM.count) samples, need \(minSamples))")
            return
        }

        let samples = enrollmentPCM
        inferenceQueue.async { [weak self] in
            guard let self else { return }

            // Multi-segment enrollment for robustness:
            // Extract 3 overlapping segments and average their embeddings
            let segmentSamples = self.modelInputSamples  // 3.5s worth
            let totalSamples = samples.count
            var embeddings: [[Float]] = []

            if totalSamples >= segmentSamples {
                // We have at least 3.5s — extract up to 3 overlapping segments
                let stride = max(1, (totalSamples - segmentSamples) / 2)
                var offsets = [0]
                if totalSamples > segmentSamples {
                    offsets.append(stride)
                    offsets.append(min(totalSamples - segmentSamples, stride * 2))
                }
                // De-duplicate offsets
                offsets = Array(Set(offsets)).sorted()

                for offset in offsets {
                    let segment = Array(samples[offset ..< offset + segmentSamples])
                    if let emb = self.extractEmbedding(pcmSamples: segment, model: mdl) {
                        embeddings.append(emb)
                        print("[SpeakerVerification] Enrollment segment at offset \(offset): ✅")
                    }
                }
            } else {
                // Less than 3.5s — pad with zeros and use single segment
                var padded = samples
                padded.append(contentsOf: [Float](repeating: 0, count: segmentSamples - totalSamples))
                if let emb = self.extractEmbedding(pcmSamples: padded, model: mdl) {
                    embeddings.append(emb)
                }
            }

            guard !embeddings.isEmpty else {
                print("[SpeakerVerification] ❌ Embedding extraction failed during enrollment")
                return
            }

            // Average all embeddings and L2-normalize
            let averaged = self.averageEmbeddings(embeddings)
            let normalized = self.l2Normalize(averaged)

            DispatchQueue.main.async {
                self.enrolledEmbedding = normalized
                self.hasVoiceProfile   = true
                self.persistEmbedding(normalized)
                print("[SpeakerVerification] ✅ Voice profile enrolled & persisted (\(normalized.count)-d, from \(embeddings.count) segments)")
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - Live Verification
    // -----------------------------------------------------------------------

    /// Call for every live audio buffer during the meeting.
    /// Updates `lastSimilarityScore` and therefore `isMyVoice`.
    private func processLiveBuffer(_ buffer: AVAudioPCMBuffer) {
        guard hasVoiceProfile, let enrolled = enrolledEmbedding, let mdl = model else { return }

        let mono = resampleToMono16k(buffer)

        // ── Noise gate: reject buffers that are mostly noise ──
        let bufferRMS = computeRMS(mono)
        if bufferRMS < noiseGateRMS {
            // This is noise — don't accumulate it
            return
        }

        // Accumulate speech-only audio into sliding window
        verificationPCM.append(contentsOf: mono)

        let windowSamples = Int(targetSampleRate * liveWindowSeconds)
        if verificationPCM.count > windowSamples * 2 {
            // Keep only the most recent window
            verificationPCM.removeFirst(verificationPCM.count - windowSamples)
        }

        // Throttle: only run if we have enough speech and enough time has passed
        let now = Date()
        guard !isInferencePending,
              verificationPCM.count >= windowSamples,
              now.timeIntervalSince(lastInferenceTime) >= inferenceIntervalSeconds
        else { return }

        isInferencePending = true
        lastInferenceTime  = now

        // Take the most recent windowSamples
        let startIdx = max(0, verificationPCM.count - windowSamples)
        let snapshot = Array(verificationPCM[startIdx...])

        inferenceQueue.async { [weak self] in
            guard let self else { return }

            // Pad or trim to model input size
            let prepared = self.prepareForModel(snapshot)

            let similarity: Float
            if let liveEmbedding = self.extractEmbedding(pcmSamples: prepared, model: mdl) {
                similarity = self.cosineSimilarity(enrolled, liveEmbedding)
            } else {
                similarity = self.lastSimilarityScore  // keep previous on failure
            }

            DispatchQueue.main.async {
                self.lastSimilarityScore = similarity
                self.isInferencePending  = false
                print("[SpeakerVerification] similarity=\(String(format: "%.3f", similarity)) isMyVoice=\(similarity >= self.similarityThreshold)")
            }
        }
    }

    // -----------------------------------------------------------------------
    // MARK: - CoreML Inference (End-to-End)
    // -----------------------------------------------------------------------

    /// Runs the end-to-end CoreML model: raw PCM → embedding.
    /// Input must be exactly `modelInputSamples` (56000) samples.
    private func extractEmbedding(pcmSamples: [Float], model: MLModel) -> [Float]? {
        guard pcmSamples.count == modelInputSamples else {
            print("[SpeakerVerification] ⚠️ Expected \(modelInputSamples) samples, got \(pcmSamples.count)")
            return nil
        }

        // Build MLMultiArray [1, 56000]
        guard let inputArray = try? MLMultiArray(
            shape: [1, NSNumber(value: modelInputSamples)],
            dataType: .float32
        ) else { return nil }

        // Copy PCM data into MLMultiArray
        let ptr = inputArray.dataPointer.bindMemory(to: Float.self, capacity: modelInputSamples)
        pcmSamples.withUnsafeBufferPointer { srcPtr in
            ptr.update(from: srcPtr.baseAddress!, count: modelInputSamples)
        }

        // Run inference
        guard let featureProvider = try? MLDictionaryFeatureProvider(
            dictionary: ["waveform": MLFeatureValue(multiArray: inputArray)]
        ),
              let output   = try? model.prediction(from: featureProvider),
              let embArray = output.featureValue(for: "embedding")?.multiArrayValue
        else {
            print("[SpeakerVerification] ⚠️ CoreML inference failed")
            return nil
        }

        // Extract embedding values (model outputs [1, 1, 192])
        let totalCount = embArray.count
        guard totalCount >= embeddingDim else {
            print("[SpeakerVerification] ⚠️ Unexpected embedding size: \(totalCount)")
            return nil
        }

        var embedding = [Float](repeating: 0, count: embeddingDim)
        for i in 0..<embeddingDim {
            embedding[i] = embArray[i].floatValue
        }
        return l2Normalize(embedding)
    }

    // -----------------------------------------------------------------------
    // MARK: - Audio Preprocessing
    // -----------------------------------------------------------------------

    /// Resample buffer to 16 kHz mono Float32 PCM.
    private func resampleToMono16k(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate:   targetSampleRate,
            channels:     1,
            interleaved:  false
        ) else { return [] }

        // Fast path: already in the right format
        if buffer.format.sampleRate == targetSampleRate,
           buffer.format.channelCount == 1,
           buffer.format.commonFormat == .pcmFormatFloat32,
           let ch = buffer.floatChannelData?[0] {
            return Array(UnsafeBufferPointer(start: ch, count: Int(buffer.frameLength)))
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: targetFormat) else { return [] }

        let ratio     = targetSampleRate / buffer.format.sampleRate
        let outFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outFrames)
        else { return [] }

        var inputConsumed = false
        _ = converter.convert(to: outBuffer, error: nil) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed     = true
            outStatus.pointee = .haveData
            return buffer
        }

        guard let ch = outBuffer.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: ch, count: Int(outBuffer.frameLength)))
    }

    /// Pad (with zeros) or trim audio to exactly `modelInputSamples`.
    private func prepareForModel(_ samples: [Float]) -> [Float] {
        if samples.count == modelInputSamples {
            return samples
        } else if samples.count > modelInputSamples {
            // Take the most recent segment
            return Array(samples.suffix(modelInputSamples))
        } else {
            // Pad with zeros at the end
            var padded = samples
            padded.append(contentsOf: [Float](repeating: 0, count: modelInputSamples - samples.count))
            return padded
        }
    }

    /// Compute RMS energy of audio samples.
    private func computeRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sumSq: Float = 0
        vDSP_svesq(samples, 1, &sumSq, vDSP_Length(samples.count))
        return sqrt(sumSq / Float(samples.count))
    }

    // -----------------------------------------------------------------------
    // MARK: - Math Utilities
    // -----------------------------------------------------------------------

    /// Cosine similarity. Both vectors assumed L2-normalised → dot = cosine.
    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        return max(0.0, min(1.0, dot))
    }

    private func l2Normalize(_ v: [Float]) -> [Float] {
        var sumSq: Float = 0
        vDSP_svesq(v, 1, &sumSq, vDSP_Length(v.count))
        let norm = sqrt(sumSq)
        guard norm > 1e-8 else { return v }
        var result  = v
        var invNorm: Float = 1.0 / norm
        vDSP_vsmul(result, 1, &invNorm, &result, 1, vDSP_Length(result.count))
        return result
    }

    /// Average multiple embedding vectors element-wise.
    private func averageEmbeddings(_ embeddings: [[Float]]) -> [Float] {
        guard let first = embeddings.first else { return [] }
        let dim = first.count
        var result = [Float](repeating: 0, count: dim)
        for emb in embeddings {
            for i in 0..<dim {
                result[i] += emb[i]
            }
        }
        let scale = 1.0 / Float(embeddings.count)
        for i in 0..<dim {
            result[i] *= scale
        }
        return result
    }

    // -----------------------------------------------------------------------
    // MARK: - Persistence
    // -----------------------------------------------------------------------

    private func persistEmbedding(_ embedding: [Float]) {
        let data = embedding.withUnsafeBytes { Data($0) }
        UserDefaults.standard.set(data, forKey: embeddingDefaultsKey)
    }

    private func loadPersistedEmbedding() {
        guard let data = UserDefaults.standard.data(forKey: embeddingDefaultsKey) else { return }
        let count = data.count / MemoryLayout<Float>.size
        guard count == embeddingDim else {
            UserDefaults.standard.removeObject(forKey: embeddingDefaultsKey)
            return
        }
        var embedding = [Float](repeating: 0, count: count)
        _ = embedding.withUnsafeMutableBytes { ptr in data.copyBytes(to: ptr) }
        enrolledEmbedding = embedding
        hasVoiceProfile   = true
        print("[SpeakerVerification] ✅ Loaded persisted voice profile (\(count)-d)")
    }

    /// Clears the enrolled profile (e.g. before re-calibration).
    func clearProfile() {
        enrolledEmbedding   = nil
        hasVoiceProfile     = false
        lastSimilarityScore = 0.0
        verificationPCM     = []
        UserDefaults.standard.removeObject(forKey: embeddingDefaultsKey)
        print("[SpeakerVerification] Voice profile cleared")
    }
}
