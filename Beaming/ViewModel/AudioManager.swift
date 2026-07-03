//
//  AudioManager.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import Foundation
import AVFoundation
import Observation

/// Manages microphone input and speech detection for hearing users.
@Observable
class AudioManager {
    
    /// Whether the user is currently speaking above the threshold.
    var isSpeaking: Bool = false
    
    /// Current audio level (RMS) for optional UI display.
    var audioLevel: Float = 0.0
    
    /// Whether the microphone is muted.
    var isMuted: Bool = false
    
    /// User-adjustable sensitivity (0.0 = most sensitive, 1.0 = least sensitive).
    /// Maps to an internal threshold range.
    var sensitivity: Float = 0.5 {
        didSet {
            updateThreshold()
        }
    }
    
    // MARK: - Calibration State
    
    /// Whether calibration is in progress.
    var isCalibrating: Bool = false
    
    /// Whether calibration has been completed.
    var isCalibrated: Bool = false
    
    /// Progress of calibration (0.0 to 1.0).
    var calibrationProgress: Float = 0.0
    
    /// The calibrated RMS average (set after calibration completes).
    var calibratedRMS: Float = 0.0
    
    private var audioEngine: AVAudioEngine?
    private var audioThreshold: Float = 0.015
    private var silenceTimer: Timer?
    private let silenceDuration: TimeInterval = 0.4  // Reduced for faster speaker handoff
    
    /// Number of consecutive frames above threshold required to trigger speaking.
    private let requiredConfirmationFrames: Int = 3
    private var consecutiveAboveThresholdFrames: Int = 0
    
    /// Threshold range: most sensitive (low) to least sensitive (high)
    private let minThreshold: Float = 0.005
    private let maxThreshold: Float = 0.06
    
    /// Calibration data collection
    private var calibrationSamples: [Float] = []
    private var calibrationTimer: Timer?
    private let calibrationDuration: TimeInterval = 5.0  // 5 seconds
    
    /// Callback when speaking state changes. Includes the current RMS level for loudness-based claim.
    var onSpeakingStateChanged: ((Bool, Float) -> Void)?
    
    /// Callback when calibration completes.
    var onCalibrationComplete: (() -> Void)?
    
    init() {
        updateThreshold()
    }
    
    // MARK: - Threshold
    
    private func updateThreshold() {
        if isCalibrated {
            // When calibrated, sensitivity slider adjusts around the calibrated value
            // sensitivity 0 = 30% of calibrated RMS (very sensitive)
            // sensitivity 0.5 = 50% of calibrated RMS (default)
            // sensitivity 1.0 = 80% of calibrated RMS (less sensitive)
            let factor = 0.3 + (0.5 * sensitivity)  // range 0.3 to 0.8
            audioThreshold = calibratedRMS * factor
        } else {
            // Fallback: manual threshold mapping
            audioThreshold = minThreshold + (maxThreshold - minThreshold) * sensitivity
        }
        print("[AudioManager] Threshold updated: \(audioThreshold)")
    }
    
    // MARK: - Calibration
    
    /// Start calibration: records audio for 3 seconds to measure the user's voice level.
    func startCalibration() {
        guard !isCalibrating else { return }
        
        isCalibrating = true
        isCalibrated = false
        calibrationProgress = 0.0
        calibrationSamples = []
        
        // Ensure audio engine is running
        startAudioEngine()
        
        // Start collecting samples for calibrationDuration seconds
        let startTime = Date()
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            let elapsed = Date().timeIntervalSince(startTime)
            self.calibrationProgress = Float(min(elapsed / self.calibrationDuration, 1.0))
            
            if elapsed >= self.calibrationDuration {
                timer.invalidate()
                self.finishCalibration()
            }
        }
    }
    
    private func finishCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        isCalibrating = false
        
        // Calculate average RMS from collected samples (only above-noise samples)
        let noiseSamples = calibrationSamples.filter { $0 > 0.002 }  // Filter out silence/noise floor
        
        if noiseSamples.count > 10 {
            let avg = noiseSamples.reduce(0, +) / Float(noiseSamples.count)
            calibratedRMS = avg
            isCalibrated = true
            
            // Set threshold to 50% of calibrated average (default sensitivity = 0.5)
            updateThreshold()
            
            print("[AudioManager] Calibration complete! Average RMS: \(avg), Threshold: \(audioThreshold)")
        } else {
            // Not enough voice data — user was too quiet or didn't speak
            calibratedRMS = 0
            isCalibrated = false
            print("[AudioManager] Calibration failed — not enough voice data")
        }
        
        calibrationProgress = 1.0
        onCalibrationComplete?()
    }
    
    /// Cancel calibration.
    func cancelCalibration() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        isCalibrating = false
        calibrationProgress = 0.0
        calibrationSamples = []
    }
    
    // MARK: - Permission
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // MARK: - Audio Engine
    
    private func startAudioEngine() {
        // Don't start if already running
        guard audioEngine == nil else { return }
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // Configure audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("[AudioManager] Audio session error: \(error)")
            return
        }
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
            print("[AudioManager] Audio engine started")
        } catch {
            print("[AudioManager] Failed to start audio engine: \(error)")
        }
    }
    
    func startListening() {
        guard !isMuted else { return }
        startAudioEngine()
        print("[AudioManager] Started listening (threshold: \(audioThreshold))")
    }
    
    func stopListening() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        isSpeaking = false
        audioLevel = 0.0
        consecutiveAboveThresholdFrames = 0
        print("[AudioManager] Stopped listening")
    }
    
    func toggleMute() {
        isMuted.toggle()
        if isMuted {
            stopListening()
        } else {
            startListening()
        }
    }
    
    // MARK: - Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += channelData[i] * channelData[i]
        }
        let rms = sqrt(sum / Float(frameLength))
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.audioLevel = rms
            
            // If calibrating, collect samples instead of processing speech
            if self.isCalibrating {
                self.calibrationSamples.append(rms)
                return
            }
            
            // Normal speech detection
            if rms > self.audioThreshold {
                // Frame is above threshold
                self.consecutiveAboveThresholdFrames += 1
                
                // Cancel silence timer since we're hearing sound
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
                
                // Only trigger speaking after N consecutive frames (multi-frame confirmation)
                if !self.isSpeaking && self.consecutiveAboveThresholdFrames >= self.requiredConfirmationFrames {
                    self.isSpeaking = true
                    self.onSpeakingStateChanged?(true, rms)
                }
            } else {
                // Below threshold — reset consecutive counter
                self.consecutiveAboveThresholdFrames = 0
                
                // Start silence timer if currently speaking
                if self.isSpeaking && self.silenceTimer == nil {
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceDuration, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        self.isSpeaking = false
                        self.onSpeakingStateChanged?(false, 0.0)
                        self.silenceTimer = nil
                    }
                }
            }
        }
    }
    
    deinit {
        stopListening()
    }
}
