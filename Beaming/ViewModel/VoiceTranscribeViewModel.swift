//
//  VoiceTranscribeViewModel.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 09/07/26.
//
//  Live speech-to-text engine for the in-meeting captions. Wraps SFSpeechRecognizer
//  + its own AVAudioEngine and EMITS one cumulative "turn" string via
//  `onCaptionUpdate`. The caller (MeetingViewModel) turns each turn into a single
//  chat bubble and starts a new bubble when the speaker changes.
//
//  Semantics of `onCaptionUpdate(text, isFinal)`:
//  - isFinal == false → the FULL text of the current speaking turn so far (grows as
//    the user talks; accumulates across SFSpeech's ~60s task restarts so earlier
//    words are never lost mid-turn).
//  - isFinal == true  → the turn just ended (a pause in speech); `text` is the full
//    turn text. After this, internal turn state resets so the next utterance is fresh.
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

    /// Fired on the main actor with the current turn text. See class docs.
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

    /// Pause detection: when no new partial arrives for this long, the current turn
    /// is committed (so the next utterance starts a fresh bubble).
    private var pauseTimer: Timer?
    private let pauseInterval: TimeInterval = 1.2

    // MARK: - Turn state (one bubble per speaking turn)

    /// Full text of the current speaking turn so far (what's emitted to the UI).
    private var turnText: String = ""

    /// Text finalized from earlier recognition segments within this turn
    /// (accumulated across SFSpeech's ~60s task restarts so words aren't lost).
    private var committedFromTask: String = ""

    /// The current recognition task's cumulative transcript (resets on restart).
    private var currentSegmentText: String = ""

    /// Last value emitted, to skip no-op duplicates (identical repeated partials).
    private var lastEmittedTurnText: String = ""

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
        resetTurnState()
        Task { await startAfterPermissions() }
    }

    /// Stop capturing + recognizing. Commits the in-flight turn.
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
        let taskEnded = (error != nil) || (result?.isFinal == true)

        if let result, !taskEnded {
            applyPartial(result.bestTranscription.formattedString)
        }

        if taskEnded {
            // SFSpeech ended this recognition task (~60s limit). Fold the finished
            // segment into the turn so its text survives, then start a fresh task —
            // the turn continues (no new bubble yet).
            accumulateSegment()
            if isTranscribing {
                restartTask()
            }
        }
    }

    /// A new partial arrived: grow the current turn's text and emit it.
    private func applyPartial(_ full: String) {
        currentSegmentText = full
        turnText = committedFromTask.isEmpty ? full : (committedFromTask + " " + full)

        // Only emit + reset the pause timer when the turn text actually changed —
        // identical repeated partials mean the user paused, so let the timer fire.
        if turnText != lastEmittedTurnText {
            lastEmittedTurnText = turnText
            onCaptionUpdate?(turnText, false)
            resetPauseTimer()
        }
    }

    /// Fold the just-ended recognition segment into the turn (called on task restart).
    private func accumulateSegment() {
        let segment = currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        currentSegmentText = ""
        guard !segment.isEmpty else { return }
        committedFromTask = committedFromTask.isEmpty ? segment : committedFromTask + " " + segment
        // Reflect the accumulated state immediately (no open partial tail right now).
        turnText = committedFromTask
        if turnText != lastEmittedTurnText {
            lastEmittedTurnText = turnText
            onCaptionUpdate?(turnText, false)
        }
    }

    // MARK: - Turn end (pause / stop)

    /// Called when speech pauses (no new partial for `pauseInterval`): commit the
    /// current turn so the next utterance starts a fresh bubble.
    private func onPause() {
        guard isTranscribing else { return }
        commitTurn()
    }

    /// Emit the current turn as finalized, then reset turn state.
    private func commitTurn() {
        pauseTimer?.invalidate()
        pauseTimer = nil
        let final = turnText.trimmingCharacters(in: .whitespacesAndNewlines)
        resetTurnState()
        guard !final.isEmpty else { return }
        onCaptionUpdate?(final, true)
    }

    private func resetTurnState() {
        turnText = ""
        committedFromTask = ""
        currentSegmentText = ""
        lastEmittedTurnText = ""
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

    /// Swap in a fresh request+task on the (still-running) engine. The turn
    /// continues — only the per-task segment cursor resets.
    private func restartTask() {
        restartTimer?.invalidate()
        pauseTimer?.invalidate()
        pauseTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        guard isTranscribing, let speechRecognizer, speechRecognizer.isAvailable else { return }

        currentSegmentText = ""   // new task = fresh segment; committedFromTask kept
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
        commitTurn()
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
