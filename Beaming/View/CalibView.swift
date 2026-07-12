//
//  CalibView.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 12/07/26.
//

import SwiftUI

struct CalibView: View {

    @StateObject private var viewModel = CalibViewModel()

    private let mainPurple = Color(red: 0x71 / 255, green: 0x5D / 255, blue: 0xD1 / 255)

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header Image
            Image("ImgCal")

            // MARK: - Content
            VStack(spacing: 24) {

                if viewModel.isCalibrating {
                    // Waveform tetap tampil selama recording maupun setelah done
                    CalibWaveformView(
                        heights: viewModel.waveformHeights,
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

                if viewModel.isDone {
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

                if viewModel.isCalibrating {
                    // Progress Bar (menggantikan button, jalan sesuai CalibViewModel)
                    ProgressBarView(progress: viewModel.progress, mainColor: mainPurple)
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
                            .background(mainPurple)
                            .cornerRadius(28)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
        .edgesIgnoringSafeArea(.top)
        .background(Color.white)
    }
}

// MARK: - Live Audio Waveform (UI statis/dummy, hanya render dari data yang diberikan ViewModel)
struct CalibWaveformView: View {
    let heights: [CGFloat]
    let mainColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<heights.count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(mainColor.opacity(0.35))
                    .frame(width: 5, height: heights[index])
            }
        }
        .frame(height: 60)
    }
}

// MARK: - Progress Bar (murni render, nilai progress dikontrol dari ViewModel)
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
    CalibView()
}
