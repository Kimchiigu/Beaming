//
//  QRScannerView.swift
//  Beaming
//
//  Live camera QR scanner used by a guest to join a host's room.
//

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    let onScan: (String) -> Void
    let onClose: () -> Void

    @State private var cameraAuthorized: Bool? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraAuthorized == true {
                QRScannerRepresentable(onScan: onScan)
                    .ignoresSafeArea()
            } else if cameraAuthorized == false {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white.opacity(0.6))
                    Text("Akses kamera diperlukan untuk memindai QR.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding()
            }

            VStack {
                ZStack {
                    Text("Scan QR")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    HStack {
                        GlassIconButton(systemName: "xmark", tint: .white, action: onClose)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.9), lineWidth: 4)
                    .frame(width: 247, height: 247)

                Spacer()

                Text("Arahkan kamera ke kode QR host")
                    .font(.system(size: 17))
                    .foregroundStyle(.white)
                    .padding(.bottom, 40)
            }
        }
        .onAppear { requestCameraAccess() }
    }

    private func requestCameraAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { cameraAuthorized = granted }
            }
        default:
            cameraAuthorized = false
        }
    }
}

// MARK: - AVCapture scanner

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerVC {
        let vc = QRScannerVC()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ vc: QRScannerVC, context: Context) {}
}

private final class QRScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.metadataObjectTypes = [.qr]
            output.setMetadataObjectsDelegate(self, queue: .main)
        }

        let pl = AVCaptureVideoPreviewLayer(session: session)
        pl.videoGravity = .resizeAspectFill
        pl.frame = view.bounds
        view.layer.addSublayer(pl)
        preview = pl

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let str = obj.stringValue else { return }
        session.stopRunning()
        DispatchQueue.main.async { self.onScan?(str) }
    }
}
