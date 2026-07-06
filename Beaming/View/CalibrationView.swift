//
//  CalibrationView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//  Redesigned for Hi-Fi by Beaming Team, July 2026.
//

import SwiftUI

/// Full-screen calibration overlay shown at the start of every meeting.
/// Three states: idle → active (listening) → done.
struct CalibrationView: View {
    var viewModel: MeetingViewModel

    // Waveform animation
    @State private var wavePhase: CGFloat = 0
    @State private var waveTimer: Timer? = nil

    var body: some View {
        ZStack {
            // MARK: Background
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                // Top-right mint blob
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.58, green: 0.95, blue: 0.81).opacity(0.50), .clear],
                            center: .center, startRadius: 0, endRadius: 240
                        )
                    )
                    .frame(width: 480, height: 480)
                    .offset(x: geo.size.width - 140, y: -100)

                // Bottom-left yellow-green blob
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.87, green: 0.93, blue: 0.60).opacity(0.40), .clear],
                            center: .center, startRadius: 0, endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -140, y: geo.size.height - 260)
            }
            .ignoresSafeArea()

            // MARK: Content
            if viewModel.isCalibrationDone {
                calibrationDoneView
            } else if viewModel.audioManager.isCalibrating {
                calibrationActiveView
            } else {
                calibrationIdleView
            }
        }
    }

    // MARK: - Idle State

    private var calibrationIdleView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Mascot
            BeamingMascot(happy: false)
                .frame(width: 130, height: 130)
                .padding(.bottom, 28)

            // Heading
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(Color(red: 0.0, green: 0.58, blue: 0.93))
                Text("Kalibrasi suara")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
            .padding(.bottom, 12)

            Text("Baca kalimat di bawah ini dengan suara normal kamu")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.bottom, 32)

            // Phrase card
            PhraseCard(phrase: "\"Halo semua, saya siap untuk mengikuti diskusi ini\"")
                .padding(.horizontal, 28)
                .padding(.bottom, 48)

            Spacer()

            // CTA button
            Button {
                startCalibration()
            } label: {
                Text("Mulai Kalibrasi")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 0.41, green: 0.73, blue: 0.61))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 52)
        }
    }

    // MARK: - Active State

    private var calibrationActiveView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated mascot (slightly bouncing)
            BeamingMascot(happy: false)
                .frame(width: 130, height: 130)
                .scaleEffect(1.0 + sin(wavePhase) * 0.03)
                .padding(.bottom, 28)

            Text("Sedang mendengarkan…")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                .padding(.bottom, 6)

            Text("silahkan mulai berbicara")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                .padding(.bottom, 32)

            // Phrase card
            PhraseCard(phrase: "\"Halo semua, saya siap untuk mengikuti diskusi ini\"")
                .padding(.horizontal, 28)
                .padding(.bottom, 32)

            // Waveform bars
            WaveformBars(
                audioLevel: viewModel.audioManager.audioLevel,
                phase: wavePhase
            )
            .frame(height: 64)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)

            // Progress bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Menganalisa suaramu…")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                    Spacer()
                    Text("\(Int(viewModel.audioManager.calibrationProgress * 100))%")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(red: 0.41, green: 0.73, blue: 0.61))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.90, green: 0.93, blue: 0.91))
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 0.41, green: 0.73, blue: 0.61))
                            .frame(width: geo.size.width * CGFloat(viewModel.audioManager.calibrationProgress), height: 6)
                            .animation(.linear(duration: 0.1), value: viewModel.audioManager.calibrationProgress)
                    }
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 28)

            Spacer()
        }
        .onAppear { startWaveTimer() }
        .onDisappear { stopWaveTimer() }
    }

    // MARK: - Done State

    private var calibrationDoneView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Happy mascot
            BeamingMascot(happy: true)
                .frame(width: 140, height: 140)
                .padding(.bottom, 28)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.65), value: viewModel.isCalibrationDone)

            Text("Kalibrasi suara selesai!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                .padding(.bottom, 10)

            Text("Mikrophone kamu sudah siap")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))

            Spacer()
        }
    }

    // MARK: - Helpers

    private func startCalibration() {
        startWaveTimer()
        viewModel.startCalibration()
    }

    private func startWaveTimer() {
        waveTimer?.invalidate()
        waveTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            wavePhase += 0.15
        }
    }

    private func stopWaveTimer() {
        waveTimer?.invalidate()
        waveTimer = nil
    }
}

// MARK: - Phrase Card

struct PhraseCard: View {
    let phrase: String

    var body: some View {
        Text(phrase)
            .font(.system(size: 17, weight: .medium))
            .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Waveform Bars

struct WaveformBars: View {
    let audioLevel: Float
    let phase: CGFloat

    private let barCount = 20
    private let minBarHeight: CGFloat = 6
    private let maxBarHeight: CGFloat = 56

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<barCount, id: \.self) { index in
                let position = CGFloat(index) / CGFloat(barCount)
                let waveHeight = sin(phase + position * .pi * 2) * 0.5 + 0.5
                let levelBoost = CGFloat(min(audioLevel * 12, 1.0))
                let barHeight = minBarHeight + (maxBarHeight - minBarHeight) * waveHeight * max(levelBoost, 0.25)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(red: 0.41, green: 0.73, blue: 0.61))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight)
                    .animation(.easeInOut(duration: 0.08), value: barHeight)
            }
        }
    }
}
