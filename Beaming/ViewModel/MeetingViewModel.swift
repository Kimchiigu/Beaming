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
    
    // MARK: - Managers
    
    let networkManager: NetworkManager
    let audioManager = AudioManager()
    let flashlightManager = FlashlightManager()
    
    // MARK: - Private
    
    /// Pending connection for host accepting new guests
    private var pendingConnections: [ObjectIdentifier: NWConnection] = [:]
    private let motionManager = CMMotionManager()
    
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
        
        // Start audio for hearing users
        if localUser.role == .hearing || localUser.role == .nonBinary {
            setupAudio()
            startFaceDownDetection()
        }
    }
    
    // MARK: - Host Setup
    
    private func startHosting() {
        networkManager.startAdvertising(roomID: room.id, hostName: localUser.name)
    }
    
    // MARK: - Audio Setup
    
    private func setupAudio() {
        audioManager.onSpeakingStateChanged = { [weak self] speaking in
            guard let self = self else { return }
            if speaking {
                self.claimSpeaker()
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
            
        case .speakerClaim(let userID):
            handleSpeakerClaim(from: userID)
            
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
        }
    }
    
    // MARK: - Join Handling (Host Side)
    
    private func handleJoinRequest(_ user: User) {
        guard isHost else { return }
        
        if room.isFull {
            // Find the pending connection for this user and reject
            // Send rejection via broadcast (the user will check their own ID)
            let response = NetworkMessage.joinResponse(success: false, room: nil, reason: "Room is full")
            networkManager.broadcastMessage(response)
            return
        }
        
        // Add user to room
        var joiningUser = user
        joiningUser.joinedTime = Date()
        room.participants.append(joiningUser)
        
        // Register the pending connection with this user's ID
        // Find the most recent pending connection
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
    
    // MARK: - Speaker Lock
    
    /// Attempt to claim the speaker lock (called when local user starts speaking).
    private func claimSpeaker() {
        guard !isMuted else { return }
        
        if isHost {
            // Host evaluates locally
            handleSpeakerClaim(from: localUser.id)
        } else {
            // Guest sends claim to host
            networkManager.sendToHost(.speakerClaim(userID: localUser.id))
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
    
    /// Evaluate a speaker claim (host side).
    private func handleSpeakerClaim(from userID: UUID) {
        if isHost {
            if room.isSpeaker == nil {
                // Room is free — grant the lock
                room.isSpeaker = userID
                
                // If the host themselves claimed it
                if userID == localUser.id {
                    isActiveSpeaker = true
                    flashlightManager.setFlashlight(on: true)
                }
                
                // Broadcast speaker status to all
                networkManager.broadcastMessage(.speakerStatus(speakerID: userID))
            }
            // If room is locked by another user, silently reject
        }
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
    
    /// Leave the room.
    func leaveRoom() {
        if isHost {
            // Host handover: find oldest guest
            let guests = room.participants.filter { $0.id != localUser.id }
            
            if let oldestGuest = guests.sorted(by: {
                ($0.joinedTime ?? .distantFuture) < ($1.joinedTime ?? .distantFuture)
            }).first {
                // Handover to oldest guest
                room.hostID = oldestGuest.id
                room.hostName = oldestGuest.name
                room.name = oldestGuest.name + "'s Room"
                room.participants.removeAll { $0.id == localUser.id }
                
                // Broadcast handover + updated state
                networkManager.broadcastMessage(.hostHandover(newHostID: oldestGuest.id))
                broadcastParticipantUpdate()
            } else {
                // No guests left — end the room
                endRoom()
                return
            }
        } else {
            // Guest leaving
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
        audioManager.stopListening()
        flashlightManager.setFlashlight(on: false)
        motionManager.stopAccelerometerUpdates()
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
