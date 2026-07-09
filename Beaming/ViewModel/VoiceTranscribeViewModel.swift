//
//  VoiceTranscribeViewModel.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 09/07/26.
//
//  Live speech-to-text engine for the in-meeting captions. Wraps SFSpeechRecognizer
//  + its own AVAudioEngine and EMITS recognized text via `onCaptionUpdate`. The
//  caller (MeetingViewModel) owns the displayed feed and the network broadcast.
//  Restarts silently before SFSpeech's ~1-minute per-task cap.
//

import Foundation
import AVFoundation
import Speech
import Observation

/// One caption bubble in the transcription feed.
struct CaptionMessage: Identifiable {
    let id = UUID()
    let speakerID: UUID
    let speakerName: String
    var text: String
    let date: Date
}

/// Live speech-to-text engine.
///
/// Owns its own `AVAudioEngine` + `SFSpeechRecognizer` and emits recognized text
/// through `onCaptionUpdate(text, isFinal)`:
/// - `isFinal == true`  → a finalized sentence (commit a bubble).
/// - `isFinal == false` → the growing partial since the last sentence (live bubble).
///
/// ⚠️ Coexistence note: `AudioManager` ALSO installs a mic input tap (for RMS
/// detection) for the whole meeting. This VM uses a *separate* engine/node, so the
/// two taps don't collide on the same node — but if a device/OS ever rejects two
/// concurrent input consumers, the robust fix is a single shared input tap in
/// `AudioManager` that feeds BOTH RMS and this recognizer. That requires editing
/// `AudioManager`, which is outside this file's scope.
@MainActor
@Observable
final class VoiceTranscribeViewModel {

    // MARK: - Observable state (for the UI)

    /// Whether the recognizer is actively capturing + recognizing.
    private(set) var isTranscribing: Bool = false

    /// Last error, surfaced in the UI. nil when healthy.
    private(set) var errorMessage: String?

    /// Fired on the main actor with recognized text. See class docs for semantics.
    var onCaptionUpdate: ((_ text: String, _ isFinal: Bool) -> Void)?

    // MARK: - Speech plumbing

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()
    private var hasTap = false

    /// Restart just before SFSpeech's ~60s per-task limit.
    private let restartInterval: TimeInterval = 50
    private var restartTimer: Timer?

    /// How many characters of the *current* recognition task's transcript have
    /// already been emitted as finalized sentences.
    private var committedChars: Int = 0

    /// The currently-open partial tail (emitted as the live bubble; flushed on end).
    private var currentTail: String = ""

    /// Pause detection: when no new partial arrives for this long, the current
    /// bubble is committed so the next utterance starts a fresh bubble.
    private var pauseTimer: Timer?
    private let pauseInterval: TimeInterval = 1.2

    /// Character count of the last seen cumulative transcript. Used to advance the
    /// cursor correctly when committing on a pause (without resetting the task).
    private var lastFullCount: Int = 0

    /// Recognition locale. Defaults to Indonesian; falls back if unavailable.
    init(locale: Locale = Locale(identifier: "id-ID")) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
            ?? SFSpeechRecognizer(locale: .current)
            ?? SFSpeechRecognizer()
        if speechRecognizer == nil {
            errorMessage = "Pengenalan suara bahasa Indonesia belum tersedia. Aktifkan bahasa Indonesia di Pengaturan perangkat."
        }
    }

    // MARK: - Public controls

    /// Begin capturing + recognizing. Safe to call repeatedly.
    func startTranscribing() {
        guard !isTranscribing else { return }
        guard let speechRecognizer else {
            errorMessage = "Pengenalan suara tidak tersedia di perangkat ini."
            return
        }
        guard speechRecognizer.isAvailable else {
            errorMessage = "Pengenalan suara belum siap. Coba lagi sebentar."
            return
        }

        errorMessage = nil
        committedChars = 0
        currentTail = ""
        lastFullCount = 0
        Task { await startAfterPermissions() }
    }

    /// Stop capturing + recognizing. Flushes any in-flight partial as a final.
    func stopTranscribing() {
        teardown()
    }

    // MARK: - Permissions

    private func startAfterPermissions() async {
        let speechOK = await Self.requestSpeechAuthorization()
        let micOK = await Self.requestMicPermission()
        guard speechOK, micOK else {
            errorMessage = "Izinkan mikrofon & pengenalan suara untuk menggunakan transkripsi."
            return
        }
        beginSession()
    }

    // MARK: - Session

    private func beginSession() {
        do {
            // Match AudioManager's session config so we don't disrupt RMS detection.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = newRequest()
            recognitionRequest = request
            installTap(for: request)

            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in self?.handle(result: result, error: error) }
            }

            isTranscribing = true
            scheduleRestart()
        } catch {
            errorMessage = "Gagal memulai transkripsi: \(error.localizedDescription)"
            teardown()
        }
    }

    private func newRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true   // stream word-by-word
        // Prefer on-device recognition when supported (privacy + offline).
        if speechRecognizer?.supportsOnDeviceRecognition ?? false {
            request.requiresOnDeviceRecognition = true
        }
        return request
    }

    private func installTap(for request: SFSpeechAudioBufferRecognitionRequest) {
        guard !hasTap else { return }
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }
        hasTap = true
    }

    private func removeTap() {
        guard hasTap else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        hasTap = false
    }

    // MARK: - Result handling

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            applyPartial(result.bestTranscription.formattedString)
        }

        // SFSpeech ends each task near 60s (delivered as an error or isFinal).
        // Flush the open partial, then seamlessly start a fresh task.
        let taskEnded = (error != nil) || (result?.isFinal == true)
        if taskEnded {
            commitTail(resetCursor: true)
            if isTranscribing {
                restartTask()
            }
        }
    }

    /// Split the cumulative transcript into newly-completed sentences + the open
    /// tail, and emit each via `onCaptionUpdate`. Also arms the pause timer so a
    /// pause in speech commits the current bubble (and starts a fresh one).
    private func applyPartial(_ full: String) {
        // SFSpeech slid its context window (dropped earlier text). Realign without
        // re-emitting already-committed sentences; show what remains as the live bubble.
        if full.count < committedChars {
            committedChars = 0
            let tail = full.trimmingCharacters(in: .whitespacesAndNewlines)
            currentTail = tail
            lastFullCount = full.count
            onCaptionUpdate?(tail, false)
            resetPauseTimer()
            return
        }

        let (sentences, liveTail) = extractNewSentences(from: full)
        for sentence in sentences {
            onCaptionUpdate?(sentence, true)
        }

        let trimmedTail = liveTail.trimmingCharacters(in: .whitespacesAndNewlines)
        lastFullCount = full.count

        // Only reset the pause timer when the live tail actually changed — identical
        // repeated partials mean the user paused, so we let the timer fire + commit.
        if trimmedTail != currentTail {
            currentTail = trimmedTail
            onCaptionUpdate?(trimmedTail, false)
            resetPauseTimer()
        }
    }

    /// Split `full` (the whole current-task transcript) beyond what's already
    /// committed into finalized sentences + the still-open tail. Advances
    /// `committedChars` by the characters consumed.
    private func extractNewSentences(from full: String) -> (newSentences: [String], liveTail: String) {
        guard committedChars < full.count else {
            return ([], "")
        }
        let start = full.index(full.startIndex, offsetBy: committedChars)
        let remaining = full[start...]
        let terminators: Set<Character> = [".", "!", "?", "।"]

        var sentences: [String] = []
        var sentenceStart = remaining.startIndex
        var consumedUpTo = remaining.startIndex
        var idx = remaining.startIndex
        while idx < remaining.endIndex {
            if terminators.contains(remaining[idx]) {
                let raw = String(remaining[sentenceStart...idx])
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                idx = remaining.index(after: idx)
                sentenceStart = idx
                consumedUpTo = idx
            } else {
                idx = remaining.index(after: idx)
            }
        }

        let liveTail = (sentenceStart < remaining.endIndex) ? String(remaining[sentenceStart...]) : ""
        let consumedInRemaining = remaining.distance(from: remaining.startIndex, to: consumedUpTo)
        committedChars += consumedInRemaining
        return (sentences, liveTail)
    }

    /// Emit any open partial as a finalized sentence.
    /// - resetCursor: `true` when the recognition task is ending (a new task
    ///   produces a fresh transcript); `false` when committing mid-task (e.g. on a
    ///   pause), where the cursor must advance to the end of the current transcript.
    private func commitTail(resetCursor: Bool) {
        pauseTimer?.invalidate()
        pauseTimer = nil
        let trimmed = currentTail.trimmingCharacters(in: .whitespacesAndNewlines)
        currentTail = ""
        committedChars = resetCursor ? 0 : lastFullCount
        guard !trimmed.isEmpty else { return }
        onCaptionUpdate?(trimmed, true)
    }

    /// Called when speech pauses (no new partial for `pauseInterval`): commit the
    /// current bubble so the next utterance starts a fresh one.
    @discardableResult
    private func onPause() -> Bool {
        guard isTranscribing, !currentTail.isEmpty else { return false }
        commitTail(resetCursor: false)
        return true
    }

    private func resetPauseTimer() {
        pauseTimer?.invalidate()
        pauseTimer = Timer.scheduledTimer(withTimeInterval: pauseInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.onPause() }
        }
    }

    // MARK: - Restart (SFSpeech tasks cap near 1 minute)

    private func scheduleRestart() {
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: restartInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.restartTask() }
        }
    }

    /// Swap in a fresh request+task on the (still-running) engine. The new task
    /// produces a fresh transcript, so the char cursor resets.
    private func restartTask() {
        restartTimer?.invalidate()
        pauseTimer?.invalidate()
        pauseTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        guard isTranscribing, let speechRecognizer, speechRecognizer.isAvailable else { return }

        committedChars = 0
        currentTail = ""
        lastFullCount = 0

        removeTap()
        let request = newRequest()
        recognitionRequest = request
        installTap(for: request)

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in self?.handle(result: result, error: error) }
        }
        scheduleRestart()
    }

    // MARK: - Teardown

    private func teardown() {
        restartTimer?.invalidate()
        restartTimer = nil
        pauseTimer?.invalidate()
        pauseTimer = nil
        commitTail(resetCursor: true)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        removeTap()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        isTranscribing = false
    }

    // MARK: - Permissions (async wrappers)

    // NOTE: No `deinit` — this is a @MainActor-isolated class, so a nonisolated
    // deinit couldn't safely touch the AVAudioEngine/SFSpeech state. Callers MUST
    // call `stopTranscribing()` (MeetingView does so in `.onDisappear`).

    private static func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private static func requestMicPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
