//
//  CalibModel.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 12/07/26.
//

import Foundation
import CoreGraphics

// MARK: - Tahapan kalibrasi suara
enum CalibStage {
    case idle        // belum mulai, masih di tampilan awal
    case recording    // sedang "merekam" (dummy, belum ada rekaman audio asli)
    case done         // sudah selesai 5 detik, tampil "Berhasil"
}

// MARK: - Data statis untuk layar kalibrasi
struct CalibModel {
    static let title = "Kalibrasi suara"
    static let subtitle = "Letakkan HP di depan Anda dan\nucapkan kalimat berikut:"
    static let calibrationSentence = "\"Halo semua, saya siap untuk\nmengikuti diskusi ini.\""

    static let successTitle = "Berhasil"
    static let successSubtitle = "Mikrofon kamu sudah siap!"

    static let buttonTitle = "Mulai Kalibrasi"

    // Durasi proses kalibrasi (dummy)
    static let calibrationDuration: Double = 5.0

    // Nilai awal bar waveform (dummy, sebelum dianimasikan)
    static let initialWaveformHeights: [CGFloat] = [18, 32, 48, 26, 56, 30, 44, 20, 34]
}
