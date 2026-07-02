//
//  NetworkMessage.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import Foundation

/// All message types exchanged over TCP between peers.
enum NetworkMessage: Codable {
    // Connection
    case joinRequest(user: User)
    case joinResponse(success: Bool, room: Room?, reason: String?)
    
    // State sync
    case participantUpdate(participants: [User], hostID: UUID, roomName: String)
    case roomInfo(room: Room)
    
    // Speaker lock
    case speakerClaim(userID: UUID)
    case speakerRelease(userID: UUID)
    case speakerStatus(speakerID: UUID?)
    
    // Room management
    case hostHandover(newHostID: UUID)
    case endRoom
    case leaveRoom(userID: UUID)
    
    // Encoding helpers
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> NetworkMessage? {
        try? JSONDecoder().decode(NetworkMessage.self, from: data)
    }
}
