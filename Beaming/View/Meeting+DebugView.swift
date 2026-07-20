//
//  Meeting+DebugView.swift
//  Beaming
//
//  Debug overlay for hearing ("Teman Dengar") participants. Lets you confirm, on
//  device, that (a) the live transcription is flowing and (b) the FluidAudio
//  voice-activity + owner recognition is behaving — with a live confidence log and a
//  tunable match threshold. Shown only via the Dengar toolbar's ladybug button; the
//  Tuli interface is untouched.
//

import SwiftUI

struct Meeting_DebugView: View {
    let viewModel: MeetingViewModel
    let transcriber: VoiceTranscribeViewModel

    @Environment(\.dismiss) private var dismiss

    private var audio: AudioManager { viewModel.audioManager }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    recognitionCard
                    confidenceCard
                    roomCard
                    transcriptCard
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Voice recognition

    private var recognitionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice recognition")
                .font(.system(size: 17, weight: .bold))

            HStack(spacing: 8) {
                Circle()
                    .fill(audio.vadTriggered ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 12, height: 12)
                Text(audio.vadTriggered ? "Voice detected" : "Silence")
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Text(audio.isSpeaking ? "claiming lock" : "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "Mic level (RMS): %.4f", audio.audioLevel))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                RMSMeter(level: audio.audioLevel)
            }

            Divider()

            // Live threshold tuning — raise it if non-owners are scoring above it.
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Match threshold")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(String(format: "%.2f", audio.ownerMatchThreshold))
                        .font(.system(size: 14, weight: .semibold).monospacedDigit())
                        .foregroundStyle(BeamingPalette.purple)
                }
                Slider(
                    value: Binding(
                        get: { audio.ownerMatchThreshold },
                        set: { audio.ownerMatchThreshold = $0 }
                    ),
                    in: 0.3...0.9
                )
                .tint(BeamingPalette.purple)
                Text("How close a voice must be (0–1 similarity) to count as you. Lower = more voices pass; higher = stricter. Your own voice is usually 0.6–0.95; others usually stay below ~0.5.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            row("Enrolled (owner)", audio.ownerEmbedding == nil ? "No" : "Yes (256-d)")
            row("Accept / Reject", "\(audio.ownerAcceptCount) / \(audio.ownerRejectCount)")
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Confidence log

    private var confidenceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Confidence log")
                    .font(.system(size: 17, weight: .bold))
                Spacer()
                Text(verificationSummary)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(lastColor)
            }

            if audio.verificationHistory.isEmpty {
                Text("No verifications yet — speak to populate.\nEach utterance is checked at ~0.6s and again as it grows.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else {
                // Newest at the top for easy reading.
                ForEach(audio.verificationHistory.reversed()) { record in
                    HStack(spacing: 10) {
                        Image(systemName: record.isOwner ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(record.isOwner ? .green : .red)
                        Text(String(format: "%.2f", record.similarity))
                            .font(.system(size: 15, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(String(format: "%.1fs", record.seconds))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                        // Visual bar relative to the current threshold.
                        ConfidenceBar(similarity: record.similarity, threshold: audio.ownerMatchThreshold)
                            .frame(width: 72, height: 6)
                    }
                }
            }
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var verificationSummary: String {
        guard let last = audio.verificationHistory.last else { return "" }
        return String(format: "%@ %.2f", last.isOwner ? "Owner" : "Other", last.similarity)
    }

    private var lastColor: Color {
        guard let last = audio.verificationHistory.last else { return .secondary }
        return last.isOwner ? .green : .red
    }

    // MARK: - Room state

    private var roomCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Room state")
                .font(.system(size: 17, weight: .bold))
            row("Lock holder", lockHolderText)
            row("Speaking participants", "\(viewModel.speakingParticipants.count)")
            row("Captions on", transcriber.isTranscribing ? "Yes" : "No")
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var lockHolderText: String {
        guard let id = viewModel.room.isSpeaker else { return "none" }
        return id == viewModel.localUser.id
            ? "you (\(viewModel.localUser.name))"
            : (viewModel.room.participants.first { $0.id == id }?.name ?? String(id.uuidString.prefix(8)))
    }

    // MARK: - Transcript

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transcript")
                .font(.system(size: 17, weight: .bold))

            if viewModel.captions.isEmpty && viewModel.liveCaption == nil {
                Text("Menunggu percakapan…")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                ForEach(viewModel.captions) { caption in
                    captionRow(speaker: caption.speakerName, text: caption.text, tentative: false)
                }
                if let live = viewModel.liveCaption {
                    captionRow(speaker: live.speakerName, text: live.text.isEmpty ? "…" : live.text, tentative: true)
                }
            }
        }
        .padding(20)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func captionRow(speaker: String, text: String, tentative: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(speaker)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(BeamingPalette.purple)
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(tentative ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(size: 14, weight: .medium)).monospacedDigit()
        }
    }
}

/// A bar tracking the live RMS level.
private struct RMSMeter: View {
    let level: Float

    private var fraction: CGFloat {
        min(max(CGFloat(level) * 4.0, 0), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.25))
                Capsule().fill(fraction > 0.66 ? Color.green : (fraction > 0.33 ? Color.yellow : Color.red))
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 8)
    }
}

/// A fixed-width confidence bar: fills up to the similarity value and marks the
/// current threshold with a tick so owner-vs-other is visible at a glance.
private struct ConfidenceBar: View {
    let similarity: Float
    let threshold: Float

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.2))
                Capsule()
                    .fill(similarity >= threshold ? Color.green : Color.red)
                    .frame(width: w * CGFloat(min(max(similarity, 0), 1)))
                // Threshold tick.
                Rectangle()
                    .fill(Color.black.opacity(0.55))
                    .frame(width: 2)
                    .offset(x: w * CGFloat(min(max(threshold, 0), 1)))
            }
        }
    }
}
