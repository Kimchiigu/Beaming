//
//  FlashlightManager.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import AVFoundation
import Foundation

/// Controls the device's hardware flashlight (torch).
/// When activated, it smoothly fades in and out continuously like a beacon at max brightness.
class FlashlightManager {
    
    private var beaconTimer: Timer?
    private var isWaiting: Bool = false
    private var waitTime: TimeInterval = 0.0
    private var pulseProgress: Double = 0.0
    private var pulsingUp: Bool = true
    
    /// Start or stop the continuous beacon effect.
    func setFlashlight(on: Bool) {
        if on {
            startBeacon()
        } else {
            stopBeacon()
        }
    }
    
    private func startBeacon() {
        guard beaconTimer == nil else { return } // Already running
        
        isWaiting = false
        waitTime = 0.0
        pulseProgress = 0.0
        pulsingUp = true
        
        // Immediately start the first blink
        beaconTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.isWaiting {
                self.waitTime += 0.05
                if self.waitTime >= 6.0 {
                    // Done waiting 6 seconds, start next blink
                    self.isWaiting = false
                    self.waitTime = 0.0
                    self.pulsingUp = true
                    self.pulseProgress = 0.0
                }
            } else {
                // Pulse speed: 0.5s to fade in, 0.5s to fade out (1 second total blink)
                if self.pulsingUp {
                    self.pulseProgress += 0.1
                    if self.pulseProgress >= 1.0 {
                        self.pulseProgress = 1.0
                        self.pulsingUp = false
                    }
                } else {
                    self.pulseProgress -= 0.1
                    if self.pulseProgress <= 0.0 {
                        // Finished fading out, start waiting
                        self.pulseProgress = 0.0
                        self.isWaiting = true
                        self.setTorch(level: 0.0) // Turn off completely
                        return
                    }
                }
                
                // Smooth S-curve easing using cosine for natural fade in/out
                let smoothed = (1.0 - cos(self.pulseProgress * .pi)) / 2.0
                let level = 0.05 + (smoothed * 0.95)
                self.setTorch(level: Float(level))
            }
        }
    }
    
    /// Stop the pulsing and turn off the torch.
    func stopBlinking() {
        // Keep the old method name so callers don't need to change if they used it directly, 
        // though setFlashlight is the primary API.
        stopBeacon()
    }
    
    private func stopBeacon() {
        beaconTimer?.invalidate()
        beaconTimer = nil
        setTorch(level: 0.0) // 0.0 turns it off
    }
    
    /// Direct torch control with specific brightness level.
    private func setTorch(level: Float) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch
        else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            if level <= 0.0 {
                device.torchMode = .off
            } else {
                // Ensure level is within valid bounds [0.01, 1.0] to avoid crash
                try device.setTorchModeOn(level: min(max(level, 0.01), 1.0))
            }
            device.unlockForConfiguration()
        } catch {
            print("[FlashlightManager] Torch error: \(error)")
        }
    }
    
    deinit {
        stopBeacon()
    }
}
