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
    
    private var audioEngine: AVAudioEngine?
    private let audioThreshold: Float = 0.008
    private var silenceTimer: Timer?
    private let silenceDuration: TimeInterval = 2.0
    
    /// Callback when speaking state changes (true = started speaking, false = stopped after 2s silence).
    var onSpeakingStateChanged: ((Bool) -> Void)?
    
    // MARK: - Permission
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    // MARK: - Audio Engine
    
    func startListening() {
        guard !isMuted else { return }
        
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
            print("[AudioManager] Started listening")
        } catch {
            print("[AudioManager] Failed to start audio engine: \(error)")
        }
    }
    
    func stopListening() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        silenceTimer?.invalidate()
        silenceTimer = nil
        isSpeaking = false
        audioLevel = 0.0
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
            
            if rms > self.audioThreshold {
                // Speaking detected
                self.silenceTimer?.invalidate()
                self.silenceTimer = nil
                
                if !self.isSpeaking {
                    self.isSpeaking = true
                    self.onSpeakingStateChanged?(true)
                }
            } else {
                // Below threshold — start silence timer if currently speaking
                if self.isSpeaking && self.silenceTimer == nil {
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: self.silenceDuration, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        self.isSpeaking = false
                        self.onSpeakingStateChanged?(false)
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
