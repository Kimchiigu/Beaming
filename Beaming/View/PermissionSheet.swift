//
//  PermissionSheet.swift
//  Beaming
//
//  Bottom sheet asking for Microphone + Local Network access before a session.
//

import SwiftUI

struct PermissionSheet: View {
    let onAllow: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            ZStack {
                Text("Izin")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)

            Text("Kami memerlukan beberapa izin untuk memulai pengalaman interaktif.")
                .font(.system(size: 16, weight: .semibold))
                .tracking(-0.31)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)

            PermissionRow(
                icon: "microphone",
                chipColor: BeamingPalette.micChip,
                title: "Mikrofon",
                description: "Mendeteksi ritme dan volume suara untuk menghasilkan pulsa \u{201C}beaming\u{201D} visual. Tidak ada audio yang pernah direkam atau disimpan."
            )

            PermissionRow(
                icon: "flashlight.off.fill",
                chipColor: BeamingPalette.netChip,
                title: "Jaringan Lokal",
                description: "Menggunakan senter atau kecerahan layar perangkat Anda untuk memberikan umpan balik visual selama diskusi aktif."
            )

            Spacer(minLength: 0)

            Button("Izinkan Akses") {
                onAllow()
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.black)
        .background(Color.white)
    }
}

private struct PermissionRow: View {
    let icon: String
    let chipColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: 36, height: 36)
                .background(chipColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.31)
                    .foregroundStyle(.black)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(BeamingPalette.green)
        }
        .padding(15)
        .beamingCard()
        .padding(.horizontal, 22)
    }
}

#Preview {
    PermissionSheet(onAllow: {}, onClose: {})
}
