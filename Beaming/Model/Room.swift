//
//  Room.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import Foundation

struct Room: Identifiable, Codable {
    var id: UUID
    var name: String
    var hostID: UUID
    var hostName: String
    var isSpeaker: UUID?
    var participants: [User]
    
    var participantCount: Int {
        participants.count
    }
    
    var isFull: Bool {
        participantCount >= 8
    }
    
    init(id: UUID, host: User, participants: [User] = []) {
        self.id = id
        self.hostID = host.id
        self.hostName = host.name
        self.name = host.name + "'s Room"
        var allParticipants = participants
        if !allParticipants.contains(where: { $0.id == host.id }) {
            var hostUser = host
            hostUser.joinedTime = Date()
            allParticipants.insert(hostUser, at: 0)
        }
        self.participants = allParticipants
    }
}
