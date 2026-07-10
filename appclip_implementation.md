# App Clip Integration for Beaming — Feasibility & Implementation Guide

## 1. Feasibility Assessment

### ✅ Verdict: **Fully Possible**

App Clips are specifically designed for exactly this use case — a lightweight, install-free experience invoked via QR code that lets a user immediately perform a task. Here's why Beaming is a perfect fit:

| Requirement | App Clip Support | Beaming Fit |
|---|---|---|
| QR code invocation | ✅ App Clip Codes / NFC / QR | ✅ Already QR-based join flow |
| Lightweight (< 15 MB) | ✅ Required by Apple | ✅ Beaming is tiny (no cloud, no heavy assets) |
| Room-specific deep link | ✅ Via URL with parameters | ✅ Room code already exists (`hostName::::roomID`) |
| Same networking stack | ✅ App Clips can use `Network.framework` | ✅ Bonjour/mDNS P2P works in App Clips |
| No login / account needed | ✅ App Clips are sessionless | ✅ Beaming auto-generates identity |
| iOS 17+ | ✅ App Clips available since iOS 14 | ✅ Beaming already targets iOS 17+ |
| Existing users bypass install | ✅ If full app is installed, URL opens the app | ✅ Universal Link routing handles this |

### Key Architectural Insight

The beauty is that **Beaming's current join flow is already almost what an App Clip needs**:

1. Scan QR → extract room code → `NWEndpoint.service(name: code, ...)` → connect → calibrate → meeting.

The App Clip just needs to **receive the room code via a URL** instead of via the in-app QR scanner. That's the only flow difference.

---

## 2. How App Clips Work (Technical Background)

```
┌────────────────────────────────────────────────────────────────────┐
│                    User scans QR with iPhone Camera               │
│                               │                                   │
│            ┌──────────────────┼──────────────────┐                │
│            ▼                                     ▼                │
│   Full App installed?                    No full app              │
│            │                                     │                │
│            ▼                                     ▼                │
│   Universal Link opens                  App Clip card appears     │
│   the full app directly                 (system banner)           │
│   → extracts room code                          │                 │
│   → calls joinWithCode()                        ▼                 │
│                                         User taps "Open"          │
│                                                  │                │
│                                                  ▼                │
│                                         App Clip launches         │
│                                         → extracts room code      │
│                                         → straight to join flow   │
└────────────────────────────────────────────────────────────────────┘
```

### App Clip = Separate Xcode Target
- An App Clip is a **separate target** in the same Xcode project
- It shares source files with the main app (you pick which `.swift` files belong to both targets)
- It has its own `@main` entry point (e.g. `BeamingClipApp.swift`)
- It has its own `Info.plist` and entitlements
- It is **limited to 15 MB** uncompressed (Beaming is well under this)
- It **cannot** use: Push Notifications (except ephemeral), Background Tasks, HealthKit, etc. — none of which Beaming uses

### Universal Links = The Bridge
- Both the full app and the App Clip register the **same Associated Domain** (e.g. `applinks:beaming.app` or your chosen domain)
- The QR code encodes a **URL** (not a raw Bonjour service name like today)
- iOS sees the URL → checks if the full app handles it → if yes, opens the full app; if no, shows the App Clip card
- The URL contains the room code as a query parameter

---

## 3. What Changes in the QR Code

### Current QR Payload
```
hostName::::roomID
```
A raw string. Only scannable by Beaming's in-app QR scanner.

### New QR Payload (App Clip URL)
```
https://beaming.app/join?room=hostName::::roomID
```
A **Universal Link**. Scannable by:
- iPhone Camera app → triggers App Clip (or opens full app)
- Beaming's in-app QR scanner → extracts the room code and joins as before

> [!IMPORTANT]
> The domain `beaming.app` (or whichever domain you own/choose) must be registered with Apple and serve an `apple-app-site-association` (AASA) file. This is the only server-side requirement. **No backend is needed** — just a static JSON file hosted on a domain you control. You can use GitHub Pages, Netlify, or any static host.

### Backward Compatibility
The in-app QR scanner (`QRScannerView`) currently passes the raw string to `joinWithCode(_:)`. We simply update the scanner to:
1. Check if the scanned string is a URL containing `room=`
2. If yes → extract the room code from the query parameter
3. If no → treat it as a raw room code (backward compat, though this path is only needed temporarily)

---

## 4. Architecture: Shared Code Strategy

The App Clip reuses **almost all** of the existing codebase. Here's what's shared vs. unique:

### Shared (both targets)
| File | Why shared |
|---|---|
| [User.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/User.swift) | Identity model |
| [Room.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/Room.swift) | Room model |
| [NetworkMessage.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/NetworkMessage.swift) | Protocol messages |
| [AppState.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Model/AppState.swift) | Auto-generated identity |
| [NetworkManager.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/NetworkManager.swift) | P2P networking |
| [AudioManager.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/AudioManager.swift) | Mic + calibration |
| [FlashlightManager.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/FlashlightManager.swift) | Torch control |
| [MeetingViewModel.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/MeetingViewModel.swift) | Meeting logic |
| [VoiceTranscribeViewModel.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/VoiceTranscribeViewModel.swift) | Live captions |
| [Theme.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Component/Theme.swift) | Design system |
| [QRCode.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Component/QRCode.swift) | QR generation (updated) |
| [CalibrationView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/CalibrationView.swift) | Calibration UI |
| [MeetingView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/MeetingView.swift) | Discussion UI |
| [FaceDownView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/FaceDownView.swift) | Face-down overlay |
| [PermissionSheet.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/PermissionSheet.swift) | Permission prompt |
| Assets.xcassets | Mascot images, colors |

### Full App Only (NOT in App Clip target)
| File | Why excluded |
|---|---|
| [BeamingApp.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/BeamingApp.swift) | Full app `@main` entry point |
| [ContentView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ContentView.swift) | Full app root (NavigationStack + HomeView) |
| [HomeView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/HomeView.swift) | Full app home screen (Create + Join cards) |
| [HomeViewModel.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/HomeViewModel.swift) | Full app home logic |
| [QRScannerView.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/View/QRScannerView.swift) | In-app scanner (full app only) |

### App Clip Only (NEW files)
| File | Purpose |
|---|---|
| `BeamingClip/BeamingClipApp.swift` | App Clip `@main` — receives URL, extracts room code, goes straight to join |
| `BeamingClip/AppClipJoinView.swift` | Lightweight landing → permission → connect → MeetingView |
| `BeamingClip/AppClipJoinViewModel.swift` | Join logic (extracts room code from URL, connects to host) |
| `BeamingClip/Info.plist` | App Clip plist (permissions, associated domains) |
| `BeamingClip/BeamingClip.entitlements` | Associated Domains entitlement |

---

## 5. Detailed Implementation Plan

### Phase 1: Domain & AASA Setup (Server-Side — One-Time)

You need a domain (e.g. `beaming.app`) to host the Apple App Site Association file. This is required for Universal Links and App Clips.

#### 5.1.1 Choose a domain
Pick any domain you control. Example: `beaming.app`, `beaming-app.com`, or even a free GitHub Pages domain.

#### 5.1.2 Host the AASA file
Create the file at `https://<your-domain>/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": [
          "<TEAM_ID>.com.yourcompany.Beaming",
          "<TEAM_ID>.com.yourcompany.Beaming.Clip"
        ],
        "components": [
          { "/": "/join", "?": { "room": "?*" } }
        ]
      }
    ]
  },
  "appclips": {
    "apps": [
      "<TEAM_ID>.com.yourcompany.Beaming.Clip"
    ]
  }
}
```

> [!NOTE]
> `<TEAM_ID>` is your Apple Developer Team ID. The bundle IDs must match what you set in Xcode. The App Clip bundle ID **must** be a child of the main app's bundle ID (e.g. `com.yourcompany.Beaming.Clip`).

---

### Phase 2: Xcode Project Setup

#### 5.2.1 Add the App Clip Target
In Xcode:
1. **File → New → Target → App Clip**
2. Product Name: `BeamingClip`
3. Bundle Identifier: `com.yourcompany.Beaming.Clip` (must be child of main app's bundle ID)
4. Language: Swift, Interface: SwiftUI
5. Embed in: `Beaming` (the main app)

This creates:
- A new `BeamingClip/` folder with its own `@main` entry
- A new target in the project
- An "Embed App Clip" build phase on the main app target

#### 5.2.2 Add Associated Domains to BOTH targets
For **both** the main app target and the App Clip target, add the Associated Domains capability:
- Go to target → Signing & Capabilities → + Capability → Associated Domains
- Add: `applinks:<your-domain>` (e.g. `applinks:beaming.app`)

#### 5.2.3 Share source files
In Xcode, select each shared file (listed in Section 4) and in the **File Inspector** (right panel), check the **Target Membership** for both `Beaming` and `BeamingClip`.

#### 5.2.4 App Clip Info.plist
The App Clip needs its own `Info.plist` with:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSBonjourServices</key>
    <array>
        <string>_beaming._tcp</string>
    </array>
    <key>NSMicrophoneUsageDescription</key>
    <string>Beaming menggunakan mikrofon untuk mendeteksi suaramu dan mengaktifkan lampu sebagai penanda pembicara.</string>
    <key>NSLocalNetworkUsageDescription</key>
    <string>Beaming menghubungkan perangkat di sekitar melalui jaringan lokal untuk menjalankan diskusi.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Beaming mengubah ucapan menjadi teks di perangkat agar bisa ditampilkan sebagai transkripsi selama diskusi.</string>
    <key>NSAppClip</key>
    <dict>
        <key>NSAppClipRequestEphemeralUserNotification</key>
        <false/>
        <key>NSAppClipRequestLocationConfirmation</key>
        <false/>
    </dict>
</dict>
</plist>
```

> [!NOTE]
> The App Clip does **not** need `NSCameraUsageDescription` — it doesn't scan QR codes (the iPhone Camera app does that). It only needs Mic, Local Network, Speech Recognition, and Bonjour.

---

### Phase 3: Code Changes — Minimal Modifications to Existing Files

> [!IMPORTANT]
> Following your instruction to minimize changes to existing files. Only **2 existing files** need small edits. Everything else is **new files**.

#### 5.3.1 [MODIFY] [QRCode.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/Component/QRCode.swift) — QR now encodes a URL

The QR payload changes from a raw Bonjour service name to a Universal Link URL. This is the most critical change.

**Change in `QRShareSheet`** (line 81):
```diff
- QRCodeView(string: code, side: 200)
+ QRCodeView(string: AppClipURLHelper.buildJoinURL(roomCode: code), side: 200)
```

**Change in subtitle text** (line 75):
```diff
- Text("Tunjukkan kode QR ke temanmu untuk ikuti diskusi")
+ Text("Tunjukkan kode QR ke temanmu untuk ikuti diskusi.\nBisa scan dari kamera atau app Beaming.")
```

That's it for this file. The `QRCodeView` and `QRGenerator` remain unchanged.

#### 5.3.2 [MODIFY] [HomeViewModel.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/HomeViewModel.swift) — Parse URL from scanned QR

The in-app scanner now reads a URL instead of a raw room code. We need to extract the room code from the URL before calling the existing `joinWithCode(_:)`.

**Change in `joinWithCode(_:)`** (line 92-93):
```diff
  func joinWithCode(_ code: String) {
      showQRScanner = false
+     // Support both App Clip URLs and legacy raw room codes
+     let roomCode = AppClipURLHelper.extractRoomCode(from: code) ?? code
      let nm = NetworkManager()
-     let endpoint = NWEndpoint.service(name: code, type: "_beaming._tcp", domain: "local.", interface: nil)
+     let endpoint = NWEndpoint.service(name: roomCode, type: "_beaming._tcp", domain: "local.", interface: nil)
```

That's it. Two existing files, minimal changes.

---

### Phase 4: New Files

#### 5.4.1 [NEW] `Beaming/Helpers/AppClipURLHelper.swift` — Shared URL builder/parser

This file is shared by **both** targets. It centralizes the URL ↔ room code conversion.

```swift
//
//  AppClipURLHelper.swift
//  Beaming
//
//  Builds and parses App Clip invocation URLs.
//  Shared by the full app and the App Clip target.
//

import Foundation

enum AppClipURLHelper {
    /// The domain registered in your AASA file.
    /// CHANGE THIS to your actual domain.
    static let domain = "beaming.app"
    
    /// Build a Universal Link URL for a given room code.
    /// Example output: "https://beaming.app/join?room=CeriaRubah::::ABCD-1234"
    static func buildJoinURL(roomCode: String) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = domain
        components.path = "/join"
        components.queryItems = [URLQueryItem(name: "room", value: roomCode)]
        return components.url?.absoluteString ?? "https://\(domain)/join?room=\(roomCode)"
    }
    
    /// Extract the room code from an App Clip URL or a raw room code string.
    /// Returns nil if the string is not a recognized URL (caller falls back to raw).
    static func extractRoomCode(from string: String) -> String? {
        // Try parsing as URL first
        guard let url = URL(string: string),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let roomCode = components.queryItems?.first(where: { $0.name == "room" })?.value else {
            return nil
        }
        return roomCode
    }
}
```

#### 5.4.2 [NEW] `BeamingClip/BeamingClipApp.swift` — App Clip entry point

```swift
//
//  BeamingClipApp.swift
//  BeamingClip
//
//  App Clip entry point. Receives the invocation URL, extracts the
//  room code, and navigates directly to the join flow.
//

import SwiftUI

@main
struct BeamingClipApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            AppClipJoinView()
                .environment(appState)
                .preferredColorScheme(.light)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    handleUserActivity(activity)
                }
        }
    }
    
    private func handleUserActivity(_ activity: NSUserActivity) {
        guard let url = activity.webpageURL else { return }
        NotificationCenter.default.post(
            name: .appClipInvocationURL,
            object: nil,
            userInfo: ["url": url]
        )
    }
}

extension Notification.Name {
    static let appClipInvocationURL = Notification.Name("appClipInvocationURL")
}
```

#### 5.4.3 [NEW] `BeamingClip/AppClipJoinView.swift` — Join-only UI

This is the App Clip's single screen. It skips the Home screen entirely and goes straight to: Permission → Connect → Calibration → Meeting.

```swift
//
//  AppClipJoinView.swift
//  BeamingClip
//
//  The App Clip's root view. Shows a brief "joining" state, requests
//  permissions, then navigates to the shared MeetingView.
//

import SwiftUI

struct AppClipJoinView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: AppClipJoinViewModel?
    @State private var showPermission = true  // Always show on first launch
    @State private var navigateToMeeting = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                BlobShape()
                    .fill(BeamingPalette.blob)
                    .frame(width: 360, height: 360)
                    .blur(radius: 50)
                    .opacity(0.45)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .offset(x: 140, y: -150)
                
                BlobShape()
                    .fill(BeamingPalette.blob)
                    .frame(width: 360, height: 360)
                    .blur(radius: 50)
                    .opacity(0.35)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .offset(x: -150, y: 180)
                
                VStack(spacing: 24) {
                    Image("MascotHome")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                    
                    Text("Beaming")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(BeamingPalette.wordmark)
                    
                    if let vm = viewModel {
                        if vm.isConnecting {
                            ProgressView("Menghubungkan ke diskusi…")
                                .tint(BeamingPalette.green)
                        } else if vm.connectionFailed {
                            VStack(spacing: 12) {
                                Image(systemName: "wifi.exclamationmark")
                                    .font(.system(size: 44))
                                    .foregroundStyle(BeamingPalette.pink)
                                Text("Tidak dapat terhubung")
                                    .font(.system(size: 17, weight: .semibold))
                                Text("Pastikan kamu dekat dengan host dan coba lagi.")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        } else {
                            Text("Bergabung ke diskusi…")
                                .font(.system(size: 17))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Menunggu data ruangan…")
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Prompt user to get the full app
                    appStoreOverlay
                }
                .padding(.horizontal, 24)
                .padding(.top, 80)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $navigateToMeeting) {
                if let meetingVM = viewModel?.activeMeetingVM {
                    MeetingView(viewModel: meetingVM)
                        .environment(appState)
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showPermission) {
            PermissionSheet(
                onAllow: {
                    showPermission = false
                    viewModel?.permissionGranted()
                },
                onClose: {
                    showPermission = false
                    // Still try to join — permissions may already exist
                    viewModel?.permissionGranted()
                }
            )
            .presentationDetents([.fraction(0.72), .large])
        }
        .onAppear {
            if viewModel == nil {
                let vm = AppClipJoinViewModel(user: appState.currentUser)
                vm.onJoinSuccess = { [weak vm] in
                    guard vm != nil else { return }
                    navigateToMeeting = true
                }
                viewModel = vm
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .appClipInvocationURL)) { notif in
            if let url = notif.userInfo?["url"] as? URL {
                viewModel?.handleInvocationURL(url)
            }
        }
        .alert("Beaming", isPresented: Binding(
            get: { viewModel?.showAlert ?? false },
            set: { viewModel?.showAlert = $0 }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel?.alertMessage ?? "")
        }
    }
    
    /// Apple's SKOverlay to promote the full app download
    private var appStoreOverlay: some View {
        VStack(spacing: 8) {
            Text("Dapatkan pengalaman lengkap")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Unduh Beaming")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(BeamingPalette.green)
        }
        .padding(.bottom, 32)
        // You can also use .appStoreOverlay(isPresented:) for
        // the native App Store banner. See Apple docs.
    }
}
```

#### 5.4.4 [NEW] `BeamingClip/AppClipJoinViewModel.swift` — Join logic

```swift
//
//  AppClipJoinViewModel.swift
//  BeamingClip
//
//  Handles the App Clip join flow: receives URL → extracts room code
//  → connects to host → produces a MeetingViewModel for navigation.
//

import Foundation
import Network
import Observation
import AVFoundation

@Observable
class AppClipJoinViewModel {
    var currentUser: User
    var activeMeetingVM: MeetingViewModel?
    var isConnecting = false
    var connectionFailed = false
    var showAlert = false
    var alertMessage = ""
    
    var onJoinSuccess: (() -> Void)?
    
    private var roomCode: String?
    private var hasPermission = false
    
    init(user: User) {
        self.currentUser = user
    }
    
    /// Called when the App Clip receives the invocation URL.
    func handleInvocationURL(_ url: URL) {
        guard let code = AppClipURLHelper.extractRoomCode(from: url.absoluteString) else {
            alertMessage = "Kode QR tidak valid."
            showAlert = true
            return
        }
        roomCode = code
        
        // If permission was already granted, connect immediately
        if hasPermission {
            connectToRoom(code: code)
        }
        // Otherwise, wait for permissionGranted() to be called
    }
    
    /// Called after the user grants permissions.
    func permissionGranted() {
        AVAudioApplication.requestRecordPermission { _ in }
        hasPermission = true
        
        // If we already have a room code, connect now
        if let code = roomCode {
            connectToRoom(code: code)
        }
    }
    
    /// Connect to the host's room using the extracted Bonjour service name.
    private func connectToRoom(code: String) {
        let nm = NetworkManager()
        let endpoint = NWEndpoint.service(
            name: code,
            type: "_beaming._tcp",
            domain: "local.",
            interface: nil
        )
        
        isConnecting = true
        connectionFailed = false
        var didComplete = false
        
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, !didComplete else { return }
            didComplete = true
            self.isConnecting = false
            self.connectionFailed = true
            self.alertMessage = "Tidak dapat terhubung. Pastikan kamu dekat dengan host."
            self.showAlert = true
            nm.disconnectFromHost()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)
        
        nm.connectToHost(endpoint: endpoint, localUser: currentUser) { [weak self] success in
            guard let self, !didComplete else { return }
            didComplete = true
            timeout.cancel()
            self.isConnecting = false
            if success {
                let vm = MeetingViewModel(
                    localUser: self.currentUser,
                    networkManager: nm,
                    asHost: false
                )
                self.activeMeetingVM = vm
                self.onJoinSuccess?()
            } else {
                self.connectionFailed = true
                self.alertMessage = "Gagal terhubung ke ruangan."
                self.showAlert = true
            }
        }
    }
}
```

---

### Phase 5: Full App — Handle Universal Links (Existing Users)

When a user **already has** Beaming installed and scans the App Clip QR code with the system Camera, iOS opens the **full app** (not the App Clip) via Universal Link. We need to handle this.

#### 5.5.1 [MODIFY] [BeamingApp.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/BeamingApp.swift) — Add Universal Link handler

```diff
  @main
  struct BeamingApp: App {
      var body: some Scene {
          WindowGroup {
              ContentView()
+                 .onOpenURL { url in
+                     // Forward App Clip URLs to the home view model
+                     NotificationCenter.default.post(
+                         name: .appClipJoinURL,
+                         object: nil,
+                         userInfo: ["url": url]
+                     )
+                 }
+                 .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
+                     if let url = activity.webpageURL {
+                         NotificationCenter.default.post(
+                             name: .appClipJoinURL,
+                             object: nil,
+                             userInfo: ["url": url]
+                         )
+                     }
+                 }
          }
      }
  }
+
+ extension Notification.Name {
+     static let appClipJoinURL = Notification.Name("appClipJoinURL")
+ }
```

#### 5.5.2 [MODIFY] [HomeViewModel.swift](file:///Users/axelnakata/Swift%20Coding/Beaming/Beaming/ViewModel/HomeViewModel.swift) — Auto-join from Universal Link

Add a method to handle incoming URLs, plus subscribe in `onAppear`:

```swift
/// Handle an incoming Universal Link (user scanned App Clip QR with Camera, but has full app).
func handleIncomingURL(_ url: URL) {
    guard let code = AppClipURLHelper.extractRoomCode(from: url.absoluteString) else { return }
    
    if UserDefaults.standard.bool(forKey: permissionKey) {
        joinWithCode(code)
    } else {
        // Store the code, show permission, then join
        pendingRoomCode = code
        pendingAction = .join
        showPermission = true
    }
}
```

---

## 6. File Structure After Changes

```
Beaming/
├── BeamingApp.swift                  ← MODIFIED (Universal Link handler)
├── ContentView.swift                 (unchanged)
├── Info.plist                        (unchanged)
├── Beaming.entitlements              ← NEW (Associated Domains)
├── Helpers/
│   └── AppClipURLHelper.swift        ← NEW (shared by both targets)
├── Model/                            (all unchanged)
├── ViewModel/
│   ├── HomeViewModel.swift           ← MODIFIED (URL parsing in joinWithCode)
│   └── ... (rest unchanged)
├── View/                             (all unchanged)
├── Component/
│   ├── QRCode.swift                  ← MODIFIED (QR encodes URL now)
│   └── Theme.swift                   (unchanged)
│
BeamingClip/                          ← NEW TARGET
├── BeamingClipApp.swift              ← NEW (App Clip @main)
├── AppClipJoinView.swift             ← NEW (landing + join UI)
├── AppClipJoinViewModel.swift        ← NEW (join logic)
├── BeamingClip.entitlements          ← NEW (Associated Domains)
└── Info.plist                        ← NEW (permissions, NSAppClip)
```

---

## 7. Both User Scenarios — End-to-End Flow

### Scenario A: User does NOT have Beaming

```
1. Host creates room → QR shows URL:
   https://beaming.app/join?room=CeriaRubah::::ABCD-1234

2. New user opens iPhone Camera → scans QR

3. iOS sees the URL → no full app installed → shows App Clip banner card:
   "Beaming — Bergabung ke diskusi"
   [Open]

4. User taps "Open" → App Clip downloads (< 15 MB, instant)

5. BeamingClipApp receives the URL via onContinueUserActivity

6. AppClipJoinView shows:
   - Beaming mascot + branding
   - Permission sheet (Mic + Local Network)
   - "Menghubungkan ke diskusi…" spinner

7. After permission → AppClipJoinViewModel.connectToRoom() →
   NWEndpoint.service(name: "CeriaRubah::::ABCD-1234", ...) → connect

8. On success → MeetingView (shared code) → Calibration → Discussion

9. At the bottom: "Unduh Beaming" prompt (promotes full app)
```

### Scenario B: User ALREADY has Beaming

```
1. Host creates room → same QR URL

2. User with full app has TWO options:

   Option B1: Scan with Beaming's in-app scanner
   - Opens QR scanner from Home → scans the URL QR
   - QRScannerView.onScan receives the URL string
   - HomeViewModel.joinWithCode() extracts room code from URL
   - Joins via Bonjour as before → Calibration → Discussion

   Option B2: Scan with iPhone Camera
   - Camera detects Universal Link
   - iOS sees full app is installed → opens Beaming directly (NOT the App Clip)
   - BeamingApp.onContinueUserActivity receives the URL
   - Forwards to HomeViewModel.handleIncomingURL()
   - Auto-joins the room → Calibration → Discussion
```

---

## 8. Constraints & Considerations

> [!WARNING]
> ### Domain Requirement
> You **must** own a domain and host the AASA file. There is no way around this for App Clips/Universal Links. However, this can be a completely static file (no backend server needed). GitHub Pages or Netlify's free tier works perfectly.

> [!IMPORTANT]
> ### Apple Developer Program
> App Clips require an active Apple Developer Program membership ($99/year) to:
> - Register the App Clip in App Store Connect
> - Configure the Associated Domain
> - Submit the App Clip for review (it goes through App Review, same as the full app)

> [!NOTE]
> ### App Clip Size Limit
> The App Clip must be under **15 MB** (uncompressed). Beaming's entire codebase is lightweight (no external dependencies, SVG assets are tiny), so this is not a concern. You can verify with: Xcode → Product → Archive → check "App Clip Size" in the organizer.

### Other Notes
- **Bonjour/P2P in App Clips**: `Network.framework` with `includePeerToPeer = true` works in App Clips. Apple does not restrict local networking for App Clips (only some APIs like background fetch, CallKit, etc. are restricted).
- **Microphone in App Clips**: Fully supported. The App Clip will prompt for mic permission just like the full app.
- **UserDefaults in App Clips**: App Clips have their own sandboxed `UserDefaults`. The auto-generated user name/ID will be unique to the App Clip (not shared with the full app unless you set up a shared App Group).
- **App Clip Lifetime**: iOS may delete the App Clip after a period of inactivity (typically 30 days). This is fine — Beaming doesn't store persistent data.
- **Testing**: You can test App Clips in Xcode using the `_XCAppClipURL` environment variable or via the **Local Experiences** feature in Developer Settings on a physical device.

---

## 9. Testing Strategy

### 9.1 In Xcode (Simulator + Device)
1. Select the `BeamingClip` scheme
2. Edit scheme → Run → set `_XCAppClipURL` environment variable to:
   ```
   https://beaming.app/join?room=TestHost::::00000000-0000-0000-0000-000000000000
   ```
3. Run → the App Clip launches with that URL → verify it extracts the room code

### 9.2 On Device (Local Experience)
1. Go to **Settings → Developer → Local Experiences → Register Local Experience**
2. URL Prefix: `https://beaming.app`
3. Bundle ID: `com.yourcompany.Beaming.Clip`
4. This makes scanning any QR with that domain prefix trigger the App Clip

### 9.3 Two-Device Test
1. Device A: Run full Beaming → "Mulai diskusi" → QR shows URL
2. Device B (no Beaming): Scan with Camera → App Clip card → join
3. Verify both devices are in the same discussion room
4. Device C (has Beaming): Scan same QR with Camera → full app opens → auto-joins
5. Device C alternative: Open Beaming → "Scan QR" → scan → joins via in-app scanner

---

## 10. Summary of Changes

| Category | Files Modified | Files Created |
|---|---|---|
| Existing code changes | 3 files (QRCode.swift, HomeViewModel.swift, BeamingApp.swift) | — |
| Shared helper | — | 1 file (AppClipURLHelper.swift) |
| App Clip target | — | 4 files (BeamingClipApp, AppClipJoinView, AppClipJoinViewModel, Info.plist) |
| Entitlements | — | 2 files (Beaming.entitlements, BeamingClip.entitlements) |
| Server-side | — | 1 file (apple-app-site-association) |
| **Total** | **3 modified** | **8 new** |

> [!TIP]
> The changes are minimal by design. The App Clip **reuses all shared code** (models, networking, audio, flashlight, meeting view, calibration, theme) and only adds a new entry point + lightweight join flow. Existing users are completely unaffected.
