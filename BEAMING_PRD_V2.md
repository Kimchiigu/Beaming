# BEAMING — PRD V2 (Post-Deaf-User-Test Pivot)

> **Status:** Source of truth for the V2 redesign. Supersedes `BEAMING_PRD_FINAL.md`
> where the two conflict (FINAL stays valid for everything *not* mentioned here).
> A fresh Claude session can build V2 from this spec. **Reuse the existing P2P
> business logic** (NetworkManager / AudioManager / FlashlightManager / speaker-lock
> arbitration) — only the *models, role handling, transcription pipeline, and the
> in-meeting UI* change.
>
> **Figma source:** file `HXmV0k07oA0saJ6liKmonz` ("Challenge 4 - Cisauk"),
> frame **Hi-Fi-Final-Frame** (`287:1670`). Mascot SVGs in repo at `mascot/`.

---

## 0. Why V2 exists (the pivot)

We tested the FINAL app with **deaf users. They rejected it.** The core problem:

> FINAL forced the deaf participant to **watch other people's phones blink** and to
> **not really use the app**. That is passive, distant, and tells them *who* is
> talking but never *what* is being said. Deaf users wanted to **participate from
> their own screen**.

**V2 keeps the beacon idea for hearing participants** (phones face-down, flashlight
blinks on the active speaker — unchanged), **and adds a rich screen experience for
the deaf participant**, who now **holds their phone face-up** and sees, in real time:

1. **Who is speaking** — the active speaker's chip/avatar is highlighted (green ring + glow + scale).
2. **What is being said** — **live captions** streamed to the screen, attributed to the current speaker.

This is enabled by Apple's **Speech framework** (`SFSpeechRecognizer`), for which a
`VoiceTranscribeViewModel.swift` already exists in the repo (added 09/07).

### Delta from FINAL in one line
FINAL = "everyone is a silent beacon; the deaf person watches from outside the app."
**V2 = "hearing people are beacons; the deaf person is the active viewer with live captions + speaker identity on their own screen."**

---

## 1. Product Overview

Beaming is an offline, local-P2P iOS app for small group discussions (up to 8).

- **Hearing participants** place phones **face-down**; their flashlight blinks when
  they speak (beacon — unchanged). Their device also **transcribes their own speech**
  and broadcasts the caption.
- **The deaf participant** holds the phone **face-up** and watches: the active
  speaker is highlighted and their **live caption** is shown. The deaf device does
  **not** need to be the speaker; it receives captions broadcast by whoever is speaking.

No cloud, no internet — only Wi-Fi/AWDL (`Network.framework`, Bonjour/mDNS, custom TCP).

---

## 2. Tech Stack & Architecture

Same as FINAL (SwiftUI, MVVM `@Observable`, Network.framework, UserDefaults, no SPM, forced light scheme). **Add:**

- **Speech framework** (`SFSpeechRecognizer`, `SFSpeechAudioBufferRecognitionRequest`) for on-device (locale-available) speech-to-text. Already scaffolded in `ViewModel/VoiceTranscribeViewModel.swift` (`SpeechRecognizer` actor).
- **AVAudioSession coordination** — transcription and RMS detection must share (or sequence over) the audio engine input tap. ⚠️ See §9 risk.

---

## 3. Final User Flow (V2)

```
Home ──Mulai diskusi (Create)──▶ Role sheet ▶ Permission sheet ▶ (host advertises) ▶ Calibration ▶ Mode Diskusi
  └──Scan QR (Join)─────────────▶ Role sheet ▶ Permission sheet ▶ QR scanner ▶ connect ▶ Calibration ▶ Mode Diskusi
```

- **Home:** branded greeting + two cards (unchanged from FINAL §6.1).
- **Role sheet (NEW):** "Bagaimana kamu akan mengikuti diskusi?" → **"Saya Tuli"** (Deaf) or **"Saya Mendengar"** (Hearing). Shown **after** tapping Create/Join, **before** permission. Choice is remembered per-session (not persisted unless we decide otherwise — see §16 Q1).
- **Permission sheet:** Mic + Local Network (FINAL §6.2). For Deaf role, also explains Speech Recognition (see §13 for the new Info.plist key).
- **Calibration:** unchanged 3-state flow (FINAL §6.4). For **Deaf role, calibration can be skipped** (they are an observer — no mic sensitivity needed); see §16 Q2.
- **Mode Diskusi:** **branched by role**:
  - **Deaf role → "Caption View"** (face-up): active-speaker highlight + live caption stream + participant strip. No flashlight. No face-down overlay.
  - **Hearing role → "Beacon View"** (face-down): FINAL §6.5 behavior — flashlight blinks on active speaker, `FaceDownView` when face-down.

---

## 4. Locked Product Decisions (V2)

1. **`Role` returns** — but lightweight: `enum Role { case deaf, hearing }`. Add `role: Role` back to `User`. `AppState` no longer auto-assumes; role is chosen in the **Role sheet** and stored on the in-memory `currentUser` (and optionally `UserDefaults`).
2. **The deaf participant is the primary viewer.** Their experience is a dedicated **Caption View** (face-up). They may speak too (their device will beacon + transcribe like any hearing participant if they choose to — see §16 Q3).
3. **Live captions are transcribed on the active speaker's device and broadcast.** Attribution model: the device holding the speaker lock runs `SFSpeechRecognizer` on its own mic and sends `caption(userID, text)` to the room. The Deaf device displays incoming captions keyed by speaker. (Rationale: only the speaker's device has clean, attributed access to its own voice; avoids the multi-talker crosstalk problem on the Deaf device's mic.)
4. **Hearing experience is FINAL's beacon, unchanged.** Same flashlight blink, same face-down overlay, same menu (Kode QR / Keluar).
5. **Discussion screen is no longer identical for everyone** — it branches by `currentUser.role`. Host/guest split is orthogonal (host handles arbitration) and stays as in FINAL.
6. **Calibration:** Hearing users calibrate (3.5 s, as today). Deaf users **skip** to the meeting (default decision; revisit in §16 Q2).
7. **Copy is Bahasa Indonesia.** Caption UI in Indonesian; transcribed *content* is whatever language is spoken (respect `SFSpeechRecognizer` locale).
8. **All toolbar buttons stay standardized** at `GlassIconButton` 36pt (FINAL's recent fix is preserved).
9. **Palette unchanged** — primary `#2C755D`, secondary `#94F2CF/20`, wordmark gradient `#6BBF9B→#A3D5A0` (FINAL's locked palette).

---

## 5. Design System additions (`Component/Theme.swift`)

Keep everything in FINAL §5 / current `Theme.swift`. Add tokens for the caption view:

| Token | Value | Use |
|---|---|---|
| `BeamingPalette.speakerRing` | `green` (`#2C755D`) | ring around the active speaker's chip |
| `BeamingPalette.speakerGlow` | `yellow.opacity(0.5)` radial | soft glow behind active speaker (reuse the MeetingView glow) |
| `BeamingPalette.captionText` | `.black` | caption body text |
| `BeamingPalette.captionAttribution` | `green` | "Name:" label before a caption line |

Add a reusable `SpeakerChip(user:, isSpeaking:)` view and a `CaptionBubble(name:, text:, isLive:)` view (both in `Component/`, e.g. a new `CaptionComponents.swift`). Keep `PrimaryButtonStyle`, `beamingCard`, `GlassIconButton`, `BlobShape` as-is.

---

## 6. Screen-by-Screen Spec (V2)

### 6.1 Home (`View/HomeView.swift`) — UNCHANGED from FINAL §6.1
Two cards. No role UI here.

### 6.2 Role sheet (NEW — `View/RoleSheet.swift`)
Full-screen or `.sheet` `.presentationDetents([.medium, .large])`. Light bg + blobs.
- Title: **"Bagaimana kamu akan mengikuti diskusi?"** (22 bold).
- Mascot (reuse `MascotHome` or a small variant).
- Two big cards (reuse `HomeActionCard` styling):
  - **"Saya Tuli"** — icon `eye.fill` (or `captions.bubble`), accent `green`. Caption: *"Lihat siapa yang bicara dan baca teks langsung di layarmu."*
  - **"Saya Mendengar"** — icon `lightbulb.fill`, accent `blue`. Caption: *"Letakkan HP terlentang. Lampu akan menyala saat kamu bicara."*
- Selecting either sets `currentUser.role` and proceeds to Permission (Create) or Permission→Scanner (Join).
- Standard `GlassIconButton("xmark")` close → cancels back to Home.

### 6.3 Permission sheet (`View/PermissionSheet.swift`) — FINAL §6.2 + Speech row
Add a **third row** when role == `.deaf` (or always, since hearing speakers also transcribe):
- **Pengenalan Suara** — chip color TBD (e.g. `greenTint`), icon `"waveform.badge.magnifyingglass"` (or `"text.bubble"`), desc: *"Mengubah ucapan menjadi teks langsung di perangkat agar bisa ditampilkan sebagai teks."* End with `checkmark.circle.fill` (green).
(Three rows total: Mikrofon, Jaringan Lokal, Pengenalan Suara.)

### 6.4 QR scanner — UNCHANGED (FINAL §6.3).

### 6.5 Calibration (`View/CalibrationView.swift`) — FINAL §6.4, **skip for deaf**
- Hearing: full 3-state flow as today.
- **Deaf: skip entirely** — `MeetingViewModel` should not set `showCalibration = true` for `.deaf`; go straight to the meeting. (Revisit §16 Q2.)

### 6.6 Mode Diskusi — **BRANCHED by role**

#### 6.6a Caption View (`View/CaptionView.swift`, NEW) — Deaf role, face-up
This is the **headline new screen.** White + blobs.
- **Top:** participant pill `"\(n) orang di dalam diskusi"` (reuse the FINAL pill) **+** a row of **`SpeakerChip`s** (one per participant; the active speaker gets a green ring + glow + scale 1.1). Local user chip labeled "Kamu".
- **Center / main:** a **scrollable caption feed**. Each entry is a `CaptionBubble`:
  - `Text(name + ":")` (15 semibold, `captionAttribution` green).
  - `Text(captionText)` (17, black).
  - The **currently live** caption (from the active speaker) is rendered larger / with a typing pulse; finalized captions sit above it in the scroll history.
  - Empty state (no one speaking yet): mascot (`MascotMeeting`) + *"Menunggu seseorang mulai berbicara…"*
- **Bottom:** standalone **QR pill** (`Tunjukkan Kode QR`, host only — same as FINAL) so the deaf host can still invite. Trailing/leading toolbar = `GlassIconButton` exit-door (red) → `leaveRoom()` (same as FINAL §6.5).
- **No face-down overlay.** (Deaf user holds the phone; if they do lay it down, we can dim but keep captions — see §16 Q4.)
- **No flashlight.**

#### 6.6b Beacon View (`View/MeetingView.swift`) — Hearing role, FINAL §6.5, UNCHANGED
Participant pill + mascot + face-down instruction + QR pill + exit-door back. Flashlight blinks on active speaker. `FaceDownView` when face-down. **Plus:** while this device is the active speaker, it runs transcription and broadcasts captions (see §8). The UI does not show captions locally (hearing user is face-down).

### 6.7 QR share sheet — UNCHANGED (FINAL §6.6).

### 6.8 FaceDownView — UNCHANGED (hearing only in V2).

---

## 7. Data Models (`Model/`)

### `User.swift` (V2 — role returns)
```swift
enum Role: String, Codable { case deaf, hearing }

struct User: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var role: Role = .hearing        // NEW
    var joinedTime: Date?
    init(name: String, id: UUID = UUID(), role: Role = .hearing) {
        self.id = id; self.name = name; self.role = role
    }
    static func == (lhs: User, rhs: User) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```
`Role` lives in `User.swift` (or a small `Role.swift`). `AppState.currentUser.role` defaults to `.hearing` until the Role sheet sets it; persist `"userRole"` in `UserDefaults` if we decide to remember it (§16 Q1).

### `Room.swift` — UNCHANGED structurally.
`participants: [User]` now carry `role`, so the Deaf device knows who is who. Consider a computed `var deafParticipants / hearingParticipants` if useful.

### `NetworkMessage.swift` (V2 — add caption)
Keep all FINAL cases. **Add:**
```swift
/// Live or finalized caption from the active speaker (userID) — text attributed to them.
case caption(userID: UUID, text: String, isFinal: Bool)
```
(`isFinal: false` = partial/live update to replace the previous partial from the same user; `true` = commit to history.)

### `AppState.swift` (V2)
`currentUser` non-optional as FINAL, but `role` defaults to `.hearing` and is updated by the Role sheet. Optional: persist role under `"userRole"`.

---

## 8. Business Logic (V2 changes)

Reuse FINAL §8 entirely. Changes:

### `MeetingViewModel`
- **Role-aware init:** accept `currentUser` (which now has `role`). Decide branch:
  - `showCalibration = (localUser.role == .hearing)` — **deaf skips calibration.**
  - Face-down detection (`startFaceDownDetection`) only matters for hearing (beacon). For deaf, keep it off (or use it only to dim — §16 Q4).
- **Transcription pipeline (NEW):**
  - Hold a `SpeechRecognizer` (from `VoiceTranscribeViewModel.swift`) — instantiate per meeting, not a static.
  - When **this device becomes the active speaker** (`isActiveSpeaker == true`, granted via the existing speaker lock): **start transcribing** (`startTranscribing()`).
  - On each partial/final `transcript` update: broadcast `caption(userID: localUser.id, text: transcript, isFinal: …)`.
  - When this device **loses** the speaker lock (`isActiveSpeaker → false`): **stop transcribing**, send a final `caption(isFinal: true)`.
  - ⚠️ Only the active speaker transcribes (one voice, clean attribution). Everyone else displays.
- **Caption receiving (NEW):**
  - Handle incoming `.caption(userID, text, isFinal)`:
    - Resolve `userID → name` from `room.participants`.
    - Append/replace in a published `@State var captions: [CaptionEntry]` (ordered, capped length e.g. last 50). For a given speaker, replace their live partial in place; on `isFinal`, freeze it and start a new live line.
    - Track `var liveSpeakerID: UUID?` = speaker currently being transcribed (drives the highlighted chip + the live bubble).
- **Active speaker already known** from the existing speaker-lock state (`room.isSpeaker`). The Deaf Caption View binds the speaker highlight to `room.isSpeaker` and the captions to `captions`.
- Keep `leaveRoom()` (alone-ends-room + `hasLeft`), host handover, mute, etc. from FINAL unchanged.
- `cleanup()` must also `stopTranscribing()`.

### `AudioManager` + `SpeechRecognizer` coexistence ⚠️
Both want the mic. Two viable options (decide in impl, see §9 risk):
- **(A) Shared tap:** one `AVAudioEngine` input tap feeds both the RMS calculator (AudioManager) and the `SFSpeechAudioBufferRecognitionRequest` (append buffers). Single audio session. **Preferred.** Requires merging the tap or routing buffers.
- **(B) Sequential:** AudioManager does RMS always; only when active speaker, hand the engine to Speech. More complex; latency risk.
The current `SpeechRecognizer.prepareEngine()` creates its **own** `AVAudioEngine` and sets session `.playAndRecord/.measurement` — this **conflicts** with `AudioManager`'s engine. For V2 we likely refactor so there is **one** shared engine, OR run transcription only on the speaker's device and accept that it owns the audio path during speaking (RMS still derivable from the same tap). Flag as the #1 implementation risk.

### `HomeViewModel`
- Add role handling: `didTapCreate()`/`didTapJoin()` → **first open Role sheet** (if role not yet chosen) → on role chosen → Permission → host/scanner.
- New state: `showRoleSheet: Bool`, `pendingRoleAction`, and `selected(role:)`.
- `startHost()` / `joinWithCode()` pass `currentUser` (with role) into `MeetingViewModel` as today.

### `FlashlightManager` — UNCHANGED (hearing beacon only).

---

## 9. Caption / Transcription Mechanism (critical) + Risks

**Flow**
1. Speaker lock arbitration (FINAL) picks the active speaker (loudest in 150 ms window).
2. The **active speaker's device** starts `SFSpeechRecognizer` on its mic.
3. Each partial result → `networkManager.broadcastMessage(.caption(userID: me, text:, isFinal: false))`.
4. **Deaf device** receives `.caption`, resolves speaker name, renders in the feed.
5. On speaker release (silence / new speaker) → send `.caption(isFinal: true)`, stop transcribing.

**Risks (flag, don't hide):**
- ⚠️ **Audio-engine conflict** between `AudioManager` (RMS) and `SpeechRecognizer` (its own engine + session). Resolve by a shared input tap (§8). This is the make-or-break technical task.
- ⚠️ **`SFSpeechRecognizer` limits:** ~1 min per task; on-device vs. on-server; locale availability (Indonesian `id-ID` must be downloaded/enabled on the device, else it falls back). Must handle the 1-min task limit by restarting the task (reset + resume) while still speaking.
- ⚠️ **Attribution under crosstalk:** if two hearing people talk, the loudest wins the lock and is the only one captioned. Acceptable for V1-of-V2; note in UI ("menampilkan pembicara terdekat").
- ⚠️ **Privacy:** on-server recognition sends audio to Apple. Prefer `requiresOnDeviceRecognition = true` where the locale supports it; document the fallback. (Speech key in Info.plist, §13.)
- ⚠️ **Battery/heat:** continuous recognition on the speaker's device. Acceptable for a short discussion; monitor.

---

## 10. File / Folder Structure (V2 deltas)

```
Beaming/
├── Model/      User.swift (+Role enum), Room.swift, NetworkMessage.swift (+caption), AppState.swift
├── ViewModel/  HomeViewModel.swift (+role), MeetingViewModel.swift (+transcription/captions),
│               NetworkManager.swift, AudioManager.swift, FlashlightManager.swift,
│               VoiceTranscribeViewModel.swift (refactor to be reusable, not a one-off)
├── View/       HomeView.swift, RoleSheet.swift (NEW), PermissionSheet.swift (+speech row),
│               QRScannerView.swift, CalibrationView.swift, MeetingView.swift (hearing/beacon),
│               CaptionView.swift (NEW, deaf), FaceDownView.swift
└── Component/  Theme.swift (+speaker/caption tokens), QRCode.swift, CaptionComponents.swift (NEW)
```
**Do not delete** `VoiceTranscribeViewModel.swift` — adopt it. **Do not delete** `MeetingView`/`FaceDownView` — they are the hearing path.

---

## 11. Assets — UNCHANGED
Reuse `MascotHome/MascotCalibrate/MascotDone/MascotMeeting`. No new mascot required for V2 (the Role sheet reuses `MascotHome`; CaptionView reuses `MascotMeeting` for the empty state).

---

## 12. Info.plist (V2 — add Speech key)

Keep FINAL's four keys. **Add:**
```xml
NSSpeechRecognitionUsageDescription = "Beaming mengubah ucapan menjadi teks di perangkat agar bisa ditampilkan sebagai teks selama diskusi."
```
Note: SFSpeechRecognizer also needs the microphone (already requested). No separate entitlement for on-device; on-device is preferred via `requiresOnDeviceRecognition`.

---

## 13. Tunables (V2)
- Calibration 3.5 s (hearing only).
- Torch level 0.3 (current, hearing beacon).
- Caption feed max length ~50 entries.
- Partial-caption throttle: broadcast at most every ~0.25 s to avoid flooding TCP (the recognition handler fires frequently).
- Speaker chip highlight = green ring + scale 1.1 + yellow radial glow (reuse MeetingView glow constants).
- Light color scheme (unchanged).

---

## 14. Implementation Order (for a fresh session)

1. **Models:** add `Role` to `User`; add `.caption` to `NetworkMessage`; update `AppState` role default.
2. **Theme:** add speaker/caption tokens; create `CaptionComponents.swift` (`SpeakerChip`, `CaptionBubble`).
3. **Role sheet:** new `RoleSheet.swift`; wire `HomeViewModel` (role → permission → host/scanner).
4. **Permission sheet:** add the Speech-Recognition row.
5. **Caption pipeline:** refactor `VoiceTranscribeViewModel`'s `SpeechRecognizer` to a shared-engine model (or document the chosen approach); in `MeetingViewModel`, start/stop transcription on active-speaker transitions; broadcast `.caption`.
6. **CaptionView (deaf):** build the speaker strip + caption feed + empty state + QR pill + exit-door.
7. **Branch MeetingView:** route to `CaptionView` when `localUser.role == .deaf`, else keep `MeetingView` (beacon). Skip calibration for deaf.
8. **Receive captions:** handle `.caption` → `captions` array + `liveSpeakerID`.
9. **Info.plist:** add `NSSpeechRecognitionUsageDescription`.
10. Build in Xcode. **Test captions on 2+ devices** (speaker device must have the locale; transcribe→broadcast→display). Simulator won't do torch/real P2P.

---

## 15. Verification

- Compiles clean; no references to removed symbols.
- **Deaf device:** Create as Deaf → reaches **CaptionView** (no calibration). A hearing device joins and speaks → the deaf device shows the **speaker highlighted** and the **live caption** updating, freezing when they stop.
- **Hearing device:** Create/Join as Hearing → calibration → BeaconView; flashlight blinks on active speaker; face-down overlay works; while speaking, it broadcasts captions.
- Multi-speaker: loudest wins lock; only that device captions; feed attributes correctly.
- Leave/alone-ends-room/host-handover still work (FINAL behavior preserved).
- Participant count live-updates on leave (FINAL).
- Locale fallback handled gracefully (if `id-ID` unavailable, show a clear message rather than silent failure).

---

## 16. Open Questions (resolve with the user before/during build)

1. **Remember role across launches?** Persist `"userRole"` so a deaf user isn't re-asked every time? (Default: remember it; allow change via a small control.)
2. **Deaf calibration:** truly skip, or show a short "we're calibrating the *room*" / mic-check screen? (Default: skip.)
3. **Can the deaf user speak?** If yes, their device must beacon + transcribe too (they have a mic). If no, lock them to observer only. (Default: yes, they can speak — same pipeline as hearing, just *also* show the caption view. Means a deaf user toggles between viewing (face-up) and the room seeing their blink (face-down) — needs UX clarity.)
4. **Deaf user lays phone face-down:** dim-to-black like hearing, or keep captions visible? (Default: keep captions visible; don't trigger the black FaceDownView for the deaf role.)
5. **Caption language/locale:** force `id-ID`, or follow device locale? (Default: follow device, with `id-ID` preferred.)
6. **On-device vs. on-server speech:** require on-device (privacy, offline) even if it means worse accuracy / locale limits? (Default: prefer on-device, allow server fallback with a one-time notice.)

---

*End of V2 spec. Anything not mentioned here inherits from `BEAMING_PRD_FINAL.md`.*
