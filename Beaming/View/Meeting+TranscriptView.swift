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
        .background(BeamingPalette.purple)
        .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.5, anchor: .leading)
                .opacity(phase.isIdentity ? 1.0 : 0.4)
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

    @ViewBuilder
    private var indicators: some View {
        let remote = currentRemoteSpeaker()
        if viewModel.isLocalSpeaking || remote != nil {
            HStack(spacing: 10) {
                if viewModel.isLocalSpeaking {
                    aiTypingIndicator
                }
                if let remote {
                    remoteSpeakerBadge(remote)
                }
            }
        }
    }

    /// "menulis" + 3 pulsing dots — shown while the local engine is mid-turn.
    private var aiTypingIndicator: some View {
        HStack(spacing: 6) {
            Text("menulis")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BeamingPalette.purple)
            PhaseAnimator(PulseWave.allCases) { phase in
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(BeamingPalette.purple)
                            .frame(width: 8, height: 8)
                            .scaleEffect(phase.scales[i])
                            .opacity(phase.opacities[i])
                    }
                }
            } animation: { _ in .easeInOut(duration: 0.35) }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }

    /// Speaker-initial circle + speaker icon — shown when a remote holds the floor.
    private func remoteSpeakerBadge(_ speaker: User) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(BeamingPalette.purple)
                    .frame(width: 28, height: 28)
                Text(initial(of: speaker.name))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14))
                .foregroundStyle(BeamingPalette.purple)
            Text(speaker.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(BeamingPalette.purple)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
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
