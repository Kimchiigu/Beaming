//
//  HomeView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//  Redesigned for Hi-Fi by Beaming Team, July 2026.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel?
    @State private var showPermission: Bool = false
    @State private var showQRScanner: Bool = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                homeContent(viewModel: viewModel)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
            }
        }
        .onAppear {
            if viewModel == nil, let user = appState.currentUser {
                let vm = HomeViewModel(currentUser: user)
                self.viewModel = vm
                vm.startDiscovery()
            } else if let vm = viewModel {
                vm.resetAfterMeeting()
            }
        }
    }

    @ViewBuilder
    private func homeContent(viewModel: HomeViewModel) -> some View {
        ZStack {
            // MARK: Background blobs
            Color.white.ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.58, green: 0.95, blue: 0.81).opacity(0.45), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 280
                        )
                    )
                    .frame(width: 560, height: 560)
                    .offset(x: geo.size.width - 180, y: -100)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(red: 0.87, green: 0.93, blue: 0.60).opacity(0.35), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                    .frame(width: 440, height: 440)
                    .offset(x: -160, y: geo.size.height - 280)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header greeting
                VStack(alignment: .leading, spacing: 4) {
                    Group {
                        Text("Selamat Datang di ")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        + Text("Beaming!")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.0, green: 0.58, blue: 0.93))
                    }

                    Text("Siap untuk diskusi selanjutnya?")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 64)

                Spacer()

                // MARK: Mascot
                BeamingMascot(happy: false)
                    .frame(width: 130, height: 130)
                    .padding(.bottom, 8)

                Spacer()

                // MARK: Action Cards
                VStack(spacing: 14) {
                    // Card 1: Mulai diskusi (host)
                    Button {
                        showPermission = true
                    } label: {
                        HomeActionCard(
                            icon: "plus",
                            iconBgColor: Color(red: 0.0, green: 0.58, blue: 0.93).opacity(0.12),
                            iconColor: Color(red: 0.0, green: 0.58, blue: 0.93),
                            title: "Mulai diskusi",
                            titleColor: Color(red: 0.0, green: 0.58, blue: 0.93),
                            isLoading: false
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isJoining)

                    // Card 2: Scan QR
                    Button {
                        showQRScanner = true
                    } label: {
                        HomeActionCard(
                            icon: "qrcode.viewfinder",
                            iconBgColor: Color(red: 0.41, green: 0.73, blue: 0.61).opacity(0.18),
                            iconColor: Color(red: 0.41, green: 0.73, blue: 0.61),
                            title: "Scan Kode QR untuk bergabung",
                            titleColor: Color(red: 0.41, green: 0.73, blue: 0.61),
                            isLoading: viewModel.isJoining
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isJoining)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
        .navigationBarHidden(true)
        // MARK: Navigation to Meeting
        .navigationDestination(isPresented: Binding(
            get: { viewModel.navigateToMeeting },
            set: { viewModel.navigateToMeeting = $0 }
        )) {
            if let meetingVM = viewModel.activeMeetingVM {
                MeetingView(viewModel: meetingVM)
                    .environment(appState)
            }
        }
        // MARK: Permission sheet (Mulai diskusi path)
        .sheet(isPresented: $showPermission) {
            PermissionView {
                showPermission = false
                viewModel.createRoom()
            }
        }
        // MARK: QR Scanner sheet
        .sheet(isPresented: $showQRScanner) {
            QRScannerView { scannedString in
                showQRScanner = false
                viewModel.joinRoomFromQR(qrString: scannedString)
            }
        }
        // MARK: Alert
        .alert("Notifikasi", isPresented: Binding(
            get: { viewModel.showAlert },
            set: { viewModel.showAlert = $0 }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        // MARK: Return to Home when meeting ends
        .onChange(of: viewModel.activeMeetingVM?.shouldDismiss) { _, newValue in
            if newValue == true {
                viewModel.navigateToMeeting = false
                viewModel.resetAfterMeeting()
            }
        }
    }
}

// MARK: - Action Card Component

struct HomeActionCard: View {
    let icon: String
    let iconBgColor: Color
    let iconColor: Color
    let title: String
    let titleColor: Color
    var isLoading: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(iconBgColor)
                    .frame(width: 64, height: 64)

                if isLoading {
                    ProgressView()
                        .tint(iconColor)
                        .scaleEffect(1.1)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(iconColor)
                }
            }

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(titleColor)
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(AppState())
    }
}
