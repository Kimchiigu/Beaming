# Product Requirements Document (PRD)
**Project Name:** Beaming (MVP)
**Core Goal:** An offline iOS application utilizing local P2P networking and hardware flashlights to help a single deaf user visually identify the active speaker during small group discussions (up to 8 people).

---

## 1. Development Context & Prerequisites
**Instruction for AI/Developer:** Before generating new code, you MUST read the current project directory and existing files. The MVVM architecture, baseline `Role`, `User`, and `Room` models, and simple UI placeholders are already established. Your task is to build upon this existing context without overriding the established aesthetic (strict black & white, minimal styling).

---

## 2. Technical Stack & Infrastructure
* **Target Platform:** iOS (iPhones only).
* **Architecture:** MVVM (Strict separation of UI and business logic).
* **Networking Layer:** `Network.framework`.
* **Discovery Protocol:** Bonjour (mDNS) zero-configuration networking.
* **Transport Protocol:** Custom TCP socket connections (`NWListener` & `NWConnection`).
* **Network Constraint:** P2P Local only via `includePeerToPeer` flag. No cloud, no database, no internet requirement. Users only need Wi-Fi toggled ON (AWDL handles the local connection even without a shared router).

---

## 3. User Roles & Permissions Flow
Roles are strictly defined during the initial Onboarding phase. Permissions must ONLY be requested based on the selected role to respect user privacy.

* **Deaf User (Max 1 per room):**
  * **Function:** Observer. Reads lips based on flashlight visual cues.
  * **Permissions Required:** Local Network (Scan/Discovery) ONLY.
  * **Hardware UX:** Phone placed face-up normally on the table.

* **Hearing User (Max 7 per room):**
  * **Function:** Speaker. Provides audio input to trigger visual cues.
  * **Permissions Required:** Local Network (Scan/Discovery), Microphone (Audio processing), Camera/Torch (Flashlight control).
  * **Hardware UX:** Phone placed face-down on the table during the active meeting. UI is locked/simplified to prevent accidental touches.

---

## 4. App Flow & User Journey

### Phase 1: Onboarding
* User inputs their Name.
* User selects their Role (Deaf or Hearing).
* App requests the specific hardware permissions based on the Role selected.

### Phase 2: Home View (Discovery)
* Displays a welcome message and the user's role.
* Continuously scans and displays a list of available rooms via Bonjour.
* **Create Action:** Any user (Deaf/Hearing) can create a room, becoming the Host.
* **Join Action:** Any user can tap to join a room.
* **Validation:** `HomeViewModel` must reject joining if room capacity is at 8. Maximum room capacity is exactly 1 Host + 7 Guests.

### Phase 3: The Meeting Room (Lobby & Active State)
The UI displayed depends strictly on the user's role and host status. All rooms display a list of current participants.

* **Hearing Host UI:** Features a Mic toggle (Mute/Unmute), "Leave Room" button, and "End Room" button.
* **Hearing Guest UI:** Features a Mic toggle (Mute/Unmute), and "Leave Room" button.
* **Deaf Host UI:** Features a "Leave Room" button, and "End Room" button.
* **Deaf Guest UI:** Features a "Leave Room" button.

---

## 5. Core Logic & Mechanics

### Host Handover & Room Termination
* **End Room (Host Only):** Force-disconnects all peers and destroys the room.
* **Leave Room (Host):** Triggers a Handover event. The guest with the oldest `joinedTime` timestamp is promoted to Host. The room name instantly updates to reflect the new Host's name. The new Host's UI updates to include the "End Room" option.
* **Leave Room (Guest):** Guest disconnects; room capacity decreases.

### The "One-Speaker Lock" (Flashlight Mechanic)
This is the critical audio-visual synchronization loop. The deaf user can only focus on one person at a time, requiring a strict 1-speaker lock.

* **Audio Threshold:** A hearing user's phone listens for audio. When they speak, their local `isSpeaking` boolean turns `true`.
* **The Request:** The speaking user's phone pings the room state to check the `isSpeaker` variable.
* **The Lock Evaluation:**
  * If `isSpeaker` == `null` (Room is free): The user claims the room. `isSpeaker` is set to their UUID. Their local `isFlashlight` turns `true` (Hardware flashlight turns ON).
  * If `isSpeaker` == `[Another User's UUID]` (Room is locked): The room rejects the request. The interrupting user's `isFlashlight` remains `false`.
* **The Handover (Silence Detection):** The active speaker's device monitors for silence. After exactly 2 seconds of zero audio input above the threshold, the device releases the lock. `isSpeaker` becomes `null`, the flashlight turns OFF, and the room is open for the next speaker.

---

## 6. UI/UX Constraints (MVP)
* **Styling:** Strictly default, highly legible black-and-white UI. Focus entirely on structural integrity and state management.
* **Face-Down State:** Hearing users require a full-screen, locked "Active Meeting" view to prevent accidental hang-ups or muting while the phone is face-down on the table.
* **Modals:** Use simple, default iOS modals (`.alert`) for all warnings (e.g., "Room is full", "Host ended the meeting").