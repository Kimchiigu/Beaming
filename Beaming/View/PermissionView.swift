//
//  PermissionView.swift
//  Beaming
//
//  Created by Beaming Team, July 2026.
//

import SwiftUI
import AVFoundation

/// Sheet shown before starting a discussion.
/// Explains and requests microphone + local network permissions.
struct PermissionView: View {
    var onAllow: () -> Void

    @State private var micGranted: Bool = false
    @State private var networkGranted: Bool = false  // local network prompt fires automatically on first Bonjour browse

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                Button {
                    onAllow() // dismiss without waiting — permissions will be prompted by OS anyway
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.4))
                        .frame(width: 36, height: 36)
                        .background(Color(red: 0.93, green: 0.93, blue: 0.93))
                        .clipShape(Circle())
                }

                Spacer()

                Text("Permission")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Spacer()

                // Balance spacer
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)

            // MARK: Subtitle
            Text("We need a few permissions to start your interactive experience.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

            // MARK: Permission Cards
            VStack(spacing: 12) {
                PermissionCard(
                    iconName: "mic.fill",
                    iconBgColor: Color(red: 1.0, green: 0.82, blue: 0.82),
                    iconColor: Color(red: 0.90, green: 0.27, blue: 0.27),
                    title: "Microphone",
                    description: "Detects speech rhythm and volume to generate visual \"beaming\" pulses. No audio is ever recorded or stored.",
                    isGranted: micGranted
                )

                PermissionCard(
                    iconName: "flashlight.off.fill",
                    iconBgColor: Color(red: 0.82, green: 0.91, blue: 1.0),
                    iconColor: Color(red: 0.0, green: 0.58, blue: 0.93),
                    title: "Local Network",
                    description: "Uses your device's flashlight or screen brightness to provide visual feedback during active discussions.",
                    isGranted: networkGranted
                )
            }
            .padding(.horizontal, 24)

            Spacer()

            // MARK: Allow Access button
            Button {
                requestPermissions()
            } label: {
                Text("Allow Access")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color(red: 0.22, green: 0.53, blue: 0.98))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(Color.white)
        .onAppear {
            checkMicStatus()
        }
    }

    private func checkMicStatus() {
        let status = AVAudioApplication.shared.recordPermission
        micGranted = (status == .granted)
    }

    private func requestPermissions() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                micGranted = granted
                // Local network permission fires automatically on first Bonjour operation
                networkGranted = true
                // Proceed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAllow()
                }
            }
        }
    }
}

// MARK: - Permission Card Component

struct PermissionCard: View {
    let iconName: String
    let iconBgColor: Color
    let iconColor: Color
    let title: String
    let description: String
    var isGranted: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Text(description)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Checkmark
            Image(systemName: isGranted ? "checkmark" : "checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(
                    isGranted
                        ? Color(red: 0.20, green: 0.73, blue: 0.45)
                        : Color(red: 0.75, green: 0.75, blue: 0.75)
                )
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    PermissionView {
        print("Allowed!")
    }
}
