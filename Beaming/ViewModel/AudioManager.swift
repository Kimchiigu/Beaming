//
//  AudioManager.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import AVFoundation
import FluidAudio
import Foundation
import Observation

/// Manages microphone input for hearing ("Dengar") users with **owner-gated voice
/// activity detection** (replaces the old RMS-threshold detector):
///
/// - **Calibration = owner-voice enrollment.** Records a few seconds of the owner
///   speaking, extracts a 256-d speaker embedding via FluidAudio's pyannote +
///   WeSpeaker diarizer, and persists it. Only the owner's voice will subsequently
///   trigger this phone's speaker lock/flashlight.
/// - **Meeting = Silero VAD + claim-then-verify.** The 16kHz mic stream feeds
///   FluidAudio's streaming VAD. On `speechStart` we optimistically claim the lock
///   (snappy flashlight), then verify the voice against the enrolled owner embedding
///   in the background; if it is NOT the owner we release within ~1.5s.
///
/// The public contract is unchanged: `onSpeakingStateChanged((Bool, Float))` feeds
/// `MeetingViewModel.claimSpeaker/releaseSpeaker`, so the 150ms loudest-wins
/// speaker-lock resolution (and the multi-speaker indicator) is untouched.
@Observable
class AudioManager {

    // MARK: - Observable state (UI)

    /// Whether the local user currently holds a speaking claim.
    var isSpeaking: Bool = false

    /// Current mic level (RMS) for the calibration waveform.
    var audioLevel: Float = 0.0

    /// Whether the microphone is muted.
    var isMuted: Bool = false

    // MARK: - Calibration state (read by CalibView)

    var isCalibrating: Bool = false
    var isCalibrated: Bool = false
    var calibrationProgress: Float = 0.0
    var calibrationPhase: CalibrationPhase = .idle

    enum CalibrationPhase: String {
        case idle
        case downloading = "Mengunduh model suara…"
        case recording   = "Mendengarkan suaramu…"
        case enrolling   = "Mendaftarkan suaramu…"
        case done        = "Selesai"
        case failed      = "Gagal mendaftarkan suara."
    }

    // MARK: - Callbacks (unchanged contract)

    /// Fired when VAD detects speech start/end. Includes RMS for loudness-based
    /// claim resolution on the host.
    var onSpeakingStateChanged: ((Bool, Float) -> Void)?

    /// Fired when calibration (enrollment) completes successfully.
    var onCalibrationComplete: (() -> Void)?

    // MARK: - Debug diagnostics (for the Dengar debug view)

    /// True while the Silero VAD considers speech active in the current chunk
    /// (independent of whether the owner-gate claimed/released).
    var vadTriggered: Bool = false

    /// Cosine similarity of the most recent owner verification (nil until first check).
    var lastVerificationSim: Float?

    /// Whether the most recent verification accepted the voice as the owner.
    var lastVerificationIsOwner: Bool?

    /// Running tallies of owner-verifications this session.
    var ownerAcceptCount: Int = 0
    var ownerRejectCount: Int = 0

    /// Most recent verification results (newest last), for the debug confidence log.
    struct VerificationRecord: Identifiable {
        let id = UUID()
        let similarity: Float
        let isOwner: Bool
        let seconds: Double   // audio length used for this embedding
    }
    var verificationHistory: [VerificationRecord] = []
    private let maxVerificationHistory = 20

    // MARK: - FluidAudio

    private var vadManager: VadManager?
    private var diarizer: DiarizerManager?

    /// Rolling Silero streaming state (carries hidden/cell/context between chunks).
    private var vadStreamState: VadStreamState = .initial()

    /// Hysteresis timing for the streaming VAD state machine.
    private let vadSegmentationConfig = VadSegmentationConfig(
        minSpeechDuration: 0.1,
        minSilenceDuration: 0.5,   // faster handoff than the 0.75 default
        maxSpeechDuration: 14.0,
        speechPadding: 0.1
    )

    /// Owner's enrolled speaker embedding (L2-normalized, 256-d). nil until calibrated.
    private(set) var ownerEmbedding: [Float]?

    /// Cosine-similarity threshold above which a voice is accepted as the owner.
    /// Lower = more permissive (owner always gets through); higher = stricter.
    /// Mutable at runtime so the debug view can tune it live.
    var ownerMatchThreshold: Float = 0.5

    /// Verify the owner once an utterance reaches this many samples (~0.6s @ 16kHz),
    /// then again every time this many *new* samples arrive. Verifying early + often
    /// is what actually rejects short non-owner utterances (the old single-shot 1.5s
    /// check let most short utterances through unchecked).
    private let firstVerifyTarget: Int = 9_600
    private let verifyInterval: Int = 9_600

    static let ownerEmbeddingKey = "beaming.ownerEmbedding"

    // MARK: - Audio engine

    private var audioEngine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private let targetSampleRate: Double = 16_000
    private let vadChunkSize: Int = VadManager.chunkSize  // 4096 (256ms)

    /// Incoming 16kHz mono samples are accumulated here, then sliced into
    /// `vadChunkSize` chunks. Only ever touched from the serial audio tap callback.
    private var sampleAccumulator: [Float] = []

    /// Serial, ordered VAD chunk pipeline (one chunk processed at a time → VAD state
    /// stays coherent and all per-utterance state is single-threaded).
    private var chunkStream: AsyncStream<[Float]>?
    private var chunkContinuation: AsyncStream<[Float]>.Continuation?
    private var vadTask: Task<Void, Never>?

    /// Ensures the models are loaded before the engine/pipeline start (handles the
    /// persisted-embedding relaunch case where enrollment didn't run this session).
    private var listeningTask: Task<Void, Never>?

    // MARK: - Per-utterance state (owned by the VAD pipeline task)

    private var utteranceBuffer: [Float] = []
    private var isVerifying: Bool = false
    /// Sample count at the last verification this utterance (drives incremental re-verify).
    private var lastVerifiedSampleCount: Int = 0
    /// Set when a non-owner was detected this utterance — ignore further `speechStart`
    /// blips until the utterance ends, so we don't flap the lock.
    private var suppressedForUtterance: Bool = false

    // MARK: - Enrollment recording buffer (audio-thread writes, enrollment reads)

    private let recordingLock = NSLock()
    private var recordingStorage: [Float] = []

    // MARK: - Init

    init() {
        loadOwnerEmbedding()
    }

    // MARK: - Owner embedding persistence

    private func loadOwnerEmbedding() {
        guard let data = UserDefaults.standard.data(forKey: Self.ownerEmbeddingKey) else { return }
        let floats = data.withUnsafeBytes { rawBuffer -> [Float] in
            let pointer = rawBuffer.bindMemory(to: Float.self)
            return Array(pointer)
        }
        guard floats.count == 256 else { return }
        ownerEmbedding = floats
        isCalibrated = true
    }

    private func persistOwnerEmbedding(_ embedding: [Float]) {
        let byteCount = embedding.count * MemoryLayout<Float>.size
        let data = embedding.withUnsafeBufferPointer { buffer -> Data in
            Data(bytes: buffer.baseAddress!, count: byteCount)
        }
        UserDefaults.standard.set(data, forKey: Self.ownerEmbeddingKey)
    }

    // MARK: - Calibration (owner enrollment)

    /// Begin owner-voice enrollment: download models → record → embed → persist.
    func startCalibration() {
        guard !isCalibrating else { return }
        Task { await runEnrollment() }
    }

    private func runEnrollment() async {
        await MainActor.run {
            self.isCalibrating = true
            self.calibrationProgress = 0
            self.calibrationPhase = .downloading
        }

        // 1) Download / load models (first run downloads from HuggingFace).
        do {
            if diarizer == nil {
                let models = try await DiarizerModels.download { [weak self] progress in
                    let value = Float(progress.fractionCompleted) * 0.5
                    Task { @MainActor [weak self] in self?.calibrationProgress = value }
                }
                let manager = DiarizerManager()
                manager.initialize(models: models)
                self.diarizer = manager
            }
            if vadManager == nil {
                let vad = try await VadManager(config: .default) { [weak self] progress in
                    let value = 0.5 + Float(progress.fractionCompleted) * 0.5
                    Task { @MainActor [weak self] in self?.calibrationProgress = value }
                }
                self.vadManager = vad
            }
        } catch {
            await MainActor.run {
                self.calibrationPhase = .failed
                self.isCalibrating = false
            }
            return
        }

        // 2) Record ~6s of the owner's voice.
        await MainActor.run {
            self.calibrationPhase = .recording
            self.calibrationProgress = 0
        }
        recordingReset()
        startAudioEngine()

        let duration = CalibModel.calibrationDuration
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < duration {
            try? await Task.sleep(nanoseconds: 50_000_000)
            let progress = Float(Date().timeIntervalSince(startTime) / duration)
            await MainActor.run { self.calibrationProgress = min(progress, 1.0) }
        }
        stopAudioEngine()

        // 3) Extract + persist the owner embedding.
        await MainActor.run {
            self.calibrationPhase = .enrolling
            self.calibrationProgress = 1.0
        }
        let samples = recordingDrain()
        guard let diarizer, !samples.isEmpty else {
            await MainActor.run { self.calibrationPhase = .failed; self.isCalibrating = false }
            return
        }
        let embedding = try? diarizer.extractSpeakerEmbedding(from: samples)
        guard let embedding, embedding.count == 256 else {
            await MainActor.run { self.calibrationPhase = .failed; self.isCalibrating = false }
            return
        }
        persistOwnerEmbedding(embedding)
        self.ownerEmbedding = embedding

        // 4) Done — same completion contract as before.
        await MainActor.run {
            self.isCalibrated = true
            self.calibrationPhase = .done
            self.calibrationProgress = 1.0
            self.isCalibrating = false
            self.onCalibrationComplete?()
        }
    }

    func cancelCalibration() {
        Task { @MainActor in
            self.isCalibrating = false
            self.calibrationProgress = 0
            self.calibrationPhase = .idle
        }
        stopAudioEngine()
        recordingReset()
    }

    // MARK: - Permission

    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    // MARK: - Listening (owner-gated VAD)

    func startListening() {
        guard !isMuted else { return }
        // Models may not be loaded yet (persisted-embedding relaunch). Load first,
        // then begin the engine + VAD pipeline.
        listeningTask = Task {
            await ensureModelsLoaded()
            guard !Task.isCancelled else { return }
            beginListening()
        }
    }

    func stopListening() {
        listeningTask?.cancel()
        listeningTask = nil
        stopAudioEngine()
        stopVADPipeline()
        if isSpeaking {
            isSpeaking = false
            onSpeakingStateChanged?(false, 0.0)
        }
        audioLevel = 0.0
    }

    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            stopListening()
        } else {
            startListening()
        }
    }

    private func ensureModelsLoaded() async {
        if vadManager == nil {
            vadManager = try? await VadManager(config: .default)
        }
        if diarizer == nil {
            if let models = try? await DiarizerModels.download() {
                let manager = DiarizerManager()
                manager.initialize(models: models)
                diarizer = manager
            }
        }
    }

    private func beginListening() {
        vadStreamState = .initial()
        utteranceBuffer.removeAll()
        lastVerifiedSampleCount = 0
        isVerifying = false
        suppressedForUtterance = false
        sampleAccumulator.removeAll()
        startVADPipeline()
        startAudioEngine()
    }

    // MARK: - VAD pipeline

    private func startVADPipeline() {
        stopVADPipeline()
        let (stream, continuation) = AsyncStream.makeStream(of: [Float].self)
        chunkStream = stream
        chunkContinuation = continuation
        vadTask = Task { [weak self] in
            for await chunk in stream {
                guard let self else { return }
                if Task.isCancelled { return }
                await self.processVADChunk(chunk)
            }
        }
    }

    private func stopVADPipeline() {
        chunkContinuation?.finish()
        chunkContinuation = nil
        chunkStream = nil
        vadTask?.cancel()
        vadTask = nil
    }

    /// Process one 4096-sample (256ms) chunk through the Silero VAD state machine and
    /// drive the optimistic claim / owner-verify / release logic. Runs serially on the
    /// VAD pipeline task, so all per-utterance state here is race-free.
    private func processVADChunk(_ chunk: [Float]) async {
        guard let vad = vadManager else { return }
        guard let result = try? await vad.processStreamingChunk(
            chunk,
            state: vadStreamState,
            config: vadSegmentationConfig
        ) else { return }
        vadStreamState = result.state
        await setVADTriggered(result.state.triggered)

        // Boundary events → claim/release. Otherwise keep accumulating speech audio.
        if let event = result.event {
            if event.isStart {
                // New utterance: reset, claim optimistically (snappy flashlight).
                utteranceBuffer = chunk
                lastVerifiedSampleCount = 0
                isVerifying = false
                suppressedForUtterance = false
                await emitSpeaking(true, rms: rms(of: chunk))
            } else if event.isEnd {
                // Backstop: if the utterance was too short to verify mid-flight, check
                // it now so every utterance produces a confidence reading (and a non-owner
                // is at least flagged). The release below happens regardless.
                if !suppressedForUtterance,
                   ownerEmbedding != nil,
                   lastVerifiedSampleCount == 0,
                   utteranceBuffer.count >= 4_000 {
                    await verifyOwner()
                }
                await emitSpeaking(false, rms: 0)
                utteranceBuffer.removeAll()
                lastVerifiedSampleCount = 0
                isVerifying = false
                suppressedForUtterance = false
            }
        } else if result.state.triggered {
            utteranceBuffer.append(contentsOf: chunk)
        }

        // Incremental owner verification: first check at ~0.6s, then every ~0.6s of new
        // audio. Verifying early + repeatedly is what rejects short non-owner utterances.
        if result.state.triggered,
           !suppressedForUtterance,
           ownerEmbedding != nil,
           !isVerifying,
           utteranceBuffer.count >= firstVerifyTarget,
           utteranceBuffer.count - lastVerifiedSampleCount >= verifyInterval {
            await verifyOwner()
        }
    }

    /// Extract an embedding from the buffered utterance and compare it (cosine) to the
    /// enrolled owner. If it is NOT the owner, retract the claim and suppress further
    /// claims until this utterance ends. Runs inline on the VAD pipeline task — the
    /// ~50–150ms CoreML extraction briefly pauses chunk processing (AsyncStream
    /// buffers), which is harmless.
    private func verifyOwner() async {
        guard let owner = ownerEmbedding, let diarizer, !utteranceBuffer.isEmpty else { return }
        isVerifying = true
        let snapshot = utteranceBuffer
        let sampleCount = snapshot.count
        let embedding = try? diarizer.extractSpeakerEmbedding(from: snapshot)
        lastVerifiedSampleCount = sampleCount
        isVerifying = false

        guard let embedding, !embedding.isEmpty else { return }
        let similarity = cosine(embedding, owner)
        let isOwner = similarity >= ownerMatchThreshold
        let seconds = Double(sampleCount) / targetSampleRate
        await recordVerification(similarity: similarity, isOwner: isOwner, seconds: seconds)
        print("[AudioManager] owner-verify sim=\(String(format: "%.3f", similarity)) owner=\(isOwner) len=\(String(format: "%.2f", seconds))s")
        // Retract only on a CONFIDENT non-owner: either clearly below threshold
        // (hysteresis avoids retracting the owner on a noisy short-clip reading), or
        // once we have ≥1s of audio so the embedding is reliable.
        let confidentReject = !isOwner && (similarity < ownerMatchThreshold - 0.1 || seconds >= 1.0)
        if confidentReject {
            suppressedForUtterance = true
            await emitSpeaking(false, rms: 0)
        }
    }

    /// Update `isSpeaking` + notify the view model. Always on the main actor so the
    /// SwiftUI state and the network claim/release calls stay consistent.
    @MainActor
    private func emitSpeaking(_ speaking: Bool, rms rmsLevel: Float) {
        isSpeaking = speaking
        onSpeakingStateChanged?(speaking, rmsLevel)
    }

    /// Publish VAD activity for the debug view (main actor).
    @MainActor
    private func setVADTriggered(_ value: Bool) {
        vadTriggered = value
    }

    /// Record the latest owner-verification result for the debug view (main actor).
    @MainActor
    private func recordVerification(similarity: Float, isOwner: Bool, seconds: Double) {
        lastVerificationSim = similarity
        lastVerificationIsOwner = isOwner
        if isOwner { ownerAcceptCount += 1 } else { ownerRejectCount += 1 }
        verificationHistory.append(
            VerificationRecord(similarity: similarity, isOwner: isOwner, seconds: seconds)
        )
        if verificationHistory.count > maxVerificationHistory {
            verificationHistory.removeFirst(verificationHistory.count - maxVerificationHistory)
        }
    }

    // MARK: - Audio engine

    private func startAudioEngine() {
        guard audioEngine == nil else { return }

        // Activate the session FIRST so the input node reports a real hardware format.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth]
            )
            try session.setActive(true)
        } catch {
            print("[AudioManager] Audio session error: \(error)")
            return
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Tap at the HARDWARE format. Installing a non-hardware format on the input
        // node aborts on real devices (outside Swift's do/catch). We convert each
        // buffer to 16kHz mono Float32 ourselves — what the VAD/embedding models need.
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0 else {
            print("[AudioManager] Input format not ready")
            return
        }
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else { return }
        converter = AVAudioConverter(from: inputFormat, to: outputFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self, let converter = self.converter else { return }
            let samples = self.convertTo16kMono(buffer, using: converter)
            guard !samples.isEmpty else { return }

            // RMS for the calibration waveform UI.
            let level = Self.simpleRMS(samples)
            DispatchQueue.main.async { self.audioLevel = level }

            self.handleSamples(samples)
        }

        do {
            try engine.start()
            audioEngine = engine
        } catch {
            print("[AudioManager] Failed to start audio engine: \(error)")
        }
    }

    private func stopAudioEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        converter = nil
        sampleAccumulator.removeAll()
    }

    /// Convert an arbitrary hardware-format PCM buffer to 16kHz mono Float32 samples
    /// (downmixes channels + resamples). Returns [] if conversion yields nothing.
    private func convertTo16kMono(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) -> [Float] {
        let inputFormat = converter.inputFormat
        let outputFormat = converter.outputFormat
        let ratio = outputFormat.sampleRate / inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return [] }

        var fed = false
        var conversionError: NSError?
        let status = converter.convert(to: outBuffer, error: &conversionError) { _, inputStatus in
            if fed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            fed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, conversionError == nil else { return [] }
        guard let channelData = outBuffer.floatChannelData?[0] else { return [] }
        let frameLength = Int(outBuffer.frameLength)
        guard frameLength > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: channelData, count: frameLength))
    }

    /// Accumulate incoming samples into 4096-sample chunks; route each chunk to either
    /// the enrollment recorder (during calibration) or the VAD pipeline. Runs on the
    /// serial audio tap callback, so `sampleAccumulator` needs no lock.
    private func handleSamples(_ samples: [Float]) {
        sampleAccumulator.append(contentsOf: samples)
        while sampleAccumulator.count >= vadChunkSize {
            let chunk = Array(sampleAccumulator.prefix(vadChunkSize))
            sampleAccumulator.removeFirst(vadChunkSize)
            if isCalibrating {
                recordingAppend(chunk)
            } else {
                chunkContinuation?.yield(chunk)
            }
        }
    }

    // MARK: - Recording buffer (locked: audio-thread writes, enrollment reads)

    private func recordingReset() {
        recordingLock.lock()
        recordingStorage.removeAll()
        recordingLock.unlock()
    }

    private func recordingAppend(_ chunk: [Float]) {
        recordingLock.lock()
        recordingStorage.append(contentsOf: chunk)
        recordingLock.unlock()
    }

    private func recordingDrain() -> [Float] {
        recordingLock.lock()
        let value = recordingStorage
        recordingStorage.removeAll()
        recordingLock.unlock()
        return value
    }

    // MARK: - Math helpers

    private func rms(of chunk: [Float]) -> Float {
        Self.simpleRMS(chunk)
    }

    /// Cosine similarity in [-1, 1]. Normalizes both vectors explicitly so it is
    /// correct even if the upstream embeddings are NOT already unit-length. The raw
    /// WeSpeaker output's magnitude varies a lot, so a plain dot product there blows
    /// past 1.0 and makes any fixed threshold meaningless (every voice "matches") —
    /// normalizing here is what makes owner-vs-other separable. Same speaker is
    /// typically 0.6–0.95; different speakers usually sit below ~0.5.
    private func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for index in 0..<a.count {
            dot += a[index] * b[index]
            normA += a[index] * a[index]
            normB += b[index] * b[index]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return dot / denom
    }

    private static func simpleRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples { sum += sample * sample }
        return sqrt(sum / Float(samples.count))
    }

    deinit {
        stopAudioEngine()
        stopVADPipeline()
        listeningTask?.cancel()
    }
}
