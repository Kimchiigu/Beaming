//
//  CalibrationView.swift
//  Beaming
//
//  3-step voice calibration: Intro → (active) Loading → Done.
//  Wraps the existing AudioManager 3.5-second RMS calibration.
//

import SwiftUI

struct CalibrationView: View {
    @State var viewModel: MeetingViewModel

    private let phrase = "Halo semua, saya siap untuk mengikuti diskusi ini"

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            BlobShape()
                .fill(BeamingPalette.blob)
                .frame(width: 360, height: 360)
                .blur(radius: 50)
                .opacity(0.4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 150, y: -170)
            BlobShape()
                .fill(BeamingPalette.blob)
                .frame(width: 360, height: 360)
                .blur(radius: 50)
                .opacity(0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -150, y: 200)

            VStack(spacing: 0) {
                calibrationToolbar

                HStack(spacing: 9) {
                    Image(systemName: "lines.measurement.horizontal")
                        .font(.system(size: 22))
                    Text("Kalibrasi suara")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.26)
                }
                .foregroundStyle(.black)
                .padding(.top, 28)

                Image(viewModel.isCalibrationDone ? "MascotDone" : "MascotCalibrate")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                Spacer(minLength: 12)

                if viewModel.isCalibrationDone {
                    doneState
                } else if viewModel.audioManager.isCalibrating {
                    loadingState
                } else {
                    introState
                }

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .foregroundStyle(.black)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Toolbar

    private var calibrationToolbar: some View {
        ZStack {
            Text("Kalibrasi")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.43)
            HStack {
                Button {
                    viewModel.leaveRoom()
                } label: {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .frame(height: 52)
    }

    // MARK: - Intro

    private var introState: some View {
        VStack(spacing: 20) {
            VStack(spacing: 18) {
                Text("Baca kalimat di bawah ini dengan suara normal kamu")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.31)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.black)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(BeamingPalette.green)
                        .frame(width: 4)
                    Text("\u{201C}\(phrase)\u{201D}")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.26)
                        .foregroundStyle(BeamingPalette.green)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                }
                .background(Color(hex: 0xF6F6F6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                WaveformView(level: 0, isLive: false)
            }
            .padding(20)
            .beamingCard()

            Button("Mulai Kalibrasi") {
                viewModel.startCalibration()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    // MARK: - Loading

    private var loadingState: some View {
        VStack(spacing: 18) {
            Text("Mendengarkan… ucapkan kalimatnya")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.black)

            ProgressView(value: Double(viewModel.audioManager.calibrationProgress))
                .tint(BeamingPalette.green)

            WaveformView(level: viewModel.audioManager.audioLevel, isLive: true)

            Text("\u{201C}\(phrase)\u{201D}")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .beamingCard()
    }

    // MARK: - Done

    private var doneState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(BeamingPalette.green)
            Text("Kalibrasi Selesai!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.black)
            Text("Mikrofon kamu sudah siap.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Waveform

private struct WaveformView: View {
    let level: Float
    let isLive: Bool

    private let heights: [CGFloat] = [30, 16, 48, 16, 30, 16, 30]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(heights.indices, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6)
                    .fill(BeamingPalette.waveform)
                    .frame(width: 8, height: barHeight(i))
            }
        }
        .frame(height: 60)
    }

    private func barHeight(_ i: Int) -> CGFloat {
        guard isLive else { return heights[i % heights.count] }
        let normalized = max(0, min(1, CGFloat(level) * 18))
        let base = heights[i % heights.count]
        return max(8, base * (0.4 + normalized))
    }
}

#Preview {
    CalibrationView(
        viewModel: MeetingViewModel(
            localUser: User(name: "Preview"),
            networkManager: NetworkManager(),
            asHost: true
        )
    )
}
