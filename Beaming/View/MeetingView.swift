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
                if Bundle.main.bundleIdentifier?.contains("Clip") == false {
                    transcriber.startTranscribing()
                }
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
            // Always-on captions: route the local engine's output into the shared
            // feed (which also broadcasts to the room) and start once calibrated.
            transcriber.onCaptionUpdate = { [weak viewModel] text, isFinal in
                viewModel?.handleLocalCaption(text: text, isFinal: isFinal)
            }
            if !viewModel.showCalibration {
                if Bundle.main.bundleIdentifier?.contains("Clip") == false {
                    transcriber.startTranscribing()
                }
            }
        }
        .onDisappear {
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

            if Bundle.main.bundleIdentifier?.contains("Clip") == true {
                Text("Transkripsi langsung tidak tersedia di App Clip. Silakan unduh aplikasi Beaming versi penuh di App Store untuk menikmati fitur ini.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if let err = transcriber.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0xE0533D))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if viewModel.captions.isEmpty && viewModel.liveBySpeaker.isEmpty {
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

    /// Scrollable, auto-following chat of caption bubbles from everyone in the room.
    /// captions is appended in chronological order, so we render it directly (no
    /// per-render sort) — sorting on every streaming partial was the main-thread
    /// bottleneck that lagged scrolling and starved transcription.
    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.captions) { msg in
                        captionBubble(msg, isLive: false)
                            .id(msg.id.uuidString)
                    }
                    ForEach(Array(viewModel.liveBySpeaker.values), id: \.speakerID) { live in
                        captionBubble(live, isLive: true)
                            .id("live-\(live.speakerID.uuidString)")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, 2)
            }
            .frame(height: 190)
            .onChange(of: viewModel.captions.count) { _, _ in follow(proxy) }
            .onChange(of: liveSignature) { _, _ in follow(proxy) }
            .onAppear { follow(proxy) }
        }
    }

    /// Throttled, non-animated auto-scroll. A streaming partial fires several times
    /// per second; animating+laying out the whole list on each one was too costly.
    private func follow(_ proxy: ScrollViewProxy) {
        let now = Date()
        guard now.timeIntervalSince(lastScrollAt) >= 0.2 else { return }
        lastScrollAt = now
        proxy.scrollTo("bottom", anchor: .bottom)
    }

    /// Fingerprint of all live bubbles — changes as any speaker's partial streams in.
    private var liveSignature: String {
        viewModel.liveBySpeaker.values
            .sorted(by: { $0.speakerID.uuidString < $1.speakerID.uuidString })
            .map(\.text)
            .joined(separator: "|")
    }

    /// One chat bubble. This device's own captions are right-aligned green; everyone
    /// else is left-aligned grey.
    private func captionBubble(_ msg: CaptionMessage, isLive: Bool) -> some View {
        let isOwn = msg.speakerID == viewModel.localUser.id
        return VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
            Text(msg.speakerName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BeamingPalette.green)
            Text(isLive ? msg.text + "…" : msg.text)
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
