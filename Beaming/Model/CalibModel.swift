//
//  CalibModel.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 12/07/26.
//

import Foundation
import CoreGraphics

// MARK: - Tahapan pendaftaran suara (owner enrollment)
enum CalibStage {
    case idle        // belum mulai, masih di tampilan awal
    case recording   // sedang merekam suara pemilik
    case done        // sudah selesai, suara terdaftar
}

// MARK: - Data statis untuk layar pendaftaran suara
struct CalibModel {
    static let title = "Daftarkan suaramu"
    static let subtitle = "Letakkan HP di dekatmu dan\nbacakan kalimat berikut dengan suaramu sendiri:"
    static let calibrationSentence = "\"Halo semua, saya siap untuk\nmengikuti diskusi ini.\""

    static let successTitle = "Berhasil"
    static let successSubtitle = "Suara kamu berhasil terdaftar!"

    static let buttonTitle = "Daftar Suara"

    // Durasi rekaman pendaftaran (detik)
    static let calibrationDuration: Double = 6.0

    // Nilai awal bar waveform (sebelum dianimasikan oleh level mic)
    static let initialWaveformHeights: [CGFloat] = [18, 32, 48, 26, 56, 30, 44, 20, 34]
}
