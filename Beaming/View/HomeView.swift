//
//  HomeView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

/// The Home screen: branded greeting + two action cards (Create / Join via QR).
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel?

    var body: some View {
        Group {
            if let viewModel = viewModel {
                homeContent(viewModel: viewModel)
            } else {
                Color.white.ignoresSafeArea()
                    .overlay(ProgressView().tint(BeamingPalette.green))
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = HomeViewModel(user: appState.currentUser)
            }
            viewModel?.onAppear()
        }
    }

    @ViewBuilder
    private func homeContent(viewModel: HomeViewModel) -> some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    
                    Button {
//                        showEditProfile = true
                    } label: {
                        Image(systemName: "person.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .frame(width: 56, height: 56)
                            .foregroundStyle(Color.black)
                            .background(Color.white.opacity(0.2)) // Base layer for glass effect if needed
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .glassEffect()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selamat Datang di")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(.black)
                    Text("Beaming!")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                    Text("Siap untuk diskusi selanjutnya?")
                        .font(.system(size: 17))
                        .tracking(-0.43)
                        .foregroundStyle(.black)
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 26)
                .padding(.bottom, 24)

                VStack(spacing: 16) {
                    HomeActionCard(
                        symbol: "plus.circle.fill",
                        title: "Mulai diskusi",
                        description: "Buat ruang baru dan bagikan QR ke temanmu.",
                        accent: Color.white,
                        chipBg: BeamingPalette.purple
                    ) {
                        viewModel.didTapCreate()
                    }

                    HomeActionCard(
                        symbol: "qrcode.viewfinder",
                        title: "Scan QR untuk bergabung",
                        description: "Pindai QR untuk masuk ke ruang diskusi.",
                        accent: Color.white,
                        chipBg: BeamingPalette.purple
                    ) {
                        viewModel.didTapJoin()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }

            if viewModel.isConnecting {
                Color.black.opacity(0.25).ignoresSafeArea()
                ProgressView("Menghubungkan…")
                    .tint(.white)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: Binding(
            get: { viewModel.showPermission },
            set: { viewModel.showPermission = $0 }
        )) {
            PermissionSheet(
                onAllow: { viewModel.permissionAllowed() },
                onClose: { viewModel.cancelFlow() }
            )
            .presentationDetents([.fraction(0.72), .large])
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showQRScanner },
            set: { viewModel.showQRScanner = $0 }
        )) {
            QRScannerView(
                onScan: { viewModel.joinWithCode($0) },
                onClose: { viewModel.showQRScanner = false }
            )
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.navigateToMeeting },
            set: { viewModel.navigateToMeeting = $0 }
        )) {
            if let meetingVM = viewModel.activeMeetingVM {
                MeetingView(viewModel: meetingVM)
                    .environment(appState)
            }
        }
        .alert("Beaming", isPresented: Binding(
            get: { viewModel.showAlert },
            set: { viewModel.showAlert = $0 }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

// MARK: - Action card

private struct HomeActionCard: View {
    let symbol: String
    let title: String
    let description: String
    let accent: Color
    let chipBg: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 56, height: 56)
                    .foregroundStyle(Color.white)
                    .background(chipBg)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.bottom, 2)
                    Text(description)
                        .font(.system(size: 14, weight: .regular))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .beamingCard()
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(AppState())
    }
}
