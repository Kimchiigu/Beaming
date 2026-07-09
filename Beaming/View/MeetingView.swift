//
//  MeetingView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

/// The active discussion ("Mode Diskusi"). Interface is identical for host and
/// guest. The host's join-QR auto-opens at half height once calibration ends.
struct MeetingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: MeetingViewModel
    @State private var showHostQR = false
    @State private var didAutoShowQR = false

    var body: some View {
        ZStack {
            discussionContent

            if viewModel.showCalibration {
                CalibrationView(viewModel: viewModel)
                    .transition(.opacity)
            }

            if viewModel.isFaceDown && !viewModel.showCalibration {
                FaceDownView()
                    .transition(.opacity)
            }
        }
        .navigationTitle("Mode Diskusi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // Hide the nav bar while calibrating or face-down so overlays cover fully.
        .toolbar((viewModel.isFaceDown || viewModel.showCalibration) ? .hidden : .visible,
                 for: .navigationBar)
        .toolbar {
            // Back = leave meeting (exit door, glass — matches other toolbars)
            ToolbarItem(placement: .topBarLeading) {
                GlassIconButton(systemName: "rectangle.portrait.and.arrow.right", tint: .red) {
                    viewModel.leaveRoom()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isFaceDown)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showCalibration)
        // Host: auto-present the QR (half sheet) the moment calibration ends.
        .onChange(of: viewModel.showCalibration) { _, stillCalibrating in
            if !stillCalibrating && viewModel.isHost && !didAutoShowQR {
                didAutoShowQR = true
                showHostQR = true
            }
        }
        // Close the QR sheet if the phone is placed face-down.
        .onChange(of: viewModel.isFaceDown) { _, faceDown in
            if faceDown { showHostQR = false }
        }
        .sheet(isPresented: $showHostQR) {
            QRShareSheet(code: viewModel.qrCodeString) {
                showHostQR = false
            }
        }
        .onDisappear {
            viewModel.leaveRoom()
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss { dismiss() }
        }
        .alert("Beaming", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {
                if viewModel.shouldDismiss { dismiss() }
            }
        } message: {
            Text(viewModel.alertMessage)
        }
    }

    // MARK: - Discussion content (identical for host & guest)

    private var discussionContent: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            BlobShape()
                .fill(BeamingPalette.blob)
                .frame(width: 360, height: 360)
                .blur(radius: 50)
                .opacity(0.35)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 150, y: -170)
            BlobShape()
                .fill(BeamingPalette.blob)
                .frame(width: 360, height: 360)
                .blur(radius: 50)
                .opacity(0.3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -150, y: 200)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 15))
                    Text("\(viewModel.room.participantCount) orang di dalam diskusi")
                        .font(.system(size: 16))
                        .tracking(-0.43)
                }
                .foregroundStyle(Color(hex: 0x75777A))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
                .padding(.top, 12)

                Spacer(minLength: 0)

                // Mascot + instruction grouped together (text near the picture)
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [BeamingPalette.yellow.opacity(0.5), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 160
                            ))
                            .frame(width: 300, height: 300)
                            .blur(radius: 6)

                        Image("MascotMeeting")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 220)
                            .accessibilityHidden(true)
                    }

                    VStack(spacing: 6) {
                        Text("Letakkan HP di atas meja dengan layar menghadap ke bawah!")
                            .font(.system(size: 17, weight: .semibold))
                            .tracking(-0.43)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.black)
                        Text("Lampu akan menyala untuk menunjukkan siapa yang sedang berbicara.")
                            .font(.system(size: 15))
                            .tracking(-0.2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 44)
                }

                Spacer(minLength: 0)

                // Standalone QR pill button
                Button {
                    showHostQR = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "qrcode.viewfinder")
                        Text("Tunjukkan Kode QR")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 36)
            }
        }
    }
}

#Preview {
    NavigationStack {
        MeetingView(
            viewModel: MeetingViewModel(
                localUser: User(name: "Preview"),
                networkManager: NetworkManager(),
                asHost: true
            )
        )
        .environment(AppState())
    }
}
