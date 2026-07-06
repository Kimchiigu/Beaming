# BEAMING — Final PRD & Rebuild Spec

> This document is the single source of truth for the **final** Beaming iOS app. A fresh Claude session can rebuild the entire app from this spec (the original MVP business logic already exists in the repo and should be **reused, not rewritten** — only the models, flow, and UI change).
>
> **Figma source:** file `HXmV0k07oA0saJ6liKmonz` ("Challenge 4 - Cisauk"), frame **Hi-Fi-Final-Frame** (`287:1670`). Use the **second iteration node set (`339:…`)** as final. Mascot SVGs live in the repo at `mascot/`.

---

## 1. Product Overview

**Beaming** is an offline, local-P2P iOS app for small group discussions (up to 8). Every participant places their phone **face-down** on the table; when someone speaks, **their phone's flashlight blinks** so a deaf participant can visually see who is talking. No cloud, no internet — only Wi-Fi/AWDL (`Network.framework`, Bonjour/mDNS, custom TCP).

**Everyone is a speaker.** There is no deaf/hearing role selection — the deaf participant simply watches the blinking phones and may not use the app at all.

---

## 2. Tech Stack & Architecture

- **Platform:** iOS (iPhone), SwiftUI, iOS 17+.
- **Architecture:** MVVM (`@Observable`). Views are thin; all logic in ViewModels + Manager services.
- **Networking:** `Network.framework` — Bonjour discovery (`NWBrowser`/`NWListener`) + custom TCP (`NWConnection`) with 4-byte length framing. `includePeerToPeer = true` (AWDL). Service type `_beaming._tcp`.
- **Persistence:** `UserDefaults` only (a stable local UUID + generated name). No Core Data/SwiftData.
- **No external dependencies / SPM packages.**
- **Theme:** forced **light** color scheme (the hi-fi is a light design).

---

## 3. Final User Flow

```
Home ──Mulai diskusi (Create)──▶ Permission sheet ▶ (host advertises) ▶ Calibration (3 states) ▶ Mode Diskusi
  └──Scan QR (Join)─────────────▶ Permission sheet ▶ QR scanner ▶ connect ▶ Calibration (3 states) ▶ Mode Diskusi
```

- **Home:** branded greeting + two cards. No name, no role, no room list.
- **Permission sheet** (Bahasa Indonesia): Microphone + Local Network → "Izinkan Akses".
- **Create:** host starts advertising (Bonjour) → proceeds to calibration → Mode Diskusi.
- **Join:** scan host's QR → `NWEndpoint.service(...)` → `connectToHost` → calibration → Mode Diskusi.
- **Calibration:** Intro → active (3.5 s) → Done.
- **Mode Diskusi:** participant count + mascot + "place phone face-down". Native nav bar with a more-button (`Menu`) containing **Kode QR** + **Keluar** (identical for host & guest). Phone face-down → `FaceDownView`.

---

## 4. Locked Product Decisions

1. **`Role` is removed.** Delete `Role.swift`; remove `role` from `User`. Everyone is a speaker (mic + flashlight + face-down).
2. **No onboarding.** Delete `OnboardingView`. `AppState` auto-creates a local user (stable UUID + generated Indonesian codename) on first launch.
3. **Join is QR-based.** Remove the Bonjour room-list UI. The QR encodes the host's Bonjour service name; the joiner builds an `NWEndpoint.service` and connects directly.
4. **Calibration = 3 states** (Intro → active → Done) wrapping the existing `AudioManager` calibration (now **3.5 s**).
5. **Face-down view = existing `FaceDownView`** (not redesigned).
6. **Discussion screen is identical for host & guest.** The more-menu has only **Kode QR** + **Keluar** (no mute, no end). If the user leaving is the only participant, leaving **ends the room**.
7. **Default iOS buttons:** system back button; sheets close with `xmark.circle.fill`.
8. **Copy is Bahasa Indonesia.**
9. **Graphics:** export the 4 mascot SVGs from `mascot/` into `Assets.xcassets` (Xcode renders SVG natively; set `preserves-vector-representation`).

---

## 5. Design System (`Component/Theme.swift`)

### Color palette
| Token | Hex | Use |
|---|---|---|
| `green` | `#6BB99C` | primary brand, Join accent |
| `blue` | `#0093EC` | Create accent |
| `yellow` | `#FFCC00` | gradient end, glow |
| `pink` | `#FF7889` | secondary |
| `micChip` | `#FFD9DD` | permission mic chip bg |
| `netChip` | `#C3E7FF` | permission net chip bg |
| `greenTint` | `#94F2CF` | join card icon chip bg |

```swift
extension Color {
    init(hex: UInt, alpha: Double = 1) { /* sRGB from hex */ }
}
enum BeamingPalette {
    static let green = Color(hex: 0x6BB99C)
    static let blue  = Color(hex: 0x0093EC)
    static let yellow = Color(hex: 0xFFCC00)
    static let pink  = Color(hex: 0xFF7889)
    static let micChip = Color(hex: 0xFFD9DD)
    static let netChip = Color(hex: 0xC3E7FF)
    static let greenTint = Color(hex: 0x94F2CF)
    static var wordmark: LinearGradient { .init(colors: [blue, green, yellow],
        startPoint: UnitPoint(x: 0.10, y: 0.15), endPoint: UnitPoint(x: 0.90, y: 0.85)) }
    static var blob: LinearGradient { .init(colors: [green.opacity(0.5), blue.opacity(0.35)],
        startPoint: .topLeading, endPoint: .bottomTrailing) }
    static var waveform: LinearGradient { .init(colors: [Color(hex: 0xD1EFCB), netChip],
        startPoint: .top, endPoint: .bottom) }
}
```

### Typography
SF Pro (system). Large title 34 bold `tracking(0.4)`. Body 17 `tracking(-0.43)`. Headings 22 bold `tracking(-0.26)`. Caption/desc 12–15, `.secondary`.

### Reusable components (define in `Theme.swift`)
- `beamingCard(cornerRadius: 20)` view modifier — white bg, continuous corner, `shadow(color: .black.opacity(0.1), radius: 10, y: 1)`.
- `PrimaryButtonStyle` (`ButtonStyle`) — green (`BeamingPalette.green`) capsule, white 17 medium text, height 52, `shadow(.black.opacity(0.12), radius: 8, y: 4)`, press scale 0.98. Accepts `tint:`.
- `BlobShape: Shape` — `addRoundedRect` with cornerSize `42%×42%`. Used for soft background blobs (`fill(BeamingPalette.blob)`, `frame 360×360`, `blur(50)`, opacity ~0.3–0.45, corner-aligned).

---

## 6. Screen-by-Screen Spec

### 6.1 Home (`View/HomeView.swift`)
- Root of `NavigationStack`. `.toolbar(.hidden, for: .navigationBar)`. `.preferredColorScheme(.light)` is set on the `NavigationStack` in `ContentView`.
- **Background:** white + two `BlobShape`s (top-trailing, bottom-leading) + **`MascotHome` big** (`height: 430`, aligned `.topTrailing`, `offset(x: 28, y: -18)`, layered BEHIND the content).
- **Title block (leading, pad top 64, horizontal 26):**
  - `Text("Selamat Datang di")` — 34 bold, black.
  - `Text("Beaming!")` — 34 bold, `.foregroundStyle(BeamingPalette.wordmark)`.
  - `Text("Siap untuk diskusi selanjutnya?")` — 17, black, `padding(.top, 10)`.
- **Two cards** (`VStack(spacing: 16)`, horizontal 24, bottom 48), each a `HomeActionCard` (white `beamingCard`, height 156, `VStack(spacing: 14)` = icon chip 56×56 rounded-18 + label 17 semibold):
  - **Mulai diskusi** — `accent: blue`, `chipBg: blue.opacity(0.1)`, symbol `"plus"` → `viewModel.didTapCreate()`.
  - **Scan QR untuk bergabung** — `accent: green`, `chipBg: greenTint.opacity(0.35)`, symbol `"qrcode.viewfinder"` → `viewModel.didTapJoin()`.
- Sheets/destinations: `.sheet(showPermission) { PermissionSheet }`, `.sheet(showQRScanner) { QRScannerView }`, `.navigationDestination(navigateToMeeting) { MeetingView }`, `.alert`.

### 6.2 Permission sheet (`View/PermissionSheet.swift`) — Indonesian
`.presentationDetents([.fraction(0.72), .large])`. VStack `.foregroundStyle(.black).background(Color.white)`.
- Grabber capsule 36×5.
- Header `ZStack`: `Text("Izin")` (17 semibold) + leading `Button(onClose) { Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary) }`.
- `Text("Kami memerlukan beberapa izin untuk memulai pengalaman interaktif.")` (16 semibold, leading).
- Row **Mikrofon** — chip `micChip`, icon `"microphone"`, desc: *"Mendeteksi ritme dan volume suara untuk menghasilkan pulsa "beaming" visual. Tidak ada audio yang pernah direkam atau disimpan."*
- Row **Jaringan Lokal** — chip `netChip`, icon `"flashlight.off.fill"`, desc: *"Menggunakan senter atau kecerahan layar perangkat Anda untuk memberikan umpan balik visual selama diskusi aktif."*
- Each row ends with `checkmark.circle.fill` (green).
- `Button("Izinkan Akses") { onAllow() }.buttonStyle(PrimaryButtonStyle())`.

### 6.3 QR scanner (`View/QRScannerView.swift`)
- Camera (`AVCaptureSession`, metadata `.qr`), black bg. Camera permission requested on appear (`AVCaptureDevice.requestAccess(for: .video)`; show message if denied).
- Overlay: header `Text("Scan QR")` + leading `xmark.circle.fill` (white) close; a 247×247 stroked viewfinder; bottom `Text("Arahkan kamera ke kode QR host")`.
- On detect: `onScan(String)`.

### 6.4 Calibration (`View/CalibrationView.swift`) — 3 states
Full-screen overlay (ZStack, white + blobs), `.toolbar(.hidden)`, `.foregroundStyle(.black)`.
- Custom toolbar: leading `chevron.backward` button → `viewModel.leaveRoom()`; centered `Text("Kalibrasi")`.
- Heading: `Image(systemName: "lines.measurement.horizontal")` + `Text("Kalibrasi suara")` (22 bold).
- Mascot: `Image(viewModel.isCalibrationDone ? "MascotDone" : "MascotCalibrate")` (`height: 150`).
- **Intro:** `beamingCard` with `Text("Baca kalimat di bawah ini dengan suara normal kamu")`; phrase card (gray `#F6F6F6`, green 4pt left rule) `"Halo semua, saya siap untuk mengikuti diskusi ini"` (20 bold, green); static `WaveformView`; then `Button("Mulai Kalibrasi") { viewModel.startCalibration() }`.
- **Loading** (`audioManager.isCalibrating`): `Text("Mendengarkan… ucapkan kalimatnya")`, `ProgressView(value: calibrationProgress).tint(green)`, live `WaveformView(level: audioLevel)`, phrase reminder.
- **Done** (`isCalibrationDone`): `checkmark.circle.fill` (green, 60), `Text("Kalibrasi Selesai!")`, `Text("Mikrofon kamu sudah siap.")`. (VM auto-dismisses after ~0.8 s.)
- `WaveformView`: 7 bars (heights `[30,16,48,16,30,16,30]`), `BeamingPalette.waveform` fill; live mode scales by level.

### 6.5 Mode Diskusi / Meeting (`View/MeetingView.swift`)
- **Native nav bar:** `.navigationTitle("Mode Diskusi")`, `.navigationBarTitleDisplayMode(.inline)`, system back button (do NOT hide). Conditionally hide the bar while calibrating/face-down: `.toolbar((isFaceDown || showCalibration) ? .hidden : .visible, for: .navigationBar)`.
- Trailing `ToolbarItem` = **`Menu`** with `Image(systemName: "ellipsis.circle")` label, items: `Button("Kode QR", systemImage: "qrcode") { showHostQR = true }` and `Button("Keluar", role: .destructive, systemImage: "rectangle.portrait.and.arrow.right") { viewModel.leaveRoom() }`.
- `.onDisappear { viewModel.leaveRoom() }` (back button leaves correctly).
- `.sheet(showHostQR) { QRShareSheet(code: viewModel.roomCode) { showHostQR = false } }`.
- **Content (identical host/guest):** white + blobs; participant pill `person.2.fill` + `"\(room.participantCount) orang di dalam diskusi"` (grey `#75777A`, white capsule, shadow); center = `MascotMeeting` (`height: 240`) on a soft yellow radial glow; bottom instruction `Text("Letakkan HP di atas meja dengan layar menghadap ke bawah!")` (17 semibold) + `Text("Lampu akan menyala untuk menunjukkan siapa yang sedang berbicara.")` (15 secondary).
- Overlays: `if showCalibration { CalibrationView }`; `if isFaceDown && !showCalibration { FaceDownView }` (existing).
- `.onChange(of: viewModel.shouldDismiss) { dismiss() }`; `.alert` for `showAlert`.

### 6.6 QR share sheet (`Component/QRCode.swift` → `QRShareSheet`)
`.presentationDetents([.large])`. Grabber; header `Text("Kode QR")` + leading `xmark.circle.fill` close; `Text("Tunjukkan kode QR ke temanmu untuk ikuti diskusi")` (15 secondary); `QRCodeView(string: code, side: 224)`.

### 6.7 FaceDownView
Keep the **existing** one (full-screen locked "phone is face-down" view).

---

## 7. Data Models (`Model/`)

### `User.swift` (FINAL — no role)
```swift
struct User: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var joinedTime: Date?
    init(name: String, id: UUID = UUID()) { self.id = id; self.name = name }
    static func == (lhs: User, rhs: User) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
```

### `Room.swift` (unchanged structurally)
`id, name, hostID, hostName, isSpeaker: UUID?, participants: [User]`; `participantCount`; `isFull { participantCount >= 8 }`; `init(id:host:participants:)` sets `hostName = host.name`, `name = host.name + "'s Room"`, inserts host with `joinedTime = Date()`.

### `NetworkMessage.swift` (unchanged)
Cases: `joinRequest(User)`, `joinResponse(success, room, reason)`, `participantUpdate(participants, hostID, roomName)`, `roomInfo(Room)`, `speakerClaim(userID, rmsLevel)`, `speakerRelease(userID)`, `speakerStatus(speakerID?)`, `hostHandover(newHostID)`, `endRoom`, `leaveRoom(userID)`. Codable with 4-byte length framing in `NetworkManager`.

### `AppState.swift` (FINAL — no onboarding)
```swift
@Observable class AppState {
    var currentUser: User
    init() { /* load or create from UserDefaults ("userID","userName"),
                generated Indonesian name e.g. "Ceria Rubah" */ }
}
```
`currentUser` is **non-optional**. No `hasOnboarded`/`saveUser`/`loadUser`/`resetOnboarding`.

---

## 8. Business Logic (REUSE — already in repo)

These exist in the original codebase and are **finished** — keep them, apply only the noted tweaks:

- **`NetworkManager`** — `startAdvertising(roomID:hostName:)` builds service name `"\(hostName)::::\(roomID)"`; `connectToHost(endpoint:localUser:completion:)`; `sendToHost`; `broadcastMessage`; `registerPeer`; `receiveMessages` recursive loop; disconnection handling (`onPeerDisconnected`). **No change.**
- **`AudioManager`** — `AVAudioEngine` RMS detection, `isSpeaking`, `startCalibration`/`onCalibrationComplete`, `audioLevel`, `calibrationProgress`, `sensitivity`. **Change:** `calibrationDuration = 3.5` (was 5.0).
- **`FlashlightManager`** — torch toggle + 3-blink sequence. **Change:** `setTorchModeOn(level: 0.5)` (was `maxAvailableTorchLevel`).
- **`MeetingViewModel`** — speaker-lock arbitration (150 ms competing-claim window, loudest wins), host handover (oldest guest), 8-person capacity, silence release, `CMMotionManager` face-down (z > 0.7), cleanup. Changes:
  - Init: everyone calibrates + face-down detection (remove the `role == .hearing` gate): `showCalibration = true; startFaceDownDetection()`.
  - Add `var roomCode: String { "\(room.hostName)::::\(room.id.uuidString)" }` (uses **host** name so a guest-shared QR is still valid).
  - `leaveRoom()`: one-shot guard `hasLeft`; **if `room.participantCount <= 1` → end** (broadcast `.endRoom` if host, cleanup, dismiss). Else host → handover; guest → `sendToHost(.leaveRoom(userID))`. Always `cleanup()` (set `hasLeft = true`) + `shouldDismiss = true`.
  - `cleanup()` sets `hasLeft = true`.
- **`HomeViewModel`** — rewrite: no discovery/role. `currentUser`, `didTapCreate()`/`didTapJoin()` → `showPermission`; `permissionAllowed()` → mic request then start host or open scanner; `startHost()` builds `MeetingViewModel(asHost:true)`; `joinWithCode(_:)` builds `NWEndpoint.service(name: code, type: "_beaming._tcp", domain: "local.", interface: nil)` → `connectToHost` → on success `MeetingViewModel(asHost:false)`; `navigateToMeeting`, `resetAfterMeeting()`.

---

## 9. QR-Join Mechanism (critical)

- **Host** advertises via `NWListener.Service(name: "\ hostName::::roomID", type: "_beaming._tcp")` (default local domain).
- **QR payload** = that exact service-name string = `MeetingViewModel.roomCode`.
- **Joiner** scans → `let endpoint = NWEndpoint.service(name: code, type: "_beaming._tcp", domain: "local.", interface: nil)` → `networkManager.connectToHost(endpoint: endpoint, localUser:)`.
  - ⚠️ `domain` is **non-optional `String`** on current SDK — pass `"local."` (not `nil`).
- Works over AWDL because both sides use `includePeerToPeer = true`.
- QR image: `CoreImage.CIFilter.qrCodeGenerator()` (`correctionLevel: "H"`, scale ×10), rendered by `QRCodeView` (`interpolation(.none)`, white rounded card, shadow).

---

## 10. File / Folder Structure (FINAL)

```
Beaming/
├── BeamingApp.swift                 (@main → ContentView)
├── ContentView.swift                (NavigationStack { HomeView }.preferredColorScheme(.light))
├── Info.plist                       (see §12)
├── Assets.xcassets/
│   ├── MascotHome.imageset/         (mascot-home.svg)
│   ├── MascotCalibrate.imageset/    (mascot-start-calibration.svg)
│   ├── MascotDone.imageset/         (mascot-finish-calibration.svg)
│   ├── MascotMeeting.imageset/      (mascot-meeting.svg)
│   └── AccentColor.colorset, AppIcon.appiconset
├── Model/      AppState.swift, User.swift, Room.swift, NetworkMessage.swift   (DELETE Role.swift)
├── ViewModel/  HomeViewModel.swift, MeetingViewModel.swift, NetworkManager.swift,
│               AudioManager.swift, FlashlightManager.swift
├── View/       HomeView.swift, PermissionSheet.swift, QRScannerView.swift,
│               CalibrationView.swift, MeetingView.swift, FaceDownView.swift
└── Component/  Theme.swift, QRCode.swift
```
**Delete:** `View/OnboardingView.swift`, `Component/RoomCardView.swift`, `Model/Role.swift`.

---

## 11. Assets (mascots)

Add each SVG from `mascot/` as an imageset in `Assets.xcassets` (Xcode renders SVG natively). Imageset `Contents.json`:
```json
{ "images": [{ "filename": "<file>.svg", "idiom": "universal" }],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "preserves-vector-representation": true } }
```
Mapping (asset name ← source file): `MascotHome` ← `mascot-home.svg` · `MascotCalibrate` ← `mascot-start calibration.svg` (rename without the space) · `MascotDone` ← `mascot-finish-calibration.svg` · `MascotMeeting` ← `mascot-meeting.svg`.

---

## 12. Info.plist (FINAL — all four keys)

```xml
NSBonjourServices        = [ "_beaming._tcp" ]
NSCameraUsageDescription = "Beaming menggunakan kamera untuk memindai kode QR agar kamu bisa bergabung ke diskusi."
NSMicrophoneUsageDescription = "Beaming menggunakan mikrofon untuk mendeteksi suaramu dan mengaktifkan lampu sebagai penanda pembicara."
NSLocalNetworkUsageDescription = "Beaming menghubungkan perangkat di sekitar melalui jaringan lokal untuk menjalankan diskusi."
```
(The repo currently has Bonjour + Camera + Mic but is **missing `NSLocalNetworkUsageDescription`** — add it.)

---

## 13. Tunables (final)
- Calibration duration **3.5 s** (`AudioManager.calibrationDuration`).
- Torch level **0.5** (`FlashlightManager.setTorchModeOn`).
- App color scheme **light** (`ContentView.preferredColorScheme(.light)`).
- Competing-claim window 150 ms; silence release ~0.4 s; sync broadcast every 3 s (unchanged from original).

---

## 14. Implementation Order (for a fresh session)

1. Models: delete `Role.swift`; simplify `User` (drop `role`); rewrite `AppState` (auto-user, no onboarding); confirm `Room`/`NetworkMessage` unchanged.
2. `ContentView` → `NavigationStack { HomeView().environment(appState) }.preferredColorScheme(.light)`.
3. `Theme.swift` (palette, `Color(hex:)`, `BlobShape`, `PrimaryButtonStyle`, `beamingCard`).
4. `QRCode.swift` (`QRGenerator`, `QRCodeView`, `QRShareSheet`).
5. `HomeViewModel` rewrite (no discovery/role; `didTapCreate`/`didTapJoin`/`permissionAllowed`/`startHost`/`joinWithCode`).
6. Views: `HomeView`, `PermissionSheet`, `QRScannerView`, `CalibrationView` (3-state), `MeetingView` (native nav + Menu + onDisappear).
7. `MeetingViewModel` tweaks (`roomCode`, unconditional calibrate/face-down, `leaveRoom` alone-ends-room + `hasLeft`).
8. `AudioManager` (3.5 s) + `FlashlightManager` (0.5).
9. Delete `OnboardingView`, `RoomCardView`, `Role`. Add 4 mascot imagesets. Fix `Info.plist`.
10. Build in Xcode (clean build if SVGs don't appear). Test on 2 devices (P2P/QR/torch/camera don't work in simulator).

---

## 15. Verification

- Compiles clean (no `Role`/`OnboardingView` references).
- Two-device flow: Create → permission → QR; second device Join → scan → connect; both calibrate; both reach Mode Diskusi.
- Speak into a device → torch blinks (dimmer now); silence → off; competing speakers → loudest wins.
- More menu → Kode QR opens share sheet (host or guest, same valid QR); Keluar leaves; back button leaves; leaving as the only person ends the room.
- Participant count updates live on remaining devices when someone leaves (via `.leaveRoom` message and TCP disconnect detection).

---

## 16. Latest Flow Tweaks (post-PRD)

1. **Permission sheet auto-opens on first launch.** `HomeViewModel.onAppear()` (called from `HomeView.onAppear`) checks `UserDefaults.standard.bool(forKey: "hasShownPermission")`; if false, it sets `showPermission = true` with `pendingAction = nil` (purely informational + mic grant — no navigation after). `permissionAllowed()` sets the flag (so it never auto-opens again), requests mic, then executes any pending create/join. Closing via `x` (`cancelFlow`) does **not** set the flag, so it re-prompts next launch until allowed. `didTapCreate`/`didTapJoin` skip the sheet entirely once the flag is set and go straight to host/scanner.

2. **Host's join-QR auto-opens at half height after creating.** In `MeetingView`, `.onChange(of: viewModel.showCalibration)` fires when calibration ends (`false`); if `isHost && !didAutoShowQR`, it sets `showHostQR = true` once. `QRShareSheet` uses `.presentationDetents([.medium, .large])` so it opens at **half** height (medium), draggable to full. The QR is also re-openable from the more-menu. Guest never auto-opens it.

*End of spec.*
