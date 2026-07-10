//
//  VoiceTranscribeViewModel.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 09/07/26.
//
//  Live speech-to-text engine for the in-meeting captions. Wraps SFSpeechRecognizer
//  + its own AVAudioEngine and emits AT MOST two events per speaking turn:
//  - onCaptionUpdate("",  false) when a turn starts  → the UI shows a placeholder.
//  - onCaptionUpdate(text, true ) when a turn ends    → the UI fills the bubble.
//  No per-word streaming (that re-rendered the whole list and caused lag). The full
//  turn text is accumulated internally (across SFSpeech's ~60s task restarts) and
//  emitted once, ~2s after the speaker goes silent.
//

import Foundation
import AVFoundation
import Speech
import Observation

/// One caption bubble in the transcription feed. Equatable so the chat can skip
/// re-rendering unchanged (historical) rows — only the new/changed bubble renders.
struct CaptionMessage: Identifiable, Equatable {
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

    /// Fired on the main actor. See class docs (turn-start placeholder, or finalized text).
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

    /// Recovery timer used when the recognizer is temporarily unavailable (Apple
    /// throttles it after heavy use) — retries instead of silently dying.
    private var retryTimer: Timer?

    /// Monotonic token for the active recognition task. Callbacks from a task we've
    /// already cancelled/replaced are ignored — this prevents a cancel→restart
    /// cascade (cancelling a task fires its handler one last time).
    private var currentTaskToken: Int = 0

    /// A turn ends after this much silence → emit the finalized text.
    private var pauseTimer: Timer?
    private let pauseInterval: TimeInterval = 2.0

    // MARK: - Turn state

    /// True while the local user is inside a speaking turn (between turn-start and finalize).
    private var inTurn: Bool = false

    /// Full text of the current turn so far (accumulated across task restarts).
    private var turnText: String = ""

    /// Text finalized from earlier recognition segments within this turn.
    private var committedFromTask: String = ""

    /// The current recognition task's cumulative transcript (resets on restart).
    private var currentSegmentText: String = ""

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

            isTranscribing = true
            startNewTask()   // installs the tap, starts the engine, builds the task
            scheduleRestart()
        } catch {
            errorMessage = "Gagal memulai transkripsi: \(error.localizedDescription)"
            teardown()
        }
    }

    private func newRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
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
        // A zero sample rate means the input isn't ready (session not active for
        // input). Installing the tap now would trap, so bail out gracefully.
        guard format.sampleRate > 0 else { return }
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

    private func handle(result: SFSpeechRecognitionResult?, error: Error?, token: Int) {
        // Ignore callbacks from a task we've already cancelled/replaced. Without this,
        // cancelling a task (which fires its handler one last time) would re-enter
        // restartTask and cascade, burning through tasks until Apple throttles the
        // recognizer and speech silently stops.
        guard token == currentTaskToken else { return }

        let taskEnded = (error != nil) || (result?.isFinal == true)

        if let result, !taskEnded {
            applyPartial(result.bestTranscription.formattedString)
        }

        if taskEnded {
            // SFSpeech ended this recognition task (~60s limit). Fold the finished
            // segment into the turn so its text survives, then start a fresh task —
            // the turn continues (no finalize emitted yet).
            accumulateSegment()
            if isTranscribing {
                restartTask()
            }
        }
    }

    /// Accumulate the partial into the current turn. Emit a turn-start placeholder
    /// once (when real text is first detected). Do NOT stream word-by-word.
    private func applyPartial(_ full: String) {
        currentSegmentText = full
        let next = committedFromTask.isEmpty ? full : (committedFromTask + " " + full)
        let changed = (next != turnText)
        turnText = next

        if !turnText.isEmpty && !inTurn {
            inTurn = true
            onCaptionUpdate?("", false)   // turn started → placeholder bubble
        }

        // Re-arm the turn-end timer only when speech is actually progressing.
        if changed {
            resetPauseTimer()
        }
    }

    /// Fold the just-ended recognition segment into the turn (called on task restart).
    private func accumulateSegment() {
        let segment = currentSegmentText.trimmingCharacters(in: .whitespacesAndNewlines)
        currentSegmentText = ""
        if !segment.isEmpty {
            committedFromTask = committedFromTask.isEmpty ? segment : committedFromTask + " " + segment
        }
        turnText = committedFromTask
        if inTurn {
            resetPauseTimer()   // turn continues across the restart
        }
    }

    // MARK: - Turn end

    /// Called when speech pauses for `pauseInterval`: emit the finalized turn text.
    private func onPause() {
        guard isTranscribing, inTurn else { return }
        commitTurn()
        // Start a fresh recognition task so any trailing/late partial SFSpeech still
        // emits for the just-finished utterance can't re-trigger a turn and duplicate
        // the bubble. The new task only sees audio from this point on.
        restartTask()
    }

    private func commitTurn() {
        pauseTimer?.invalidate()
        pauseTimer = nil
        let final = turnText.trimmingCharacters(in: .whitespacesAndNewlines)
        let wasInTurn = inTurn
        resetTurnState()
        guard wasInTurn else { return }
        // Emit the full turn text (may be empty if nothing was recognized; the VM
        // drops it in that case so no stuck placeholder remains).
        onCaptionUpdate?(final, true)
    }

    private func resetTurnState() {
        inTurn = false
        turnText = ""
        committedFromTask = ""
        currentSegmentText = ""
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

    /// Cancel the current task and start a fresh one on the (still-running) engine.
    /// The turn continues — only the per-task segment cursor resets.
    private func restartTask() {
        restartTimer?.invalidate()
        retryTimer?.invalidate()
        retryTimer = nil
        // Fold the current segment into the turn BEFORE cancelling the task, so its
        // text survives the restart. (No-op when called after a natural task end,
        // which already folded it via handle().)
        accumulateSegment()
        teardownCurrentTask()   // bumps the token so the old task's final callback is ignored
        startNewTask()
        scheduleRestart()
    }

    /// Build the request + tap + recognition task for the current engine. If the
    /// recognizer is temporarily unavailable (Apple throttles it after heavy use),
    /// it retries shortly instead of silently dying.
    private func startNewTask() {
        guard isTranscribing, let speechRecognizer else { return }
        guard speechRecognizer.isAvailable else {
            print("[Transcriber] Recognizer unavailable; retrying in 1.5s")
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.startNewTask() }
            }
            return
        }

        currentSegmentText = ""   // new task = fresh segment; committedFromTask kept
        removeTap()
        let request = newRequest()
        recognitionRequest = request
        installTap(for: request)        // install the tap BEFORE starting the engine

        // If the tap didn't install (input not ready), don't start the engine/task.
        guard hasTap else {
            errorMessage = "Input audio belum siap. Coba lagi sebentar."
            return
        }

        // First run: start the engine now (tap is already installed). The restart
        // path keeps the already-running engine.
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                errorMessage = "Gagal memulai transkripsi: \(error.localizedDescription)"
                removeTap()
                return
            }
        }

        currentTaskToken += 1
        let token = currentTaskToken
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in self?.handle(result: result, error: error, token: token) }
        }
    }

    /// Tear down the current task/request and invalidate its pending callbacks.
    private func teardownCurrentTask() {
        currentTaskToken += 1   // any in-flight callback from the old task is now stale
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }

    // MARK: - Teardown

    private func teardown() {
        restartTimer?.invalidate()
        restartTimer = nil
        retryTimer?.invalidate()
        retryTimer = nil
        commitTurn()
        teardownCurrentTask()
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
