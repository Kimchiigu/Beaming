//
//  PermissionSheet.swift
//  Beaming
//
//  Unified permission sheet: Microphone, Speech Recognition, Camera.
//  Each row is tappable — tapping fires the real Apple prompt (or, if the user has
//  already denied it, opens Settings so they can re-enable), and the checkmark fills
//  only once the permission is actually granted. Uses standard Apple sheet chrome
//  (nav bar title + toolbar close button), matching the edit-profile sheet.
//

import SwiftUI

struct PermissionSheet: View {
    let micGranted: Bool
    let speechGranted: Bool
    let cameraGranted: Bool
    /// Deaf (Tuli) users don't speak — hide the mic + speech rows (camera only).
    let isTuli: Bool
    let onRequest: (PermissionKind) -> Void
    let onAllow: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Kami memerlukan beberapa izin untuk memulai pengalaman interaktif.")
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.31)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 4)

                if !isTuli {
                    PermissionRow(
                        icon: "microphone",
                        title: "Mikrofon",
                        description: "Mendeteksi suara saat Anda berbicara untuk menyalakan lampu.",
                        granted: micGranted
                    ) { onRequest(.microphone) }

                    PermissionRow(
                        icon: "waveform",
                        title: "Pengenalan Suara",
                        description: "Mengubah percakapan menjadi teks transkripsi langsung.",
                        granted: speechGranted
                    ) { onRequest(.speech) }
                }

                PermissionRow(
                    icon: "camera.fill",
                    title: "Kamera",
                    description: "Memindai kode QR host untuk bergabung ke ruang diskusi.",
                    granted: cameraGranted
                ) { onRequest(.camera) }

                Spacer(minLength: 0)

                Button {
                    onAllow()
                } label: {
                    Text("Lanjutkan")
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(BeamingPalette.purple)
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .navigationTitle("Izin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(BeamingPalette.purple)
                    .frame(width: 44, height: 44)
                    .background(BeamingPalette.purple.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .tracking(-0.31)
                        .foregroundStyle(.black)
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(granted ? BeamingPalette.purple : Color.secondary.opacity(0.35))
            }
            .padding(15)
            .beamingCard()
            .padding(.horizontal, 22)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PermissionSheet(
        micGranted: true,
        speechGranted: false,
        cameraGranted: false,
        isTuli: false,
        onRequest: { _ in },
        onAllow: {},
        onClose: {}
    )
}
