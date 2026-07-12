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
        NavigationStack {
            VStack(spacing: 18) {
                Text("Tunjukkan kode QR ke temanmu untuk ikuti diskusi")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 44)
                    .padding(.top, 8)

                QRCodeView(string: code, side: 200)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.black)
            .background(Color.white)
            .navigationTitle("Kode QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
