//
//  CalibrationView.swift
//  Beaming
//
//  Created by Beaming Team on 03/07/26.
//

import SwiftUI

/// Full-screen overlay for voice calibration before a meeting starts.
/// The user speaks a phrase so the app can auto-set their mic threshold.
struct CalibrationView: View {
    @State var viewModel: MeetingViewModel
    
    /// The phrase for the user to read aloud.
    private let calibrationPhrase = "Hello everyone, I am ready to start this meeting."
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: viewModel.isCalibrationDone ? "checkmark.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                
                // Title
                Text(viewModel.isCalibrationDone ? "Calibration Complete!" : "Voice Calibration")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Instructions
                if !viewModel.audioManager.isCalibrating && !viewModel.isCalibrationDone {
                    VStack(spacing: 16) {
                        Text("Please read the phrase below\nin your normal speaking voice.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        // Phrase card
                        Text("\"\(calibrationPhrase)\"")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 8)
                    }
                }
                
                // During calibration: progress + live level
                if viewModel.audioManager.isCalibrating {
                    VStack(spacing: 20) {
                        Text("Listening... speak now")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.9))
                        
                        // Phrase reminder
                        Text("\"\(calibrationPhrase)\"")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                        
                        // Progress bar
                        ProgressView(value: Double(viewModel.audioManager.calibrationProgress))
                            .tint(.white)
                            .scaleEffect(y: 2)
                            .padding(.horizontal, 40)
                        
                        // Live audio level indicator
                        HStack(spacing: 3) {
                            ForEach(0..<20, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Float(i) / 20.0 < viewModel.audioManager.audioLevel * 15 ? Color.white : Color.white.opacity(0.15))
                                    .frame(width: 8, height: 24)
                            }
                        }
                    }
                }
                
                // After calibration: success message
                if viewModel.isCalibrationDone {
                    VStack(spacing: 8) {
                        Text("Your microphone is ready.")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                        Text("Entering meeting...")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                // Buttons
                if !viewModel.audioManager.isCalibrating && !viewModel.isCalibrationDone {
                    VStack(spacing: 12) {
                        Button {
                            viewModel.startCalibration()
                        } label: {
                            Text("Start Calibration")
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    let user = User(name: "Preview", role: .hearing)
    let vm = MeetingViewModel(localUser: user, networkManager: NetworkManager(), asHost: true)
    CalibrationView(viewModel: vm)
}
