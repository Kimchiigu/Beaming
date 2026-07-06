//
//  MeetingView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//  Redesigned for Hi-Fi by Beaming Team, July 2026.
//

import SwiftUI

struct MeetingView: View {
    var viewModel: MeetingViewModel

    @Environment(AppState.self) private var appState
    @State private var showOptions: Bool = false
    @State private var showQRCode: Bool = false
    @State private var showLeaveConfirm: Bool = false

    var body: some View {
        ZStack {
            // MARK: Background
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.58, green: 0.95, blue: 0.81).opacity(0.40), .clear],
                            center: .center, startRadius: 0, endRadius: 260
                        )
                    )
                    .frame(width: 520, height: 520)
                    .offset(x: geo.size.width - 150, y: -80)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.87, green: 0.93, blue: 0.60).opacity(0.35), .clear],
                            center: .center, startRadius: 0, endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(x: -130, y: geo.size.height - 240)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Top bar
                HStack {
                    // Participant count badge
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.41, green: 0.73, blue: 0.61))
                        Text("\(viewModel.room.participants.count) orang di dalam diskusi")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)

                    Spacer()

                    // Three-dot menu
                    Button {
                        showOptions = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)

                Spacer()

                // MARK: Mode Diskusi content
                VStack(spacing: 0) {
                    // Group mascot (group of 3 smaller mascots)
                    GroupMascot()
                        .frame(height: 140)
                        .padding(.bottom, 28)

                    Text("Mode Diskusi")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .padding(.bottom, 14)

                    Text("Letakkan HP di atas meja dengan layar menghadap ke bawah!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.2))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 10)

                    Text("Lampu akan menyala untuk menunjukkan siapa yang sedang berbicara.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Color(red: 0.50, green: 0.50, blue: 0.50))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                }

                Spacer()
            }

            // MARK: Face-down battery-saver overlay
            if viewModel.isFaceDown && !viewModel.showCalibration {
                FaceDownView()
                    .transition(.opacity)
                    .zIndex(5)
            }

            // MARK: Calibration overlay
            if viewModel.showCalibration {
                CalibrationView(viewModel: viewModel)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .navigationBarHidden(true)
        // MARK: Options action sheet
        .confirmationDialog("", isPresented: $showOptions, titleVisibility: .hidden) {
            Button("Lihat Kode QR") {
                showQRCode = true
            }
            Button("Keluar Diskusi", role: .destructive) {
                showLeaveConfirm = true
            }
            Button("Batal", role: .cancel) { }
        }
        // MARK: QR Code sheet
        .sheet(isPresented: $showQRCode) {
            QRCodeDisplayView(qrCodeString: viewModel.qrCodeString)
                .presentationDetents([.medium, .large])
        }
        // MARK: Leave confirmation
        .alert("Keluar Diskusi?", isPresented: $showLeaveConfirm) {
            Button("Keluar", role: .destructive) {
                viewModel.leaveRoom()
            }
            Button("Batal", role: .cancel) { }
        } message: {
            Text("Kamu akan keluar dari diskusi ini.")
        }
        // MARK: Error alert
        .alert("Notifikasi", isPresented: Binding(
            get: { viewModel.showAlert },
            set: { viewModel.showAlert = $0 }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .onChange(of: viewModel.shouldDismiss) { _, newValue in
            // Handled by NavigationStack pop in HomeView
        }
    }
}

// MARK: - Group Mascot (3 mascots side by side)

struct GroupMascot: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: -20) {
            // Left mascot (smaller)
            BeamingMascot(happy: false)
                .frame(width: 80, height: 80)
                .offset(y: 10)

            // Center mascot (larger)
            BeamingMascot(happy: false)
                .frame(width: 110, height: 110)

            // Right mascot (smaller, slightly different tint)
            BeamingMascot(happy: false)
                .frame(width: 80, height: 80)
                .offset(y: 10)
                .colorMultiply(Color(red: 0.96, green: 0.85, blue: 0.65))
        }
    }
}
