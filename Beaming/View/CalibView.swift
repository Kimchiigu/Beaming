//
//  CalibView.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 12/07/26.
//

import SwiftUI

/// Voice calibration UI (new hi-fi). Pure presentation — all logic lives in the
/// shared `MeetingViewModel` / `AudioManager` (start, progress, audio level, done),
/// so the real 3.5-second calibration still drives this screen.
struct CalibView: View {

    let viewModel: MeetingViewModel

    private let mainPurple = Color(red: 0x71 / 255, green: 0x5D / 255, blue: 0xD1 / 255)

    /// Waveform + progress bar stay visible while recording OR after done.
    private var isCalibrating: Bool {
        viewModel.audioManager.isCalibrating || viewModel.isCalibrationDone
    }

    private var isDone: Bool { viewModel.isCalibrationDone }

    /// Live waveform bars derived from the current mic level (same approach as the
    /// previous calibration screen).
    private var waveformHeights: [CGFloat] {
        let level = max(0, min(1, CGFloat(viewModel.audioManager.audioLevel) * 18))
        return CalibModel.initialWaveformHeights.map { max(8, $0 * (0.4 + level)) }
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header Image
            Image("ImgCal")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()
                .ignoresSafeArea(edges: .top)

            // MARK: - Content
            VStack(spacing: 24) {

                if isCalibrating {
                    // Waveform tetap tampil selama recording maupun setelah done
                    CalibWaveformView(
                        heights: waveformHeights,
                        mainColor: mainPurple
                    )
                    .padding(.top, 32)
                } else {
                    VStack(spacing: 8) {
                        Text(CalibModel.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)

                        Text(CalibModel.subtitle)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 32)
                }

                if isDone {
                    // Kalibrasi berhasil
                    VStack(spacing: 8) {
                        Text(CalibModel.successTitle)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)

                        Text(CalibModel.successSubtitle)
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                    }
                } else {
                    Text(CalibModel.calibrationSentence)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(mainPurple)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .background(mainPurple.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)
                }

                Spacer()

                if isCalibrating {
                    // Current phase: downloading models → recording voice → enrolling.
                    Text(viewModel.audioManager.calibrationPhase.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(mainPurple)
                        .padding(.bottom, 8)

                    // Progress bar (real progress from AudioManager, 0...1)
                    ProgressBarView(progress: CGFloat(viewModel.audioManager.calibrationProgress), mainColor: mainPurple)
                        .frame(height: 12)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                } else {
                    Button(action: {
                        viewModel.startCalibration()
                    }) {
                        Text(CalibModel.buttonTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .glassEffect(.regular.tint(mainPurple).interactive())
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
        .edgesIgnoringSafeArea(.top)
        .background(Color.white)
        .overlay(alignment: .topLeading) {
            // Leave calibration → back to Home. Default-sized glass button (iOS 26).
            Button {
                viewModel.leaveRoom()
            } label: {
                Image(systemName: "chevron.backward")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: .circle)
            }
            .padding(.leading, 12)
            .padding(.top, 8)
        }
    }
}

// MARK: - Live Audio Waveform (renders heights supplied by the parent)
struct CalibWaveformView: View {
    let heights: [CGFloat]
    let mainColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<heights.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(mainColor.opacity(0.35))
                    .frame(width: 8, height: heights[index])
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Progress Bar (renders progress supplied by the parent)
struct ProgressBarView: View {
    let progress: CGFloat
    let mainColor: Color

    private let trackColor = Color(red: 0xD9 / 255, green: 0xD9 / 255, blue: 0xD9 / 255)

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)

                Capsule()
                    .fill(mainColor)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
    }
}

#Preview {
    CalibView(
        viewModel: MeetingViewModel(
            localUser: User(name: "Preview"),
            networkManager: NetworkManager(),
            asHost: true
        )
    )
}
