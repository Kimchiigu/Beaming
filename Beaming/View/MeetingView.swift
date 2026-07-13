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
                CalibView(viewModel: viewModel)
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        // Hide the nav bar while calibrating or face-down so overlays cover fully.
        .toolbar((viewModel.isFaceDown || viewModel.showCalibration) ? .hidden : .visible,
                 for: .navigationBar)
        .toolbar {
            // [NOTES] — left: leave; center: "Mode Diskusi"; right: participants + QR.
            ToolbarItem(placement: .topBarLeading) {
                toolbarIcon("rectangle.portrait.and.arrow.right", tint: .red) {
                    viewModel.leaveRoom()
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Mode Diskusi")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                toolbarIcon("person.2.fill") {
                    withAnimation(.easeOut(duration: 0.15)) { showParticipants.toggle() }
                }
                toolbarIcon("qrcode.viewfinder") {
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
            if isTuli {
                // Deaf (Tuli) users don't speak: no mic, no local transcription — they
                // only read remote captions. As host, share the QR now since there's no
                // calibration step to trigger the auto-show.
                if viewModel.isHost { showHostQR = true }
            } else {
                // Always-on captions: route the local engine's output into the shared
                // feed (which also broadcasts to the room) and start once calibrated.
                transcriber.onCaptionUpdate = { [weak viewModel] text, isFinal in
                    viewModel?.handleLocalCaption(text: text, isFinal: isFinal)
                }
                if !viewModel.showCalibration {
                    transcriber.startTranscribing()
                }
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

    /// Deaf role: Transcript / Tutorial via Apple's standard tab bar.
    private var tuliContent: some View {
        TabView(selection: $selectedTab) {
            Meeting_TranscriptView(viewModel: viewModel, transcriber: transcriber)
                .tabItem {
                    Label("Transkrip", systemImage: "captions.bubble.fill")
                }
                .tag(MeetingTab.transcript)

            Meeting_TutorialView()
                .tabItem {
                    Label("Tutorial", systemImage: "lightbulb.fill")
                }
                .tag(MeetingTab.tutorial)
        }
        .tint(BeamingPalette.purple)
    }

    // MARK: - Toolbar icon (plain — no glass circle)

    private func toolbarIcon(_ systemName: String, tint: Color = .primary,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(tint)
        }
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

private enum MeetingTab: Hashable {
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
