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
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: HomeViewModel?
    @State private var showEditProfile = false

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
                // Use the profile name (entered during onboarding) over the stable id
                // so the meeting room shows the real name, not the generated codename.
                let name = appState.profileUsername ?? appState.currentUser.name
                viewModel = HomeViewModel(user: User(name: name, id: appState.currentUser.id), role: appState.profileRole)
            }
            viewModel?.onAppear()
        }
        .onChange(of: appState.profileUsername) { _, newName in
            // Keep the local user's name in sync if the profile is edited later.
            if let newName, let viewModel {
                viewModel.currentUser.name = newName
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // Re-read permission status when returning to the app (e.g. after the
            // user flipped a switch in Settings following a denial).
            if phase == .active, let viewModel {
                viewModel.refreshPermissions()
            }
        }
    }

    @ViewBuilder
    private func homeContent(viewModel: HomeViewModel) -> some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    // Settings + profile joined into one glass control (like the
                    // participant/QR group in the meeting toolbar).
                    HStack(spacing: 0) {
                        Button {
                            viewModel.openPermissionSheet()
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Pengaturan")

                        Capsule()
                            .fill(Color.black.opacity(0.12))
                            .frame(width: 1, height: 24)

                        Button {
                            showEditProfile = true
                        } label: {
                            Image(systemName: "person.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Profil")
                    }
                    .glassEffect(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            .frame(maxHeight: .infinity, alignment: .top)

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
                micGranted: viewModel.micGranted,
                speechGranted: viewModel.speechGranted,
                cameraGranted: viewModel.cameraGranted,
                isTuli: appState.profileRole == .temanTuli,
                onRequest: { viewModel.requestPermission($0) },
                onAllow: { viewModel.permissionAllowed() },
                onClose: { viewModel.cancelFlow() }
            )
            .presentationDetents([.large])
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
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(appState: appState)
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

// MARK: - Edit profile sheet

/// Reuses `OnboardingFormView` verbatim (exact same form design as onboarding),
/// pre-filled with the current profile. Presents a standard sheet toolbar:
/// centered "Ubah Profil" title, close on the left, checkmark save on the right.
private struct EditProfileSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: OnboardingViewModel
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        // Pre-fill with the existing profile so the user edits, not re-enters.
        let vm = OnboardingViewModel()
        vm.username = appState.profileUsername ?? ""
        vm.selectedRole = appState.profileRole
        _viewModel = State(initialValue: vm)
    }

    var body: some View {
        NavigationStack {
            OnboardingFormView(viewModel: viewModel, showsTitle: false)
                .navigationTitle("Ubah Profil")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.completeOnboarding(appState: appState)
                            dismiss()
                        } label: {
                            Image(systemName: "checkmark")
                                .fontWeight(.bold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(!viewModel.isFormValid)
                    }
                }
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
