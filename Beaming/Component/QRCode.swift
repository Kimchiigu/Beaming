//
//  QRCode.swift
//  Beaming
//
//  QR generation + a reusable QR code view + the room share sheet.
//

import SwiftUI
import CoreImage.CIFilterBuiltins
import UIKit

enum QRGenerator {
    static func generate(from string: String, scale: CGFloat = 10) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// Renders a QR code for the given string on a rounded white card.
struct QRCodeView: View {
    let string: String
    var side: CGFloat = 200

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.clear
            }
        }
        .frame(width: side, height: side)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .onAppear { image = QRGenerator.generate(from: string) }
    }
}

/// Bottom sheet showing the room's join-QR so guests can scan it.
/// Opens at half height (medium detent), draggable to full.
struct QRShareSheet: View {
    let code: String
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            ZStack {
                Text("Kode QR")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                HStack {
                    GlassIconButton(systemName: "xmark", action: onClose)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)

            Text("Tunjukkan kode QR ke temanmu untuk ikuti diskusi.\nBisa scan dari kamera atau app Beaming.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)

            QRCodeView(string: code, side: 200)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.black)
        .background(Color.white)
        .presentationDetents([.medium, .large])
    }
}
