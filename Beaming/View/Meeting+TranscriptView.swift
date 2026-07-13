//
//  Meeting+TranscriptView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 11/07/26.
//

import SwiftUI

/// The Transcript tab shown to a deaf ("Teman Tuli") participant. Renders the live
/// captions (`viewModel.captions`) as a card carousel, with:
///  - 3 pulsing dots while the local engine is transcribing a turn in progress.
//  [NOTES]: integrated — pulls each speaker's name from the caption, shows pulse dots
//  while the AI is transcribing, and a small speaker-initial circle below the newest
//  card when someone else is talking.
/// Readable per-speaker colors (white text stays legible on all of them). Used so
/// multiple speakers are distinguishable instead of everything being purple.
private enum SpeakerPalette {
    static let colors: [Color] = [
        Color(hex: 0x715DD1), // purple
        Color(hex: 0x2E6FB4), // blue
        Color(hex: 0x128A72), // teal-green
        Color(hex: 0xC0392B), // red
        Color(hex: 0xC2447A), // pink
        Color(hex: 0xB5651D), // amber
        Color(hex: 0x2C7A9B), // steel blue
        Color(hex: 0x5A9E3F), // green
    ]
}

struct Meeting_TranscriptView: View {
    let viewModel: MeetingViewModel
    let transcriber: VoiceTranscribeViewModel

    var body: some View {
        GeometryReader { geometry in
            let cardHeight = geometry.size.height * 0.55

            ZStack(alignment: .bottom) {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: -40) {
                            if viewModel.captions.isEmpty {
                                emptyState
                                    .frame(height: cardHeight)
                                    .id("empty")
                            } else {
                                ForEach(viewModel.captions) { msg in
                                    captionCard(msg, cardHeight: cardHeight)
                                        .id(msg.id)
                                }
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.vertical, (geometry.size.height - cardHeight) / 2)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .onChange(of: viewModel.captions.count) { _, _ in
                        scrollToLatest(proxy)
                    }
                    .onAppear { scrollToLatest(proxy) }
                }

                indicators
                    .padding(.bottom, 8)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.isLocalSpeaking)
                    .animation(.easeInOut(duration: 0.2), value: viewModel.room.isSpeaker)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Caption card

    private func captionCard(_ msg: CaptionMessage, cardHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(msg.speakerName)
                .font(.system(size: 40, weight: .bold))
            Text(msg.text)
                .font(.system(size: 28))
        }
        .foregroundColor(.white)
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: cardHeight)
        .background(speakerColor(for: msg.speakerID))
        .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.5, anchor: .leading)
                .opacity(phase.isIdentity ? 1.0 : 0.2)
                .offset(y: phase.value * 40)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "captions.bubble")
                .font(.system(size: 40))
                .foregroundStyle(BeamingPalette.purple.opacity(0.5))
            Text(transcriber.isTranscribing ? "Mendengarkan…" : "Menunggu percakapan…")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BeamingPalette.purple)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Indicators (below the newest card)

    /// Mini avatar for whoever currently holds the floor — the local user (while the
    /// engine transcribes their turn) or a remote participant. Colored per speaker.
    @ViewBuilder
    private var indicators: some View {
        let remote = currentRemoteSpeaker()
        if viewModel.isLocalSpeaking {
            speakerAvatar(viewModel.localUser, isLocal: true)
        } else if let remote {
            speakerAvatar(remote, isLocal: false)
        }
    }

    /// Speaker-initial circle + name in that speaker's assigned color. Shows pulsing
    /// dots while the local engine is mid-turn, otherwise a speaker icon.
    private func speakerAvatar(_ user: User, isLocal: Bool) -> some View {
        let color = speakerColor(for: user.id)
        return HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                Text(initial(of: user.name))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .overlay {
                Circle().stroke(.white, lineWidth: 2).frame(width: 32, height: 32)
            }

            Text(user.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            if isLocal && transcriber.isTranscribing {
                typingDots(color: color)
            } else {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(color)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }

    /// 3 pulsing dots, tinted to the active speaker's color.
    private func typingDots(color: Color) -> some View {
        PhaseAnimator(PulseWave.allCases) { phase in
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase.scales[i])
                        .opacity(phase.opacities[i])
                }
            }
        } animation: { _ in .easeInOut(duration: 0.35) }
    }

    // MARK: - Helpers

    /// The remote participant who currently holds the speaker lock, if any.
    private func currentRemoteSpeaker() -> User? {
        guard let speakerID = viewModel.room.isSpeaker,
              speakerID != viewModel.localUser.id else { return nil }
        return viewModel.room.participants.first { $0.id == speakerID }
    }

    private func initial(of name: String) -> String {
        String(name.prefix(1)).uppercased()
    }

    /// Stable, deterministic color per speaker — a hash of the speaker's UUID picks
    /// from a readable palette so multiple speakers are visually distinguishable.
    private func speakerColor(for id: UUID) -> Color {
        var hash = 0
        for char in id.uuidString.unicodeScalars {
            hash = (hash &* 31) &+ Int(char.value)
        }
        return SpeakerPalette.colors[abs(hash) % SpeakerPalette.colors.count]
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let last = viewModel.captions.last else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(last.id, anchor: .center)
        }
    }
}

/// Three-dot "typing" wave phases for `aiTypingIndicator`.
private enum PulseWave: CaseIterable {
    case rest, one, two, three

    var scales: [CGFloat] {
        switch self {
        case .rest:  [1.0, 1.0, 1.0]
        case .one:   [1.5, 1.0, 1.0]
        case .two:   [1.0, 1.5, 1.0]
        case .three: [1.0, 1.0, 1.5]
        }
    }

    var opacities: [Double] {
        switch self {
        case .rest:  [0.4, 0.4, 0.4]
        case .one:   [1.0, 0.4, 0.4]
        case .two:   [0.4, 1.0, 0.4]
        case .three: [0.4, 0.4, 1.0]
        }
    }
}

#Preview {
    Meeting_TranscriptView(
        viewModel: MeetingViewModel(
            localUser: User(name: "Preview"),
            networkManager: NetworkManager(),
            asHost: true
        ),
        transcriber: VoiceTranscribeViewModel()
    )
}
