//
//  CalibViewModel.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 12/07/26.
//

import SwiftUI
import Combine

final class CalibViewModel: ObservableObject {

    // MARK: - Published state (dibaca oleh CalibView)
    @Published private(set) var stage: CalibStage = .idle
    @Published private(set) var progress: CGFloat = 0
    @Published private(set) var waveformHeights: [CGFloat] = CalibModel.initialWaveformHeights

    private var waveformTimer: Timer?

    // MARK: - Computed helper untuk View (biar View tetap bodoh, tinggal baca Bool)
    var isCalibrating: Bool {
        stage == .recording || stage == .done
    }

    var isDone: Bool {
        stage == .done
    }

    // MARK: - Kalibrasi flow (dummy, belum ada rekaman audio asli)
    func startCalibration() {
        guard stage == .idle else { return }

        stage = .recording
        progress = 0
        startWaveformAnimation()

        withAnimation(.linear(duration: CalibModel.calibrationDuration)) {
            progress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + CalibModel.calibrationDuration) { [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.stage = .done
            }
            self.stopWaveformAnimation()
        }
    }

    // MARK: - Live Audio Waveform (dummy animation, belum terhubung ke rekaman audio asli)
    private func startWaveformAnimation() {
        waveformTimer?.invalidate()
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                self.waveformHeights = self.waveformHeights.map { _ in CGFloat.random(in: 12...56) }
            }
        }
    }

    private func stopWaveformAnimation() {
        waveformTimer?.invalidate()
        waveformTimer = nil
    }

    deinit {
        waveformTimer?.invalidate()
    }
}
