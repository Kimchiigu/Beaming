//
//  Meeting+TranscriptView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 11/07/26.
//

import SwiftUI

/// The Transcript tab shown to a deaf ("Teman Tuli") participant. A vertical card
/// carousel where the centered ("picked") card is full-size/full-opacity and the rest
/// scale down + dim, plus:
///  - An in-progress "loading" card for whoever currently holds the speaker lock,
///    shown the instant they start speaking and while they keep talking.
///  - A multi-speaker indicator: overlapping avatar circles for everyone ELSE who is
///    talking at the same time, with a speaker icon on the right.
/// The speaker lock (flashlight) logic is untouched — these are indicators only.
struct Meeting_TranscriptView: View {
    let viewModel: MeetingViewModel
    let transcriber: VoiceTranscribeViewModel

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                if viewModel.captions.isEmpty && activeSpeaker() == nil {
                    // Centered empty state (icon + "Menunggu percakapan…").
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.captions) { msg in
                                    captionCard(msg)
                                        .id(msg.id)
                                }

                                // In-progress card for the current speaker (text incoming).
                                if let speaker = activeSpeaker() {
                                    inProgressBox(speaker)
                                        .id("inProgress")
                                }
                            }
                            .scrollTargetLayout()
                            // Generous vertical padding so any content-sized card can center.
                            .padding(.vertical, geometry.size.height / 2)
                        }
                        .scrollTargetBehavior(.viewAligned)
                        // Advance only when a turn finalizes (a new caption lands) — the
                        // previous card stays centered while the in-progress card is up.
                        .onChange(of: viewModel.captions.count) { _, _ in scrollToLatest(proxy) }
                        .onAppear { scrollToLatest(proxy) }
                    }
                }

                // Multi-speaker indicator: avatars of other active speakers + speaker icon.
                if !otherSpeakers().isEmpty {
                    speakerBar
                        .padding(.horizontal, 24)
                        .padding(.bottom, 10)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.speakingParticipants)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Caption card (carousel — picked card is full size, others scale/dim)

    private func captionCard(_ msg: CaptionMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(msg.speakerName)
                .font(.system(size: 40, weight: .bold))
            Text(msg.text)
                .font(.system(size: 28))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(speakerColor(for: msg.speakerID))
        .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.5, anchor: .leading)
                .opacity(phase.isIdentity ? 1.0 : 0.4)
                .offset(y: phase.value * 40)
        }
    }

    // MARK: - In-progress card (current lock holder, transcript loading)

    private func inProgressBox(_ speaker: User) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(speaker.name)
                .font(.system(size: 40, weight: .bold))
            if let live = viewModel.liveCaption, !live.text.isEmpty {
                Text(live.text)
                    .font(.system(size: 28))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                bigLoadingDots
            }
        }
        .foregroundStyle(.white)
        .padding(36)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(speakerColor(for: speaker.id))
        .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
        .scrollTransition(.interactive, axis: .vertical) { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1.0 : 0.5, anchor: .leading)
                .opacity(phase.isIdentity ? 1.0 : 0.4)
                .offset(y: phase.value * 40)
        }
    }

    /// Big 3-dot loading wave — shown while the speaker's turn is in progress.
    private var bigLoadingDots: some View {
        PhaseAnimator(PulseWave.allCases) { phase in
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(.white)
                        .frame(width: 20, height: 20)
                        .scaleEffect(phase.scales[i])
                        .opacity(phase.opacities[i])
                }
            }
        } animation: { _ in .easeInOut(duration: 0.4) }
    }

    // MARK: - Multi-speaker indicator bar

    private var speakerBar: some View {
        let others = otherSpeakers()
        return HStack(spacing: 8) {
            HStack(spacing: -8) {
                ForEach(others, id: \.id) { speaker in
                    avatarCircle(speaker)
                }
            }
            Spacer()
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(BeamingPalette.purple)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
    }

    private func avatarCircle(_ user: User) -> some View {
        let color = speakerColor(for: user.id)
        return ZStack {
            Circle().fill(color).frame(width: 34, height: 34)
            Text(initial(of: user.name))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay {
            Circle().stroke(.white, lineWidth: 2).frame(width: 34, height: 34)
        }
    }

    // MARK: - Empty state (centered)

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "captions.bubble")
                .font(.system(size: 40))
                .foregroundStyle(BeamingPalette.purple.opacity(0.5))
            HStack(spacing: 0) {
                Text(transcriber.isTranscribing ? "Mendengarkan" : "Menunggu percakapan")
                // Looping loading dots: "." → ".." → "..." → "." …
                PhaseAnimator([1, 2, 3]) { phase in
                    Text(String(repeating: ".", count: phase))
                } animation: { _ in .easeInOut(duration: 0.4) }
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(BeamingPalette.purple)
        }
    }

    // MARK: - Helpers

    /// The lock holder — the "first"/primary speaker, shown as the in-progress card.
    /// Falls back to whoever is streaming a live partial so the transcript shows even
    /// if the speaker lock isn't currently signaled (e.g. mid breath pause).
    private func activeSpeaker() -> User? {
        if let speakerID = viewModel.room.isSpeaker {
            if speakerID == viewModel.localUser.id { return viewModel.localUser }
            if let p = viewModel.room.participants.first(where: { $0.id == speakerID }) { return p }
        }
        if let live = viewModel.liveCaption {
            if live.speakerID == viewModel.localUser.id { return viewModel.localUser }
            if let p = viewModel.room.participants.first(where: { $0.id == live.speakerID }) { return p }
            return User(name: live.speakerName, id: live.speakerID)
        }
        return nil
    }

    /// Other participants currently speaking (excluding the lock holder) — shown as avatars.
    private func otherSpeakers() -> [User] {
        let lockID = viewModel.room.isSpeaker
        return viewModel.speakingParticipants.compactMap { id in
            if id == lockID { return nil }
            if id == viewModel.localUser.id { return viewModel.localUser }
            return viewModel.room.participants.first { $0.id == id }
        }
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

    /// Center the latest FINALIZED caption. The in-progress card is only centered when
    /// there are no finalized captions yet (first speech) — otherwise the previous card
    /// stays put while a speaker's turn is in progress.
    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if let last = viewModel.captions.last {
                proxy.scrollTo(last.id, anchor: .center)
            } else if activeSpeaker() != nil {
                proxy.scrollTo("inProgress", anchor: .center)
            }
        }
    }
}

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

/// Three-dot wave phases for the big loading dots.
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
