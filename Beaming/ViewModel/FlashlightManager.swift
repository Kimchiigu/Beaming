//
//  FlashlightManager.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import AVFoundation
import Foundation

/// Controls the device's hardware flashlight (torch) with blinking support.
class FlashlightManager {
    
    private var blinkTimer: Timer?
    private var isCurrentlyOn: Bool = false
    private let blinkInterval: TimeInterval = 0.35
    
    /// Start blinking the flashlight.
    func startBlinking() {
        stopBlinking()
        
        // Turn on immediately
        setTorch(on: true)
        isCurrentlyOn = true
        
        // Start blink loop
        blinkTimer = Timer.scheduledTimer(withTimeInterval: blinkInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.isCurrentlyOn.toggle()
            self.setTorch(on: self.isCurrentlyOn)
        }
    }
    
    /// Stop blinking and turn off the flashlight.
    func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        isCurrentlyOn = false
        setTorch(on: false)
    }
    
    /// Turn the flashlight on or off (single action, no blinking).
    func setFlashlight(on: Bool) {
        if on {
            startBlinking()
        } else {
            stopBlinking()
        }
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
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
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
