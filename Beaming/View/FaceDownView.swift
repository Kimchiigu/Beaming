//
//  FaceDownView.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//  Redesigned for Hi-Fi by Beaming Team, July 2026.
//

import SwiftUI

/// Minimal overlay shown when phone is actually face-down during an active meeting.
/// A very dim screen so as not to distract, with a soft pulsing indicator.
struct FaceDownView: View {
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Pure black background — maximum battery saving on OLED screens
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.25))

                Text("Diskusi Aktif")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.25))
            }
        }
        .onAppear {
            pulseScale = 1.4
        }
    }
}

#Preview {
    FaceDownView()
}
