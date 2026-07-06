# Beaming — Developer Handoff Document

> **Status as of:** 2026-07-06  
> **Scope:** Backend implementation is functionally complete. This handoff is for a new session to finalize **UI (high-fidelity design) and UX flow polish** on top of the existing backend.  
> **Platform:** iOS (Swift / SwiftUI). Targeting iPhones (tested on iPhone 17s on the same local network).

---

## 1. What Beaming Is

Beaming is a **local P2P accessibility app** for groups that include **Deaf users**. The core idea:

- A **Deaf user** hosts a "room" (they are the audience — they can't hear).
- **Hearing users** join the room and speak freely.
- When a hearing user speaks, **their own phone's flashlight blinks 3 times** to visually signal to the Deaf host _who_ is speaking.
- A **speaker lock** arbitrated by the host ensures only one flashlight activates at a time.
- Designed for small-group settings — e.g., a table conversation with 1 Deaf host + up to 7 hearing guests (max 8 total).

---

## 2. Architecture Overview

```
Beaming/
├── Model/
│   ├── AppState.swift          — Global app state (current user, onboarding flag)
│   ├── User.swift              — User struct (id, name, role, joinedTime)
│   ├── Room.swift              — Room struct (id, name, hostID, participants, isSpeaker)
│   ├── Role.swift              — Enum: .deaf | .hearing
│   └── NetworkMessage.swift    — All P2P message types (Codable enum)
│
├── ViewModel/
│   ├── HomeViewModel.swift     — Room discovery, join/create, role change
│   ├── MeetingViewModel.swift  — Active meeting: speaker lock, audio, network, motion
│   ├── AudioManager.swift      — Mic input, RMS detection, calibration
│   ├── FlashlightManager.swift — 3-blink torch sequence
│   └── NetworkManager.swift   — Bonjour TCP (advertising, browsing, connections)
│
└── View/
    ├── ContentView.swift        — Root nav: shows Onboarding or Home
    ├── OnboardingView.swift     — Name + role entry (first launch only)
    ├── HomeView.swift           — Room list, create/join, role change
    ├── MeetingView.swift        — In-room: participants list + controls
    ├── CalibrationView.swift    — Voice calibration overlay (hearing users only)
    └── FaceDownView.swift       — Overlay shown when phone is face-down on table
```

**State management:** Uses Swift's `@Observable` macro (iOS 17+) throughout. No Combine/MVVM-with-Publishers. Everything is `@Observable class`.

**Navigation:** `NavigationStack` rooted at `ContentView`. `HomeView` → `MeetingView` via `navigationDestination`.

---

## 3. Data Models

### `Role.swift`
```swift
enum Role: String, CaseIterable, Codable, Hashable {
    case deaf
    case hearing

    var title: String { /* "Deaf" | "Hearing" */ }
}
```
> ⚠️ `nonBinary` was removed. Do NOT re-add it. Only `.deaf` and `.hearing` exist.

### `User.swift`
```swift
struct User: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var role: Role
    var joinedTime: Date?   // Used for host handover ordering
    var isSpeaking: Bool    // Currently unused in UI but exists on model
    var isFlashlight: Bool  // Currently unused in UI but exists on model
}
```

### `Room.swift`
```swift
struct Room: Identifiable, Codable {
    var id: UUID
    var name: String          // "{hostName}'s Room"
    var hostID: UUID
    var hostName: String
    var isSpeaker: UUID?      // UUID of current speaker, nil if none
    var participants: [User]  // All users including host (max 8)
    
    var isFull: Bool { participants.count >= 8 }
}
```

### `NetworkMessage.swift`
All messages sent over TCP as JSON. The full enum:

| Case | Direction | Purpose |
|---|---|---|
| `.joinRequest(user:)` | Guest → Host | Guest wants to join |
| `.joinResponse(success:room:reason:)` | Host → Guest | Accept/reject with full room state |
| `.participantUpdate(participants:hostID:roomName:)` | Host → All | Sync room membership (also sent on 3s heartbeat) |
| `.roomInfo(room:)` | Host → Guest | Full room snapshot (legacy, kept for compatibility) |
| `.speakerClaim(userID:rmsLevel:)` | Guest → Host, or Host evaluates locally | Claim the speaker lock |
| `.speakerRelease(userID:)` | Guest → Host | Release the lock (after 0.4s silence) |
| `.speakerStatus(speakerID:)` | Host → All | Broadcast who the speaker is (or nil if released) |
| `.hostHandover(newHostID:)` | Host → All | Reassign host role to oldest guest |
| `.endRoom` | Host → All | Host forcibly closes the room |
| `.leaveRoom(userID:)` | Guest → Host | Guest is leaving |

---

## 4. Networking Layer (`NetworkManager.swift`)

### Transport
- **Protocol:** Raw TCP via Apple's `Network` framework (`NWConnection`, `NWListener`, `NWBrowser`)
- **Discovery:** Bonjour (mDNS) with service type `_beaming._tcp`
- **Framing:** 4-byte big-endian length prefix + JSON body (to handle TCP stream fragmentation)
- **Peer-to-peer:** `params.includePeerToPeer = true` (works on same WiFi or even WiFi Direct)

### Service Name Encoding
Because Bonjour TXT records are unreliable on iOS, the host's name is encoded directly into the **service name** using a delimiter:
```
"{hostName}::::{roomUUID}"
```
Guests parse this to display `"{hostName}'s Room"` in the room list.

### Connection Topology
- **Host** opens an `NWListener`, accepts incoming connections. Keeps a dictionary `peerConnections: [UUID: NWConnection]` for all guests.
- **Guest** opens one `NWConnection` to the host's endpoint. Stored as `hostConnection`.
- All messages from host go to all guests via `broadcastMessage()`.
- Host-to-specific-guest via `sendMessageToPeer(_:peerID:)`.
- Guest-to-host via `sendToHost(_:)`.

### Lifecycle: Two Separate NetworkManagers
> **Critical design decision:** There are TWO separate `NetworkManager` instances:
> 1. `HomeViewModel.browseManager` — used ONLY for Bonjour browsing on the home screen.
> 2. A fresh `NetworkManager` created per meeting session inside `HomeViewModel.joinRoom()` and `HomeViewModel.createRoom()`.
>
> This separation prevents callback collisions that caused "joining creates a new room" bugs.

---

## 5. Home Screen Flow (`HomeViewModel.swift`)

### Room Discovery
- `startDiscovery()` → starts `browseManager.startBrowsing()` + a 1-second polling timer that maps Bonjour results to `[DiscoveredRoom]`.
- `DiscoveredRoom` is a local struct parsed from Bonjour results (parses the `hostName::::roomID` service name format).
- `refreshRooms()` restarts the browser (there's a manual sync button in HomeView for this).

### Joining a Room
```
joinRoom(room:)
  ├── guard !isJoining (prevents double-tap)
  ├── stopDiscovery()
  ├── Create fresh NetworkManager
  ├── 5-second connection timeout (DispatchWorkItem)
  ├── connectToHost(endpoint:localUser:) → sends .joinRequest on connect
  ├── On success: create MeetingViewModel, navigate
  └── On fail/timeout: restart discovery, show alert
```

### Creating a Room
```
createRoom()
  ├── guard !isJoining
  ├── stopDiscovery()
  ├── Create fresh NetworkManager
  ├── Create MeetingViewModel(asHost: true)
  └── Navigate immediately (no async wait)
```

### Returning from Meeting
`HomeView.onAppear` calls `homeViewModel.resetAfterMeeting()` which:
- Clears `activeMeetingVM`
- Resets `navigateToMeeting = false`
- Calls `startDiscovery()` again

---

## 6. Meeting Room Flow (`MeetingViewModel.swift`)

### Initialization
```swift
init(localUser:, networkManager:, asHost:, room:)
```
1. Sets up room (host creates new Room, guest uses placeholder until `joinResponse` arrives)
2. Calls `setupNetworkCallbacks()` (binds message handlers)
3. If host: calls `startHosting()` → starts advertising + 3-second sync timer
4. If hearing role: sets `showCalibration = true` + starts face-down detection

### Speaker Lock System

This is the **core logic** of the app. It's arbitrated entirely by the host device.

**Flow:**
1. Hearing user's mic detects speech above threshold → `AudioManager.onSpeakingStateChanged(true, rmsLevel)`
2. Guest calls `sendToHost(.speakerClaim(userID:rmsLevel:))`; host evaluates its own claim locally
3. Host buffers all incoming claims for **150ms** (`claimWindowDuration`) in `pendingClaims`
4. After 150ms: `resolveCompetingClaims()` picks the claim with the **highest RMS level** (loudest = speaker's own phone, closest to their mouth)
5. Host grants lock: `room.isSpeaker = winnerID` → broadcasts `.speakerStatus(speakerID: winnerID)` to all
6. Winner turns on flashlight (3 blinks), others receive status update and do nothing
7. When speaker stops talking (0.4s silence), sends `.speakerRelease` → host clears lock → broadcasts `.speakerStatus(speakerID: nil)`

**Why RMS-based resolution?**
In testing, phones at a table all pick up ambient sound. The speaker's own phone registers significantly higher RMS because it's closest. This prevents the wrong phone from lighting up.

### Host Handover
When host leaves (`leaveRoom()`):
1. Find oldest guest by `joinedTime`
2. Broadcast `.hostHandover(newHostID:)` + `.participantUpdate`
3. Oldest guest receives handover → `isHost = true` → calls `startHosting()` (starts advertising from their device)

### Participant Sync (Heartbeat)
Host broadcasts `participantUpdate` every **3 seconds** via `syncTimer`. This ensures guests whose connection dropped quietly don't show stale participant lists.

### Cleanup
`cleanup()` is called on leave/end/deinit:
- Stops audio engine
- Turns off flashlight
- Stops accelerometer
- Invalidates all timers
- Disconnects all network peers

---

## 7. Audio System (`AudioManager.swift`)

### Calibration Flow (mandatory for hearing users)
1. User enters meeting → `CalibrationView` overlay appears (full screen, black)
2. User reads the calibration phrase aloud: **"Hello everyone, I am ready to start this meeting."**
3. `startCalibration()` runs the audio engine for **5 seconds**, collecting RMS samples
4. Filters out noise floor (RMS < 0.002), averages the rest → `calibratedRMS`
5. Sets `audioThreshold = calibratedRMS * 0.5` (50% of the user's own voice level)
6. After 0.8s delay, `showCalibration = false` → `setupAudio()` begins listening

**Why 50%?** Their own voice registers much higher RMS than a friend's voice from across a table. Setting threshold at 50% of their own voice means their speech easily triggers it, while ambient sound from others typically registers at 20–30% (below threshold).

> ⚠️ **Calibration is MANDATORY.** The Skip button was intentionally removed. Do not re-add it.

### Speech Detection
```
processAudioBuffer()
  ├── Calculate RMS from AVAudioPCMBuffer
  ├── If calibrating: collect to calibrationSamples[], return
  ├── If rms > audioThreshold:
  │     ├── consecutiveAboveThresholdFrames++
  │     ├── Cancel silenceTimer
  │     └── If frames >= 3 (requiredConfirmationFrames) AND !isSpeaking:
  │           → isSpeaking = true
  │           → onSpeakingStateChanged(true, rms)
  └── Else:
        ├── Reset consecutiveAboveThresholdFrames = 0
        └── If isSpeaking and no silenceTimer: start 0.4s timer
              → on fire: isSpeaking = false, onSpeakingStateChanged(false, 0.0)
```

**Multi-frame confirmation:** Requires 3 consecutive frames above threshold before triggering. Filters out transient spikes (coughs, table knocks).

**Silence timeout:** 0.4 seconds. After 0.4s of silence, the lock is released. This is intentionally short for snappy speaker handoff.

### Audio Session Configuration
```swift
AVAudioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
```
`mode: .measurement` disables Apple's automatic gain control (AGC), which would otherwise normalize levels and defeat RMS-based discrimination.

---

## 8. Flashlight System (`FlashlightManager.swift`)

When a speaker lock is granted, the behavior is:
- **3 quick blinks** (ON 0.15s → OFF 0.15s × 3 cycles), total ~0.75s
- Then flashlight stays **OFF** for the rest of the speaking duration
- This signals "someone started talking" without being blinding or distracting

The flashlight turns OFF immediately when `setFlashlight(on: false)` is called (e.g., speaker releases lock, or speaker gets overridden by new lock).

---

## 9. Device Sensors

### Accelerometer (Face-Down Detection)
Used to detect when a hearing user places their phone face-down on the table (passive listening mode).
- `CMMotionManager`, polling every 0.3s
- `isFaceDown = data.acceleration.z > 0.7` (positive Z = screen facing down)
- When face-down: `FaceDownView` overlay is shown (full screen, prompts to flip phone up to speak)
- Only activates for `.hearing` role users

---

## 10. Persistence / State (`AppState.swift`)

Stored in `UserDefaults`:
- `hasOnboarded: Bool` — whether onboarding was completed
- `userName: String`
- `userRole: String` (raw value of `Role`)
- `userID: String` (UUID, stable across sessions — critical for reconnecting)

User ID is **stable**: the same UUID is reused if the user re-launches the app. This is important so a host who re-creates a room isn't treated as a stranger by their previous guests.

---

## 11. Required Info.plist Keys

The following must be in `Info.plist` (already added, documented here for reference):

| Key | Value | Reason |
|---|---|---|
| `NSMicrophoneUsageDescription` | `"Beaming uses the microphone to detect when you're speaking."` | Mic access for hearing users |
| `NSLocalNetworkUsageDescription` | `"Beaming uses your local network to connect with others in the same room."` | Bonjour discovery |
| `NSBonjourServices` | `["_beaming._tcp"]` | Bonjour service type registration |

---

## 12. Current View State

### `ContentView.swift`
Simple root: if `appState.hasOnboarded` → `HomeView`, else → `OnboardingView`. Wrapped in `NavigationStack`.

### `OnboardingView.swift`
- Name text field + Role picker (Deaf / Hearing)
- Requests microphone permission for Hearing role on "CONTINUE"
- Saves to `AppState` via `appState.saveUser(name:role:)`
- **UI: minimal/functional, no high-fidelity design yet**

### `HomeView.swift`
- Header: "Welcome, {name}" + role switcher (tappable `Menu`) + sync button (↻)
- Room list: scrollable cards with room name + join arrow (or empty state)
- Create Room button (bottom, full width, disabled + shows spinner while `isJoining`)
- Role change triggers mic permission request if switching to hearing
- **UI: minimal/functional, no high-fidelity design yet**

### `MeetingView.swift`
- Header: room name + participant count (X/8)
- Participants list: name, role badge, HOST pill, speaker waveform indicator
- Calibration overlay (`CalibrationView`) shown first for hearing users
- FaceDown overlay shown when phone is face-down
- Controls (bottom): End button (host only), Mic toggle (hearing only), Leave button (all)
- **UI: minimal/functional, no high-fidelity design yet**

### `CalibrationView.swift`
- Full-screen black overlay
- Shows calibration phrase: "Hello everyone, I am ready to start this meeting."
- "Start Calibration" button → 5-second recording with live audio level bars + progress bar
- Success state → auto-dismisses into meeting after 0.8s
- **UI: functional, but visually basic**

### `FaceDownView.swift`
- Simple full-screen overlay shown when hearing user's phone is face-down
- Prompts user to flip phone to speak

---

## 13. Known Limitations / Open Issues

| Issue | Status | Notes |
|---|---|---|
| Calibration might need retry | TBD | If user doesn't speak during calibration, `isCalibrated = false` and threshold falls back to default 0.015. No retry UI exists yet. |
| Speaker lock not re-queued | By design | If someone speaks while lock is held, their claim is silently dropped. The 150ms window only runs when the lock is free. |
| `skipCalibration()` function still exists in `MeetingViewModel` | Dormant | Not called from UI anymore. Can be removed or kept as debug escape hatch. |
| FaceDown detection logic direction | Confirmed correct | `z > 0.7` = face down (screen to table). Was previously inverted — now fixed. |
| Room list shows "Unknown's Room" | Fixed | Was a parsing bug in service name. Now uses `hostName::::roomUUID` format reliably. |
| Simulator testing | Limited | Bonjour discovery between iOS simulators on same Mac can be unreliable; always test on real devices. |
| Max room size hardcoded at 8 | By design | `Room.isFull` = `participants.count >= 8`. |

---

## 14. What Needs to Be Done (Next Session)

The backend is functionally complete. The next session should focus on:

### 14.1 UI Polish (High Fidelity)
All views currently have placeholder/minimal styling. The design system needs to be built out. Views to redesign:
- `OnboardingView` — first impression, should feel premium
- `HomeView` — room cards should be visually rich; role switcher UX
- `MeetingView` — participant list needs redesign; speaker state should be visually exciting (who is speaking clearly visible to everyone, especially the Deaf host)
- `CalibrationView` — the phrase display and level meters could be much more polished
- `FaceDownView` — needs a clear, readable, high-contrast design

### 14.2 UX Flow Decisions (TBC)
These are design decisions that need confirmation before implementation:

| Decision | Options to Consider |
|---|---|
| **Deaf host view** | Should the host have a very different, prominent view of who is speaking? Currently they see the same list as guests. |
| **Speaker identity on screen** | When someone is speaking, how prominently is their name shown on ALL devices (not just the speaker's own)? |
| **Calibration failure state** | What happens if calibration doesn't capture enough voice data? Show retry UI? |
| **Participant join/leave animations** | Should participants animate in/out of the list? |
| **Onboarding multi-page** | Current onboarding is one screen. Should there be an intro/walkthrough? |
| **Deaf host "who is speaking" indicator** | The flashlight is the core feature. Should there also be a persistent on-screen notification? |
| **Host vs. Guest role visual distinction** | Should hearing guests who are also the host (after handover) see a different UI? |

### 14.3 Minor Backend TODOs (Optional)
- **Calibration retry UI:** If `isCalibrated == false` after calibration (not enough voice data), the current behavior silently falls back. A "Try Again" button would improve reliability.
- **Remove `skipCalibration()`** from `MeetingViewModel` (no longer called, was for debugging).
- **`isSpeaking` and `isFlashlight` on `User` model** are populated nowhere currently — if the new UI wants to show real-time "is speaking" states per participant, these fields need to be kept in sync via network messages.

---

## 15. Key Implementation Gotchas

1. **`@Observable` + `@State`:** ViewModels that are `@Observable` must be stored in `@State` in the view (e.g., `@State var viewModel: MeetingViewModel`). They cannot be `@StateObject` because that's for `ObservableObject`.

2. **Timer + weak self:** Every Timer closure captures `self` weakly to avoid retain cycles with the `@Observable` classes.

3. **Audio engine lifecycle:** Calling `inputNode.removeTap(onBus: 0)` BEFORE `engine.stop()` is important. Reversing the order can cause crashes on teardown.

4. **Bonjour on real devices:** Must be on the same local network. The `NSLocalNetworkUsageDescription` permission is required — iOS will prompt the user on first discovery attempt.

5. **Two NetworkManagers:** Do NOT merge browsing and meeting into one `NetworkManager`. The separation is intentional — if the same instance handles both browsing and connection callbacks, they overwrite each other.

6. **MeetingViewModel owns AudioManager:** `audioManager` is an instance variable on `MeetingViewModel`. Its callbacks (`onSpeakingStateChanged`) are set up in `setupAudio()`, which is called AFTER calibration completes — not on init.

7. **Host is always participant[0]:** In `Room.init`, the host user is always inserted at index 0 with `joinedTime = Date()`. Guest `joinedTime` is set by the host when processing `.joinRequest` (not by the guest themselves — this prevents clock skew issues).

---

## 16. File Reference Table

| File | Key Responsibilities |
|---|---|
| [Role.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/Role.swift) | Role enum (deaf/hearing) |
| [User.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/User.swift) | User data model |
| [Room.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/Room.swift) | Room data model, capacity check |
| [NetworkMessage.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/NetworkMessage.swift) | All P2P message types |
| [AppState.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/AppState.swift) | UserDefaults persistence, current user |
| [NetworkManager.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/NetworkManager.swift) | TCP connections, Bonjour, framing |
| [AudioManager.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/AudioManager.swift) | Mic input, calibration, RMS detection |
| [FlashlightManager.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/FlashlightManager.swift) | 3-blink torch sequence |
| [HomeViewModel.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/HomeViewModel.swift) | Discovery, join/create, role change |
| [MeetingViewModel.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/MeetingViewModel.swift) | Speaker lock, all in-meeting logic |
| [ContentView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ContentView.swift) | Root nav gate |
| [OnboardingView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/OnboardingView.swift) | First launch setup |
| [HomeView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/HomeView.swift) | Room list, create button |
| [MeetingView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/MeetingView.swift) | Active meeting screen |
| [CalibrationView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/CalibrationView.swift) | Voice calibration overlay |
| [FaceDownView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/FaceDownView.swift) | Face-down mode overlay |
