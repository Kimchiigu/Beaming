//
//  QRCodeDisplayView.swift
//  Beaming
//
//  Created by Beaming Team, July 2026.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

/// Sheet shown when user taps "Lihat Kode QR" from the ... menu in MeetingView.
/// Displays a shareable QR code encoding the Bonjour service name.
struct QRCodeDisplayView: View {
    let qrCodeString: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .frame(width: 36, height: 36)
                        .background(Color(red: 0.93, green: 0.93, blue: 0.93))
                        .clipShape(Circle())
                }

                Spacer()

                Text("Kode QR")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)

            // MARK: Subtitle
            Text("Tunjukkan kode QR ke temanmu untuk ikuti diskusi")
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 32)

            // MARK: QR Code image
            if let qrImage = generateQRCode(from: qrCodeString) {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.91, green: 0.91, blue: 0.91))
                    .frame(width: 240, height: 240)
                    .overlay(
                        Text("QR tidak tersedia")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    )
            }

            Spacer()
        }
        .background(Color.white)
    }

    // MARK: - QR Generation

    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        let data = Data(string.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    QRCodeDisplayView(qrCodeString: "Alex::::550E8400-E29B-41D4-A716-446655440000")
}
