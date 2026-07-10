//
//  AppClipJoinView.swift
//  BeamingClip
//
//  The App Clip's root view. Designed to match the App Clip card reference:
//  mascot + "Beaming" + "Ikuti percakapan secara real-time".
//  Skips Home entirely: Permission → Connect → Calibration → Meeting.
//

import SwiftUI
import StoreKit

struct AppClipJoinView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @Binding var invocationURL: URL?

    @State private var viewModel: AppClipJoinViewModel?
    @State private var showPermission = false
    @State private var navigateToMeeting = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background — white + soft blobs (matching full app style)
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

                // Content — matches the App Clip card reference design
                VStack(spacing: 0) {
                    Spacer()

                    // Mascot with radial glow (same as the App Clip card reference)
                    ZStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [
                                    BeamingPalette.yellow.opacity(0.35),
                                    BeamingPalette.green.opacity(0.15),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 140
                            ))
                            .frame(width: 280, height: 280)
                            .blur(radius: 8)

                        Image("MascotMeeting")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 180)
                    }

                    Spacer().frame(height: 28)

                    // Title: "Beaming" with gradient (like the reference card)
                    Text("Beaming")
                        .font(.system(size: 32, weight: .bold))
                        .tracking(0.4)
                        .foregroundStyle(BeamingPalette.wordmark)

                    Spacer().frame(height: 8)

                    // Subtitle: matching the App Clip card reference
                    Text("Ikuti percakapan secara real-time")
                        .font(.system(size: 17))
                        .tracking(-0.43)
                        .foregroundStyle(Color(hex: 0x75777A))

                    Spacer().frame(height: 32)

                    // Status area — shows connection state
                    statusView

                    Spacer()

                    // Footer: promote the full app download
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.app.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(BeamingPalette.green)
                            Text("Dapatkan pengalaman lengkap")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text("Unduh Beaming di App Store")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BeamingPalette.green)
                    }
                    .padding(.bottom, 36)
                }
                .padding(.horizontal, 24)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToMeeting) {
                if let meetingVM = viewModel?.activeMeetingVM {
                    MeetingView(viewModel: meetingVM)
                        .environment(appState)
                }
            }
        }
        .preferredColorScheme(.light)
        // MARK: - Permission sheet (only when no alert is active)
        .sheet(isPresented: $showPermission) {
            PermissionSheet(
                onAllow: {
                    UserDefaults.standard.set(true, forKey: "hasShownPermission")
                    showPermission = false
                    viewModel?.permissionGranted()
                },
                onClose: {
                    showPermission = false
                    viewModel?.permissionGranted()
                }
            )
            .presentationDetents([.fraction(0.72), .large])
        }
        // MARK: - Lifecycle
        .onAppear {
            if viewModel == nil {
                let vm = AppClipJoinViewModel(user: appState.currentUser)
                vm.onJoinSuccess = { [weak vm] in
                    guard vm != nil else { return }
                    navigateToMeeting = true
                }
                viewModel = vm

                // If URL is already available (cold launch), handle it now
                if let url = invocationURL {
                    vm.handleInvocationURL(url)
                    // Show permission only if the URL was valid
                    if vm.hasValidRoom {
                        if UserDefaults.standard.bool(forKey: "hasShownPermission") {
                            vm.permissionGranted()
                        } else {
                            showPermission = true
                        }
                    }
                }
            }
        }
        // MARK: - URL arrival (may come after onAppear)
        .onChange(of: invocationURL) { _, newURL in
            guard let url = newURL else { return }
            print("[AppClipJoinView] URL changed to: \(url.absoluteString)")
            viewModel?.handleInvocationURL(url)
            // Show permission only if valid room AND not already in a meeting
            if viewModel?.hasValidRoom == true,
               viewModel?.activeMeetingVM == nil,
               !navigateToMeeting,
               !showPermission {
                if UserDefaults.standard.bool(forKey: "hasShownPermission") {
                    viewModel?.permissionGranted()
                } else {
                    showPermission = true
                }
            }
        }
        // MARK: - Foreground re-activation
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, let url = invocationURL {
                // Re-process URL when returning from background
                if viewModel?.activeMeetingVM == nil && !navigateToMeeting {
                    viewModel?.handleInvocationURL(url)
                    if viewModel?.hasValidRoom == true && !showPermission {
                        if UserDefaults.standard.bool(forKey: "hasShownPermission") {
                            viewModel?.permissionGranted()
                        } else {
                            showPermission = true
                        }
                    }
                }
            }
        }
        // MARK: - Alert (only shows when permission sheet is NOT active)
        .alert("Beaming", isPresented: Binding(
            get: {
                // Only allow alert when sheet is dismissed to prevent presentation conflict
                guard !showPermission else { return false }
                return viewModel?.showAlert ?? false
            },
            set: { viewModel?.showAlert = $0 }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.alertMessage ?? "")
        }
    }

    // MARK: - Status indicator

    @ViewBuilder
    private var statusView: some View {
        if let vm = viewModel {
            if vm.isConnecting {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(BeamingPalette.green)
                    Text("Menghubungkan ke diskusi…")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(hex: 0x75777A))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(hex: 0xF6F6F6))
                .clipShape(Capsule())
            } else if vm.connectionFailed {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(BeamingPalette.pink)
                    Text("Tidak dapat terhubung")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("Pastikan kamu dekat dengan host dan coba lagi.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            } else {
                HStack(spacing: 8) {
                    Circle()
                        .fill(BeamingPalette.green)
                        .frame(width: 8, height: 8)
                    Text("Menunggu data ruangan…")
                        .font(.system(size: 15))
                        .foregroundStyle(Color(hex: 0x75777A))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(hex: 0xF6F6F6))
                .clipShape(Capsule())
            }
        }
    }
}
