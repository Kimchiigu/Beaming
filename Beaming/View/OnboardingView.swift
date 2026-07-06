//
//  OnboardingView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//  Redesigned for Hi-Fi by Beaming Team, July 2026.
//

import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var name: String = ""
    @State private var isNameFocused: Bool = false

    var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            // MARK: Background with gradient blobs
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                // Top-right mint blob
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.58, green: 0.95, blue: 0.81).opacity(0.55), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)
                    .offset(x: geo.size.width - 120, y: -120)

                // Bottom-left lavender blob
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.87, green: 0.93, blue: 0.60).opacity(0.45), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -150, y: geo.size.height - 200)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // MARK: Mascot placeholder
                        HStack {
                            Spacer()
                            BeamingMascot(happy: false)
                                .frame(width: 120, height: 120)
                                .padding(.top, 48)
                                .padding(.bottom, 32)
                            Spacer()
                        }

                        // MARK: Heading
                        Group {
                            Text("Selamat Datang di ")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                            + Text("Beaming!")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.0, green: 0.58, blue: 0.93))
                        }
                        .padding(.bottom, 8)

                        Text("Siap untuk diskusi selanjutnya?")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                            .padding(.bottom, 40)

                        // MARK: Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nama")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))

                            TextField("Masukkan namamu", text: $name)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .font(.system(size: 16))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.96, green: 0.97, blue: 0.97))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(
                                            isNameFocused
                                                ? Color(red: 0.0, green: 0.58, blue: 0.93).opacity(0.6)
                                                : Color.clear,
                                            lineWidth: 1.5
                                        )
                                )
                                .onTapGesture { isNameFocused = true }
                        }
                        .padding(.bottom, 60)
                    }
                    .padding(.horizontal, 28)
                }

                // MARK: Continue button
                Button(action: handleContinue) {
                    Text("Lanjutkan")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            canContinue
                                ? Color(red: 0.0, green: 0.58, blue: 0.93)
                                : Color(red: 0.75, green: 0.75, blue: 0.75)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                }
                .disabled(!canContinue)
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            isNameFocused = false
        }
    }

    // MARK: - Actions

    private func handleContinue() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // Request mic permission upfront, then save
        AVAudioApplication.requestRecordPermission { _ in
            DispatchQueue.main.async {
                // Save with .hearing as default — all users participate with audio
                appState.saveUser(name: trimmedName, role: .hearing)
            }
        }
    }
}

// MARK: - Beaming Mascot (SwiftUI placeholder for asset)

struct BeamingMascot: View {
    var happy: Bool = false

    var body: some View {
        ZStack {
            // Body blob
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.68, green: 0.95, blue: 0.82),
                            Color(red: 0.50, green: 0.85, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 90)
                .offset(y: 8)

            // Left cheek
            Ellipse()
                .fill(Color(red: 1.0, green: 0.47, blue: 0.53).opacity(0.5))
                .frame(width: 28, height: 15)
                .offset(x: -22, y: 18)

            // Right cheek
            Ellipse()
                .fill(Color(red: 1.0, green: 0.47, blue: 0.53).opacity(0.5))
                .frame(width: 28, height: 15)
                .offset(x: 22, y: 18)

            // Left eye
            Ellipse()
                .fill(Color.black)
                .frame(width: 16, height: happy ? 10 : 18)
                .offset(x: -16, y: -4)

            // Right eye
            Ellipse()
                .fill(Color.black)
                .frame(width: 16, height: happy ? 10 : 18)
                .offset(x: 16, y: -4)

            // Eye shine (left)
            Circle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
                .offset(x: -12, y: -8)

            if happy {
                // Happy mouth arc
                Path { path in
                    path.move(to: CGPoint(x: -18, y: 28))
                    path.addQuadCurve(
                        to: CGPoint(x: 18, y: 28),
                        control: CGPoint(x: 0, y: 44)
                    )
                }
                .stroke(Color.black, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 36, height: 20)
                .offset(x: 0, y: 14)
            }
        }
        .frame(width: 120, height: 120)
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
