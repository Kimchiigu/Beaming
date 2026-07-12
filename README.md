# Beaming

Beaming is an iOS app that makes small group discussions more accessible for deaf and hard-of-hearing participants.

In a Beaming session, everyone places their iPhone face-down on the table. When someone speaks, **their phone's flashlight blinks**, so a deaf participant can see at a glance who is talking. Deaf participants also get a **live transcription** of the conversation on their screen. Everything runs over the **local network** — no internet connection, cloud service, or account is required.

Built for the Apple Developer Academy **C4 — Urban Innovation Challenge**.

## How it works

- **Create or join a room.** A host starts a discussion and shares a QR code; others scan it to join (up to 8 people).
- **Place the phone face-down.** The screen turns off to save battery while the flashlight stays ready.
- **Speak, and your light blinks.** A shared "speaker lock" makes sure only the current speaker's flashlight is on. When two people talk at once, the loudest signal wins.
- **Read along.** Deaf participants see a live, speaker-labelled transcript.
- **Keep going if the host leaves.** The host role is handed off to the next participant automatically.

## Roles

- **Teman Tuli (Deaf)** — sees the live transcript and the light cues.
- **Teman Dengar (Hearing)** — contributes their voice; their phone blinks when they speak.

## Tech stack

- **UI:** SwiftUI (iOS 26+)
- **Networking:** Apple `Network.framework` with Bonjour (mDNS) peer discovery — fully local, peer-to-peer
- **Audio:** AVFoundation (microphone level detection for the speaker lock + calibration)
- **Speech:** `SFSpeechRecognizer` for live transcription (on-device)
- **Motion:** CoreMotion for face-down detection
- **Camera:** AVFoundation for QR scanning
- **Architecture:** MVVM using Swift Observation (`@Observable`)

## Getting started

1. Open `Beaming.xcodeproj` in Xcode (Xcode 26+).
2. Choose an iOS simulator or a physical device.
3. Run the **Beaming** scheme.
4. On first launch, enter a name and pick a role, then grant the requested permissions (microphone, speech recognition, camera).
5. To test a multi-device session, run on two devices (or a device + simulator) on the same Wi-Fi.

> Permissions are unified on the Home screen. Granting microphone, speech recognition, and camera there means you won't be prompted again mid-session.

## Project structure

```
Beaming/
├── View/            SwiftUI screens (Home, Meeting, Calibration, Onboarding, …)
├── ViewModel/       @Observable view models + managers (Network, Audio, Flashlight, …)
└── Model/           Data types (User, Room, AppState, network messages, …)
```

## Branching

- `main` — stable releases
- `dev/*` — feature work in progress

## Acknowledgments

Built by the Beaming team at the Apple Developer Academy. Thanks to the deaf community members who shaped the design through their feedback.
