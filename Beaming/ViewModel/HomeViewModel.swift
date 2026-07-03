//
//  HomeViewModel.swift
//  Beaming
//
//  Created by Axel Nino Nakata on 02/07/26.
//

import Foundation
import Network
import Observation
import AVFoundation

@Observable
class HomeViewModel {
    var currentUser: User
    var availableRooms: [DiscoveredRoom] = []
    var showAlert: Bool = false
    var alertMessage: String = ""
    var isJoining: Bool = false
    
    /// Set when navigation to meeting should occur.
    var navigateToMeeting: Bool = false
    
    /// The MeetingViewModel for the active meeting (created on join/create).
    var activeMeetingVM: MeetingViewModel?
    
    /// Dedicated NetworkManager for browsing only. Meeting gets its own.
    private let browseManager = NetworkManager()
    private var discoveryTimer: Timer?
    
    /// Represents a room discovered via Bonjour.
    struct DiscoveredRoom: Identifiable {
        var id: String  // Bonjour service name
        var hostName: String
        var roomName: String
        var endpoint: NWEndpoint
        
        init(from result: NWBrowser.Result) {
            self.endpoint = result.endpoint
            
            // Parse host name from service name (format: "hostName::::roomID")
            if case .service(let name, _, _, _) = result.endpoint {
                self.id = name
                let components = name.components(separatedBy: "::::")
                if components.count >= 2 {
                    self.hostName = components[0]
                } else {
                    self.hostName = name
                }
            } else {
                self.id = UUID().uuidString
                self.hostName = "Unknown"
            }
            
            self.roomName = "\(hostName)'s Room"
        }
    }
    
    init(currentUser: User) {
        self.currentUser = currentUser
    }
    
    // MARK: - Discovery
    
    func startDiscovery() {
        browseManager.startBrowsing()
        
        // Observe discovered rooms from Bonjour browser results
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.availableRooms = self.browseManager.discoveredRooms.map { DiscoveredRoom(from: $0) }
            }
        }
    }
    
    func stopDiscovery() {
        discoveryTimer?.invalidate()
        discoveryTimer = nil
        browseManager.stopBrowsing()
    }
    
    /// Restart browsing to refresh the room list.
    func refreshRooms() {
        stopDiscovery()
        availableRooms = []
        startDiscovery()
    }
    
    // MARK: - Role Change
    
    /// Change the user's role and request permissions if needed.
    func changeRole(to newRole: Role, appState: AppState) {
        currentUser.role = newRole
        appState.saveUser(name: currentUser.name, role: newRole)
        
        // Request mic permission if switching to hearing
        if newRole == .hearing {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if !granted {
                        self.alertMessage = "Microphone access is needed for hearing users. You can enable it in Settings."
                        self.showAlert = true
                    }
                }
            }
        }
    }
    
    // MARK: - Join Room
    
    func joinRoom(room: DiscoveredRoom) {
        // Prevent double-tap / concurrent joins
        guard !isJoining else { return }
        isJoining = true
        
        // Stop browsing — we're committing to joining
        stopDiscovery()
        
        // Create a FRESH NetworkManager for the meeting session
        let meetingNetworkManager = NetworkManager()
        
        // Timeout: if connection doesn't succeed in 5 seconds, abort
        var didComplete = false
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self, !didComplete else { return }
            didComplete = true
            self.isJoining = false
            self.alertMessage = "Connection timed out. Please try again."
            self.showAlert = true
            meetingNetworkManager.disconnectFromHost()
            // Restart discovery
            self.startDiscovery()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: timeoutWork)
        
        meetingNetworkManager.connectToHost(endpoint: room.endpoint, localUser: currentUser) { [weak self] success in
            guard let self = self, !didComplete else { return }
            didComplete = true
            timeoutWork.cancel()
            
            if success {
                let meetingVM = MeetingViewModel(
                    localUser: self.currentUser,
                    networkManager: meetingNetworkManager,
                    asHost: false
                )
                self.activeMeetingVM = meetingVM
                self.navigateToMeeting = true
                self.isJoining = false
            } else {
                self.isJoining = false
                self.alertMessage = "Failed to connect to room."
                self.showAlert = true
                meetingNetworkManager.disconnectFromHost()
                // Restart discovery
                self.startDiscovery()
            }
        }
    }
    
    // MARK: - Create Room
    
    func createRoom() {
        // Prevent accidental double-create
        guard !isJoining else { return }
        isJoining = true
        
        // Stop browsing
        stopDiscovery()
        
        // Create a FRESH NetworkManager for the meeting session
        let meetingNetworkManager = NetworkManager()
        
        let meetingVM = MeetingViewModel(
            localUser: currentUser,
            networkManager: meetingNetworkManager,
            asHost: true
        )
        self.activeMeetingVM = meetingVM
        self.navigateToMeeting = true
        self.isJoining = false
    }
    
    // MARK: - Reset after leaving meeting
    
    func resetAfterMeeting() {
        activeMeetingVM = nil
        navigateToMeeting = false
        isJoining = false
        // Restart discovery for finding new rooms
        startDiscovery()
    }
}
