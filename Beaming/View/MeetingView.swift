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
    @State private var transcriber = VoiceTranscribeViewModel()
    @State private var lastScrollAt: Date = .distantPast

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
            if !stillCalibrating {
                // Always-on captions start the moment calibration finishes.
                transcriber.startTranscribing()
            }
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

                Spacer(minLength: 16)

                transcriptionCard

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

    // MARK: - Live transcription

    /// Caption card: always-on chat-style transcript merged from all speakers.
    private var transcriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: transcriber.isTranscribing ? "waveform" : "captions.bubble")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeamingPalette.green)
                Text("Transkripsi Langsung")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(BeamingPalette.green)
                if transcriber.isTranscribing {
                    Text("● langsung")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(BeamingPalette.green)
                }
                Spacer()
            }

            if let err = transcriber.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0xE0533D))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.captions.isEmpty {
                Text(transcriber.isTranscribing ? "Mendengarkan…" : "Memulai transkripsi…")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
            } else {
                chatScroll
            }
        }
        .padding(16)
        .beamingCard()
        .padding(.horizontal, 24)
    }

    /// Scrollable, auto-following chat of turn bubbles (one per speaker turn, max 5).
    /// Each row is an Equatable view, so when a new bubble arrives only the NEW row
    /// renders — historical rows are reused as-is (no re-render, no lag).
    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.captions) { msg in
                        CaptionBubbleView(msg: msg, isOwn: msg.speakerID == viewModel.localUser.id)
                            .equatable()
                            .id(msg.id.uuidString)
                    }
                    if viewModel.isLocalSpeaking {
                        CaptionBubbleView(
                            msg: CaptionMessage(
                                speakerID: viewModel.localUser.id,
                                speakerName: viewModel.localUser.name,
                                text: "",
                                date: Date()
                            ),
                            isOwn: true
                        )
                        .id("local-placeholder")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 2)
            }
            .frame(height: 190)
            .onChange(of: viewModel.captions.count) { _, _ in follow(proxy) }
            .onChange(of: viewModel.isLocalSpeaking) { _, _ in follow(proxy) }
            .onAppear { follow(proxy) }
        }
    }

    /// Throttled, non-animated auto-scroll.
    private func follow(_ proxy: ScrollViewProxy) {
        let now = Date()
        guard now.timeIntervalSince(lastScrollAt) >= 0.2 else { return }
        lastScrollAt = now
        proxy.scrollTo("bottom", anchor: .bottom)
    }
}

/// One chat bubble. Equatable so SwiftUI can skip re-rendering it when its inputs
/// are unchanged — this is what keeps history from re-rendering on every new message.
private struct CaptionBubbleView: View, Equatable {
    let msg: CaptionMessage
    let isOwn: Bool

    static func == (lhs: CaptionBubbleView, rhs: CaptionBubbleView) -> Bool {
        lhs.isOwn == rhs.isOwn && lhs.msg == rhs.msg
    }

    var body: some View {
        // Empty text = the local "speaking" placeholder while a turn is in progress.
        let display = msg.text.isEmpty ? "sedang bicara…" : msg.text
        return VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
            Text(msg.speakerName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BeamingPalette.green)
            Text(display)
                .font(.system(size: 15))
                .foregroundStyle(isOwn ? .white : .black)
                .multilineTextAlignment(isOwn ? .trailing : .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOwn ? BeamingPalette.green : Color(hex: 0xF0F1F2))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .frame(maxWidth: 260, alignment: isOwn ? .trailing : .leading)
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
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

