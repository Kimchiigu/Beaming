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
    
    /// Set when navigation to meeting should occur.
    var navigateToMeeting: Bool = false
    
    /// The MeetingViewModel for the active meeting (created on join/create).
    var activeMeetingVM: MeetingViewModel?
    
    let networkManager = NetworkManager()
    
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
        networkManager.startBrowsing()
        
        // Observe discovered rooms from Bonjour browser results
        // We use a timer to periodically sync since NWBrowser.Result isn't directly Observable
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.availableRooms = self.networkManager.discoveredRooms.map { DiscoveredRoom(from: $0) }
            }
        }
    }
    
    func stopDiscovery() {
        networkManager.stopBrowsing()
    }
    
    /// Restart browsing to refresh the room list.
    func refreshRooms() {
        networkManager.stopBrowsing()
        availableRooms = []
        networkManager.startBrowsing()
    }
    
    // MARK: - Role Change
    
    /// Change the user's role and request permissions if needed.
    func changeRole(to newRole: Role, appState: AppState) {
        currentUser.role = newRole
        appState.saveUser(name: currentUser.name, role: newRole)
        
        // Request mic permission if switching to hearing
        if newRole == .hearing || newRole == .nonBinary {
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
        networkManager.connectToHost(endpoint: room.endpoint, localUser: currentUser) { [weak self] success in
            guard let self = self else { return }
            if success {
                // Create a MeetingViewModel as guest
                let meetingVM = MeetingViewModel(
                    localUser: self.currentUser,
                    networkManager: self.networkManager,
                    asHost: false
                )
                self.activeMeetingVM = meetingVM
                self.navigateToMeeting = true
            } else {
                self.alertMessage = "Failed to connect to room."
                self.showAlert = true
            }
        }
    }
    
    // MARK: - Create Room
    
    func createRoom() {
        let meetingVM = MeetingViewModel(
            localUser: currentUser,
            networkManager: networkManager,
            asHost: true
        )
        self.activeMeetingVM = meetingVM
        self.navigateToMeeting = true
    }
}
