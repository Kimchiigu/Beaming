//
//  MeetingView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

/// The active discussion ("Mode Diskusi"). Content is role-based:
///  [NOTES] — a deaf ("Teman Tuli") participant gets an app bar with two tabs:
///  Transcript (`Meeting+TranscriptView`) and Tutorial (`Meeting+TutorialView`).
///  A hearing ("Teman Dengar") participant gets only `Meeting+HearView` (no app bar).
struct MeetingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: MeetingViewModel
    @State private var showHostQR = false
    @State private var didAutoShowQR = false
    @State private var showParticipants = false
    @State private var selectedTab: MeetingTab = .transcript
    @State private var transcriber = VoiceTranscribeViewModel()

    private var isTuli: Bool { appState.profileRole == .temanTuli }

    var body: some View {
        ZStack {
            meetingContent

            // Calibration runs first; when it ends, audio + transcription start.
            if viewModel.showCalibration {
                CalibrationView(viewModel: viewModel)
                    .transition(.opacity)
            }

            if viewModel.isFaceDown && !viewModel.showCalibration {
                FaceDownView()
                    .transition(.opacity)
            }

            if showParticipants && !viewModel.showCalibration && !viewModel.isFaceDown {
                participantsDropdown
            }
        }
        .navigationTitle("Mode Diskusi")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // Hide the nav bar while calibrating or face-down so overlays cover fully.
        .toolbar((viewModel.isFaceDown || viewModel.showCalibration) ? .hidden : .visible,
                 for: .navigationBar)
        .toolbar {
            // [NOTES] — left: leave; center: "Mode Diskusi" (navigationTitle);
            // right: participants dropdown + QR.
            ToolbarItem(placement: .topBarLeading) {
                GlassIconButton(systemName: "rectangle.portrait.and.arrow.right", tint: .red) {
                    viewModel.leaveRoom()
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                GlassIconButton(systemName: "person.2.fill") {
                    withAnimation(.easeOut(duration: 0.15)) { showParticipants.toggle() }
                }
                GlassIconButton(systemName: "qrcode.viewfinder") {
                    showHostQR = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isFaceDown)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showCalibration)
        // Host: auto-present the QR (half sheet) the moment calibration ends.
        .onChange(of: viewModel.showCalibration) { _, stillCalibrating in
            if !stillCalibrating {
                // Always-on captions start the moment calibration finishes.
                transcriber.startTranscribing()
            }
            if !stillCalibrating && viewModel.isHost && !didAutoShowQR {
                didAutoShowQR = true
                showHostQR = true
            }
        }
        // Close the QR sheet / participants dropdown if the phone is placed face-down.
        .onChange(of: viewModel.isFaceDown) { _, faceDown in
            if faceDown {
                showHostQR = false
                showParticipants = false
            }
        }
        .sheet(isPresented: $showHostQR) {
            QRShareSheet(code: viewModel.qrCodeString) {
                showHostQR = false
            }
        }
        .onAppear {
            // Keep the screen awake for the whole meeting. The torch is a camera
            // resource and iOS kills it the moment the app backgrounds / the screen
            // locks — the audio background mode keeps the MIC alive, but there is no
            // background mode that lets the torch run on a locked phone. Disabling
            // the idle timer prevents auto-lock, so the app stays foregrounded and
            // the torch can still blink when someone speaks. (Restored on disappear.)
            UIApplication.shared.isIdleTimerDisabled = true
            // Always-on captions: route the local engine's output into the shared
            // feed (which also broadcasts to the room) and start once calibrated.
            transcriber.onCaptionUpdate = { [weak viewModel] text, isFinal in
                viewModel?.handleLocalCaption(text: text, isFinal: isFinal)
            }
            if !viewModel.showCalibration {
                transcriber.startTranscribing()
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            transcriber.stopTranscribing()
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

    // MARK: - Role-based content

    @ViewBuilder
    private var meetingContent: some View {
        if isTuli {
            tuliContent
        } else {
            Meeting_HearView()
        }
    }

    /// Deaf role: a Transcript/Tutorial tab switched by a floating bottom app bar.
    private var tuliContent: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .transcript:
                    Meeting_TranscriptView(viewModel: viewModel, transcriber: transcriber)
                case .tutorial:
                    Meeting_TutorialView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomTabBar
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
        }
    }

    private var bottomTabBar: some View {
        HStack(spacing: 6) {
            tabButton(.transcript, title: "Transkrip", icon: "captions.bubble.fill")
            tabButton(.tutorial, title: "Tutorial", icon: "lightbulb.fill")
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func tabButton(_ tab: MeetingTab, title: String, icon: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(selectedTab == tab ? .white : BeamingPalette.purple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                if selectedTab == tab {
                    Capsule().fill(BeamingPalette.purple)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Participants dropdown

    private var participantsDropdown: some View {
        VStack {
            HStack {
                Spacer()
                DropdownMenuList(names: viewModel.room.participants.map { $0.name })
                    .padding(.trailing, 16)
                    .padding(.top, 6)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.15)) { showParticipants = false }
                }
        )
        .transition(.opacity)
        .zIndex(10)
    }
}

private enum MeetingTab {
    case transcript, tutorial
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
