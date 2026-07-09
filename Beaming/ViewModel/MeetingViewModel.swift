//
//  MeetingViewModel.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import Foundation
import Network
import Observation
import CoreMotion

/// ViewModel for the active meeting room. Manages room state, speaker lock,
/// audio detection, flashlight control, and P2P communication.
@Observable
class MeetingViewModel {
    
    // MARK: - Published State
    
    var room: Room
    var localUser: User
    var isHost: Bool
    var isMuted: Bool = false
    var showAlert: Bool = false
    var alertMessage: String = ""
    var shouldDismiss: Bool = false
    var isFaceDown: Bool = false
    
    /// Whether this device currently holds the speaker lock and has flashlight on.
    var isActiveSpeaker: Bool = false
    
    /// Whether the calibration screen should be shown (hearing users only).
    var showCalibration: Bool = false
    
    /// Whether calibration has been completed.
    var isCalibrationDone: Bool = false

    // MARK: - Live captions (one bubble per speaking turn, max 5)

    /// Turn bubbles, newest last. The last bubble is the currently-streaming turn.
    var captions: [CaptionMessage] = []

    /// Speaker whose turn is currently streaming (nil between turns). Read by the
    /// view to show the "typing" indicator on the last bubble.
    var activeSpeakerID: UUID?
    
    // MARK: - Managers
    
    let networkManager: NetworkManager
    let audioManager = AudioManager()
    let flashlightManager = FlashlightManager()
    
    // MARK: - Private
    
    /// Pending connection for host accepting new guests
    private var pendingConnections: [ObjectIdentifier: NWConnection] = [:]
    private let motionManager = CMMotionManager()
    
    /// Competing claim resolution: collect claims in a 150ms window, pick loudest
    private var pendingClaims: [(userID: UUID, rmsLevel: Float)] = []
    private var claimResolutionTimer: Timer?
    private let claimWindowDuration: TimeInterval = 0.15  // 150ms
    
    /// Timer for periodically broadcasting room state to prevent stuck participants
    private var syncTimer: Timer?

    /// Guards leave/cleanup so it only runs once (back button + menu + endRoom).
    private var hasLeft = false

    /// Broadcast throttle + the hard bubble cap requested for the chat.
    private var lastCaptionBroadcast: Date = .distantPast
    private let captionBroadcastMinInterval: TimeInterval = 0.2
    /// At most this many bubbles are kept; older ones are dropped.
    private let maxCaptions = 5
    
    // MARK: - Init
    
    /// Initialize for a host creating a new room.
    init(localUser: User, networkManager: NetworkManager, asHost: Bool, room: Room? = nil) {
        self.localUser = localUser
        self.networkManager = networkManager
        self.isHost = asHost
        
        if asHost {
            // Host creates the room
            self.room = Room(id: UUID(), host: localUser)
        } else {
            // Guest joins an existing room (room will be updated via network)
            self.room = room ?? Room(id: UUID(), host: localUser)
        }
        
        setupNetworkCallbacks()
        
        if asHost {
            startHosting()
        }
        
        // All users: show calibration first, then start audio after done
        showCalibration = true
        startFaceDownDetection()
    }
    
    // MARK: - Calibration
    
    /// The Bonjour service name encoded for QR sharing. Uses the HOST's name so
    /// a guest sharing the QR still advertises the host's service. Format:
    /// "hostName::::roomID" (matches NetworkManager.startAdvertising).
    var qrCodeString: String {
        "\(room.hostName)::::\(room.id.uuidString)"
    }

    // MARK: - Live Captions

    /// Local transcription produced new text (called from VoiceTranscribeViewModel).
    /// Applies it to the local feed AND broadcasts it to the room.
    func handleLocalCaption(text: String, isFinal: Bool) {
        let speakerID = localUser.id
        let speakerName = localUser.name
        applyCaption(speakerID: speakerID, speakerName: speakerName, text: text, isFinal: isFinal)
        broadcastCaption(speakerID: speakerID, speakerName: speakerName, text: text, isFinal: isFinal)
    }

    /// A caption arrived from a peer over the network.
    private func handleRemoteCaption(speakerID: UUID, speakerName: String, text: String, isFinal: Bool) {
        // Ignore our own captions echoed back.
        guard speakerID != localUser.id else { return }
        applyCaption(speakerID: speakerID, speakerName: speakerName, text: text, isFinal: isFinal)
        // Star topology: the host relays guest captions to the OTHER guests so
        // everyone sees them (guests only have a direct line to the host).
        if isHost {
            networkManager.broadcastMessage(.caption(speakerID: speakerID, speakerName: speakerName, text: text, isFinal: isFinal))
        }
    }

    /// Place a caption into the feed as a single turn-bubble. The bubble grows
    /// while the same speaker keeps talking; a different speaker (or a new turn
    /// after a pause) starts a fresh bubble. The list is capped at `maxCaptions`.
    private func applyCaption(speakerID: UUID, speakerName: String, text: String, isFinal: Bool) {
        ensureActiveBubble(speakerID: speakerID, speakerName: speakerName)
        setLastBubble(text: text)
        if isFinal {
            // Turn ended — next caption (even from the same speaker) starts a new bubble.
            activeSpeakerID = nil
        }
        enforceCaptionCap()
    }

    /// Make sure the last bubble belongs to `speakerID`; otherwise append a new one
    /// (this is the "change bubble when another person talks" rule).
    private func ensureActiveBubble(speakerID: UUID, speakerName: String) {
        guard speakerID != activeSpeakerID || captions.isEmpty else { return }
        captions.append(CaptionMessage(speakerID: speakerID, speakerName: speakerName, text: "", date: Date()))
        activeSpeakerID = speakerID
    }

    private func setLastBubble(text: String) {
        guard !captions.isEmpty else { return }
        captions[captions.count - 1].text = text
    }

    /// Broadcast a caption to the room (host → all guests; guest → host, which relays).
    private func broadcastCaption(speakerID: UUID, speakerName: String, text: String, isFinal: Bool) {
        // Throttle partials (they fire several times/sec); finals always go through.
        if !isFinal {
            let now = Date()
            guard now.timeIntervalSince(lastCaptionBroadcast) >= captionBroadcastMinInterval else { return }
            lastCaptionBroadcast = now
        }
        let msg = NetworkMessage.caption(speakerID: speakerID, speakerName: speakerName, text: text, isFinal: isFinal)
        if isHost {
            networkManager.broadcastMessage(msg)
        } else {
            networkManager.sendToHost(msg)
        }
    }

    /// Cheap cap: only trims when over the limit. Called per partial, so it must be
    /// near O(1). Keeps only the newest `maxCaptions` bubbles.
    private func enforceCaptionCap() {
        guard captions.count > maxCaptions else { return }
        captions.removeFirst(captions.count - maxCaptions)
    }
    
    /// Start the voice calibration process.
    func startCalibration() {
        audioManager.onCalibrationComplete = { [weak self] in
            guard let self = self else { return }
            self.isCalibrationDone = true
            
            // Short delay then dismiss calibration and start listening
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.showCalibration = false
                self.setupAudio()
            }
        }
        audioManager.startCalibration()
    }
    
    // MARK: - Host Setup
    
    private func startHosting() {
        networkManager.startAdvertising(roomID: room.id, hostName: localUser.name)
        
        // Start periodic sync to keep guests in sync (e.g. if a leave message is missed)
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.broadcastParticipantUpdate()
        }
    }
    
    // MARK: - Audio Setup
    
    private func setupAudio() {
        audioManager.onSpeakingStateChanged = { [weak self] speaking, rmsLevel in
            guard let self = self else { return }
            if speaking {
                self.claimSpeaker(rmsLevel: rmsLevel)
            } else {
                self.releaseSpeaker()
            }
        }
        audioManager.startListening()
    }
    
    // MARK: - Network Callbacks
    
    private func setupNetworkCallbacks() {
        // Handle incoming messages
        networkManager.onMessageReceived = { [weak self] message, peerID in
            self?.handleMessage(message, from: peerID)
        }
        
        // Handle peer disconnections
        networkManager.onPeerDisconnected = { [weak self] peerID in
            self?.handlePeerDisconnected(peerID)
        }
        
        // Handle new connections (host side)
        networkManager.onNewConnection = { [weak self] connection in
            // Store pending connection until join request arrives
            self?.pendingConnections[ObjectIdentifier(connection)] = connection
        }
    }
    
    // MARK: - Message Handling
    
    private func handleMessage(_ message: NetworkMessage, from peerID: UUID?) {
        switch message {
            
        case .joinRequest(let user):
            handleJoinRequest(user)
            
        case .joinResponse(let success, let roomData, let reason):
            handleJoinResponse(success: success, room: roomData, reason: reason)
            
        case .participantUpdate(let participants, let hostID, let roomName):
            room.participants = participants
            room.hostID = hostID
            room.name = roomName
            // Check if we became the host
            if hostID == localUser.id {
                isHost = true
            }
            
        case .speakerClaim(let userID, let rmsLevel):
            handleSpeakerClaim(from: userID, rmsLevel: rmsLevel)
            
        case .speakerRelease(let userID):
            handleSpeakerRelease(from: userID)
            
        case .speakerStatus(let speakerID):
            room.isSpeaker = speakerID
            // If we claimed and got it, turn on flashlight
            if speakerID == localUser.id {
                isActiveSpeaker = true
                flashlightManager.setFlashlight(on: true)
            } else if isActiveSpeaker && speakerID != localUser.id {
                isActiveSpeaker = false
                flashlightManager.setFlashlight(on: false)
            }
            
        case .hostHandover(let newHostID):
            if newHostID == localUser.id {
                isHost = true
                room.hostID = newHostID
                room.hostName = localUser.name
                room.name = localUser.name + "'s Room"
                // Take over hosting duties
                startHosting()
            }
            
        case .endRoom:
            alertMessage = "The host has ended the meeting."
            showAlert = true
            cleanup()
            shouldDismiss = true
            
        case .leaveRoom(let userID):
            handlePeerDisconnected(userID)
            
        case .roomInfo(let updatedRoom):
            self.room = updatedRoom

        case .caption(let speakerID, let speakerName, let text, let isFinal):
            handleRemoteCaption(speakerID: speakerID, speakerName: speakerName, text: text, isFinal: isFinal)
        }
    }
    
    // MARK: - Join Handling (Host Side)
    
    private func handleJoinRequest(_ user: User) {
        guard isHost else { return }
        
        if room.isFull {
            // Find the pending connection for this user and reject
            let response = NetworkMessage.joinResponse(success: false, room: nil, reason: "Room is full")
            networkManager.broadcastMessage(response)
            return
        }
        
        // Add user to room
        var joiningUser = user
        joiningUser.joinedTime = Date()
        room.participants.append(joiningUser)
        
        // Register the pending connection with this user's ID
        if let (key, connection) = pendingConnections.first {
            networkManager.registerPeer(user.id, connection: connection)
            pendingConnections.removeValue(forKey: key)
            
            // Send join response to the new user
            let response = NetworkMessage.joinResponse(success: true, room: room, reason: nil)
            networkManager.sendMessageToPeer(response, peerID: user.id)
        }
        
        // Broadcast updated participants to everyone
        broadcastParticipantUpdate()
    }
    
    // MARK: - Join Response (Guest Side)
    
    private func handleJoinResponse(success: Bool, room: Room?, reason: String?) {
        if success, let room = room {
            self.room = room
        } else {
            alertMessage = reason ?? "Could not join room."
            showAlert = true
            shouldDismiss = true
        }
    }
    
    // MARK: - Speaker Lock (with Competing Claim Resolution)
    
    /// Attempt to claim the speaker lock (called when local user starts speaking).
    private func claimSpeaker(rmsLevel: Float) {
        guard !isMuted else { return }
        
        if isHost {
            // Host evaluates locally — add to competing claims window
            handleSpeakerClaim(from: localUser.id, rmsLevel: rmsLevel)
        } else {
            // Guest sends claim with RMS level to host
            networkManager.sendToHost(.speakerClaim(userID: localUser.id, rmsLevel: rmsLevel))
        }
    }
    
    /// Release the speaker lock (called after 2s silence).
    private func releaseSpeaker() {
        if isHost {
            handleSpeakerRelease(from: localUser.id)
        } else {
            networkManager.sendToHost(.speakerRelease(userID: localUser.id))
        }
    }
    
    /// Evaluate a speaker claim (host side) — uses competing claim window.
    private func handleSpeakerClaim(from userID: UUID, rmsLevel: Float) {
        guard isHost else { return }
        
        // If room is already locked by someone, silently reject
        guard room.isSpeaker == nil else { return }
        
        // Add this claim to the pending claims buffer
        pendingClaims.append((userID: userID, rmsLevel: rmsLevel))
        
        // If this is the first claim, start the 150ms resolution window
        if claimResolutionTimer == nil {
            claimResolutionTimer = Timer.scheduledTimer(withTimeInterval: claimWindowDuration, repeats: false) { [weak self] _ in
                self?.resolveCompetingClaims()
            }
        }
    }
    
    /// After the 150ms window, pick the loudest claimant.
    private func resolveCompetingClaims() {
        claimResolutionTimer = nil
        
        // Double-check the room is still free (could have been claimed in a previous resolution)
        guard room.isSpeaker == nil else {
            pendingClaims.removeAll()
            return
        }
        
        // Pick the claim with the highest RMS level (loudest = closest to speaker's mouth)
        guard let winner = pendingClaims.max(by: { $0.rmsLevel < $1.rmsLevel }) else {
            pendingClaims.removeAll()
            return
        }
        
        let winnerID = winner.userID
        print("[MeetingVM] Speaker lock granted to \(winnerID) with RMS \(winner.rmsLevel) (from \(pendingClaims.count) competing claims)")
        
        // Clear pending claims
        pendingClaims.removeAll()
        
        // Grant the lock
        room.isSpeaker = winnerID
        
        // If the host themselves won
        if winnerID == localUser.id {
            isActiveSpeaker = true
            flashlightManager.setFlashlight(on: true)
        }
        
        // Broadcast speaker status to all
        networkManager.broadcastMessage(.speakerStatus(speakerID: winnerID))
    }
    
    /// Handle speaker release (host side).
    private func handleSpeakerRelease(from userID: UUID) {
        if isHost {
            if room.isSpeaker == userID {
                room.isSpeaker = nil
                
                if userID == localUser.id {
                    isActiveSpeaker = false
                    flashlightManager.setFlashlight(on: false)
                }
                
                networkManager.broadcastMessage(.speakerStatus(speakerID: nil))
            }
        }
    }
    
    // MARK: - Room Management
    
    /// Toggle mute for hearing users.
    func toggleMute() {
        isMuted.toggle()
        audioManager.toggleMute()
        
        // If muted while being the active speaker, release the lock
        if isMuted && isActiveSpeaker {
            releaseSpeaker()
            isActiveSpeaker = false
            flashlightManager.setFlashlight(on: false)
        }
    }
    
    /// Leave the room. If the user is the only participant, the room is ended.
    func leaveRoom() {
        guard !hasLeft else { return }
        hasLeft = true

        // Alone in the room → tear it down (and tell peers if we're the host).
        if room.participantCount <= 1 {
            if isHost { networkManager.broadcastMessage(.endRoom) }
            cleanup()
            shouldDismiss = true
            return
        }

        if isHost {
            // Host handover: promote the oldest guest.
            let guests = room.participants.filter { $0.id != localUser.id }
            if let oldestGuest = guests.sorted(by: {
                ($0.joinedTime ?? .distantFuture) < ($1.joinedTime ?? .distantFuture)
            }).first {
                room.hostID = oldestGuest.id
                room.hostName = oldestGuest.name
                room.name = oldestGuest.name + "'s Room"
                room.participants.removeAll { $0.id == localUser.id }

                networkManager.broadcastMessage(.hostHandover(newHostID: oldestGuest.id))
                broadcastParticipantUpdate()
            } else {
                endRoom()
                return
            }
        } else {
            // Guest leaving — host drops them and re-broadcasts the new count.
            networkManager.sendToHost(.leaveRoom(userID: localUser.id))
        }

        cleanup()
        shouldDismiss = true
    }
    
    /// End the room (host only). Force-disconnects all peers.
    func endRoom() {
        guard isHost else { return }
        
        // Broadcast end room to all peers
        networkManager.broadcastMessage(.endRoom)
        
        cleanup()
        shouldDismiss = true
    }
    
    // MARK: - Peer Disconnection
    
    private func handlePeerDisconnected(_ peerID: UUID) {
        room.participants.removeAll { $0.id == peerID }
        
        // If the disconnected peer was the speaker, release the lock
        if room.isSpeaker == peerID {
            room.isSpeaker = nil
            networkManager.broadcastMessage(.speakerStatus(speakerID: nil))
        }
        
        if isHost {
            broadcastParticipantUpdate()
        }
    }
    
    // MARK: - Helpers
    
    private func broadcastParticipantUpdate() {
        let update = NetworkMessage.participantUpdate(
            participants: room.participants,
            hostID: room.hostID,
            roomName: room.name
        )
        networkManager.broadcastMessage(update)
    }
    
    private func cleanup() {
        hasLeft = true
        audioManager.stopListening()
        flashlightManager.setFlashlight(on: false)
        motionManager.stopAccelerometerUpdates()
        claimResolutionTimer?.invalidate()
        claimResolutionTimer = nil
        syncTimer?.invalidate()
        syncTimer = nil
        pendingClaims.removeAll()
        if isHost {
            networkManager.stopAdvertising()
            for (id, _) in networkManager.peerConnections {
                networkManager.disconnectPeer(id)
            }
        } else {
            networkManager.disconnectFromHost()
        }
    }
    
    // MARK: - Face-Down Detection
    
    private func startFaceDownDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.3
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self = self, let data = data else { return }
            // Z-axis > 0.7 means phone is face-down (screen facing table)
            self.isFaceDown = data.acceleration.z > 0.7
        }
    }
    
    deinit {
        cleanup()
    }
}
