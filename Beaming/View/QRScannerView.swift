//
//  QRScannerView.swift
//  Beaming
//
//  Created by Beaming Team, July 2026.
//

import SwiftUI
import AVFoundation

/// Sheet that opens the camera to scan a Beaming QR code.
struct QRScannerView: View {
    var onScanned: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scannerError: String? = nil

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

                Text("Scan QR Code")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Spacer()

                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 24)

            // MARK: Scanner viewport
            ZStack {
                if let error = scannerError {
                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.7))
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.5))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 0.93, green: 0.97, blue: 0.93))
                } else {
                    QRCodeScannerRepresentable(
                        onScanned: { value in
                            onScanned(value)
                        },
                        onError: { message in
                            scannerError = message
                        }
                    )
                }

                // Corner bracket overlays
                ScannerFrameOverlay()
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(Color.white)
    }
}

// MARK: - Scanner Frame Overlay

struct ScannerFrameOverlay: View {
    let cornerLength: CGFloat = 28
    let lineWidth: CGFloat = 4
    let cornerRadius: CGFloat = 8
    let color: Color = Color(red: 0.41, green: 0.73, blue: 0.61)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Top-left
                Path { path in
                    path.move(to: CGPoint(x: 16, y: 16 + cornerLength))
                    path.addLine(to: CGPoint(x: 16, y: 16 + cornerRadius))
                    path.addQuadCurve(to: CGPoint(x: 16 + cornerRadius, y: 16), control: CGPoint(x: 16, y: 16))
                    path.addLine(to: CGPoint(x: 16 + cornerLength, y: 16))
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Top-right
                Path { path in
                    path.move(to: CGPoint(x: w - 16 - cornerLength, y: 16))
                    path.addLine(to: CGPoint(x: w - 16 - cornerRadius, y: 16))
                    path.addQuadCurve(to: CGPoint(x: w - 16, y: 16 + cornerRadius), control: CGPoint(x: w - 16, y: 16))
                    path.addLine(to: CGPoint(x: w - 16, y: 16 + cornerLength))
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Bottom-left
                Path { path in
                    path.move(to: CGPoint(x: 16, y: h - 16 - cornerLength))
                    path.addLine(to: CGPoint(x: 16, y: h - 16 - cornerRadius))
                    path.addQuadCurve(to: CGPoint(x: 16 + cornerRadius, y: h - 16), control: CGPoint(x: 16, y: h - 16))
                    path.addLine(to: CGPoint(x: 16 + cornerLength, y: h - 16))
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

                // Bottom-right
                Path { path in
                    path.move(to: CGPoint(x: w - 16 - cornerLength, y: h - 16))
                    path.addLine(to: CGPoint(x: w - 16 - cornerRadius, y: h - 16))
                    path.addQuadCurve(to: CGPoint(x: w - 16, y: h - 16 - cornerRadius), control: CGPoint(x: w - 16, y: h - 16))
                    path.addLine(to: CGPoint(x: w - 16, y: h - 16 - cornerLength))
                }
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
        }
    }
}

// MARK: - AVFoundation QR Scanner

struct QRCodeScannerRepresentable: UIViewRepresentable {
    var onScanned: (String) -> Void
    var onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onError: onError)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let coordinator = context.coordinator

        AVAudioApplication.requestRecordPermission { _ in }

        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                if granted {
                    coordinator.setupSession(in: view)
                } else {
                    onError("Akses kamera tidak diizinkan. Aktifkan di Pengaturan > Privasi > Kamera.")
                }
            }
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) { }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onScanned: (String) -> Void
        var onError: (String) -> Void
        var session: AVCaptureSession?
        var previewLayer: AVCaptureVideoPreviewLayer?
        var hasScanned = false

        init(onScanned: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onScanned = onScanned
            self.onError = onError
        }

        func setupSession(in view: UIView) {
            let session = AVCaptureSession()
            self.session = session

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                onError("Kamera tidak tersedia di perangkat ini.")
                return
            }

            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.bounds
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }

            // Update frame when view bounds change
            DispatchQueue.main.async {
                previewLayer.frame = view.bounds
            }
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !hasScanned,
                  let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = metadataObject.stringValue else { return }
            hasScanned = true
            session?.stopRunning()
            onScanned(value)
        }
    }
}

#Preview {
    QRScannerView { code in
        print("Scanned: \(code)")
    }
}
