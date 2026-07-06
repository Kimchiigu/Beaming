//
//  FlashlightManager.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import AVFoundation
import Foundation

/// Controls the device's hardware flashlight (torch).
/// When activated, does 3 quick blinks then turns off (less distracting).
class FlashlightManager {
    
    private var blinkTimer: Timer?
    private var blinkCount: Int = 0
    private let totalBlinks: Int = 3
    private let blinkOnDuration: TimeInterval = 0.15
    private let blinkOffDuration: TimeInterval = 0.10
    
    /// Start the 3-blink sequence (called when speaker lock is acquired).
    func setFlashlight(on: Bool) {
        if on {
            startBlinkSequence()
        } else {
            stopBlinking()
        }
    }
    
    /// 3 quick blinks: ON-OFF-ON-OFF-ON-OFF, then done.
    private func startBlinkSequence() {
        stopBlinking()
        blinkCount = 0
        
        // Immediately turn on for first blink
        setTorch(on: true)
        blinkCount = 1
        
        // Schedule alternating on/off
        var step = 0
        let totalSteps = (totalBlinks * 2) - 1  // ON-off-ON-off-ON = 5 steps (already did first ON)
        
        blinkTimer = Timer.scheduledTimer(withTimeInterval: blinkOnDuration, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            step += 1
            
            if step > totalSteps {
                // Done — turn off and stop
                self.setTorch(on: false)
                timer.invalidate()
                self.blinkTimer = nil
                return
            }
            
            // Even steps = OFF, odd steps = ON
            let isOn = (step % 2 == 0)
            self.setTorch(on: isOn)
        }
    }
    
    /// Stop any active blinking and turn off the torch.
    func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        blinkCount = 0
        setTorch(on: false)
    }
    
    /// Direct torch control.
    private func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch
        else {
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            if on {
                // Lowered from max so the blink is noticeable but not blinding.
                try device.setTorchModeOn(level: 0.5)
            }
            device.unlockForConfiguration()
        } catch {
            print("[FlashlightManager] Torch error: \(error)")
        }
    }
    
    deinit {
        stopBlinking()
    }
}
