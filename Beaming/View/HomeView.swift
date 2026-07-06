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

            BlobShape()
                .fill(BeamingPalette.blob)
                .frame(width: 360, height: 360)
                .blur(radius: 50)
                .opacity(0.45)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 140, y: -150)

            BlobShape()
                .fill(BeamingPalette.blob)
                .frame(width: 360, height: 360)
                .blur(radius: 50)
                .opacity(0.35)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .offset(x: -150, y: 180)

            // Big hero mascot behind the content, top-right
            Image("MascotHome")
                .resizable()
                .scaledToFit()
                .frame(height: 430)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 28, y: -18)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selamat Datang di")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(.black)
                    Text("Beaming!")
                        .font(.system(size: 34, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(BeamingPalette.wordmark)
                    Text("Siap untuk diskusi selanjutnya?")
                        .font(.system(size: 17))
                        .tracking(-0.43)
                        .foregroundStyle(.black)
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 26)
                .padding(.top, 64)

                Spacer(minLength: 24)

                VStack(spacing: 16) {
                    HomeActionCard(
                        symbol: "plus",
                        title: "Mulai diskusi",
                        accent: BeamingPalette.blue,
                        chipBg: BeamingPalette.blue.opacity(0.1)
                    ) {
                        viewModel.didTapCreate()
                    }

                    HomeActionCard(
                        symbol: "qrcode.viewfinder",
                        title: "Scan QR untuk bergabung",
                        accent: BeamingPalette.green,
                        chipBg: BeamingPalette.greenTint.opacity(0.35)
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
    let accent: Color
    let chipBg: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 56, height: 56)
                    .background(chipBg)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 156)
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
