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
    
    // Speaker lock — speakerClaim now includes RMS level for loudness-based resolution
    case speakerClaim(userID: UUID, rmsLevel: Float)
    case speakerRelease(userID: UUID)
    case speakerStatus(speakerID: UUID?)
    /// Indicator ONLY (lock logic unchanged): every participant currently speaking,
    /// so the transcript can show multi-speaker avatars. Host broadcasts; guests receive.
    case speakingParticipants([UUID])
    
    // Room management
    case hostHandover(newHostID: UUID)
    case endRoom
    case leaveRoom(userID: UUID)

    // Live caption from a speaker — broadcast so everyone sees who says what.
    // isFinal=false → growing partial (replace that speaker's live bubble);
    // isFinal=true  → a finalized sentence (commit a bubble, clear the live one).
    case caption(speakerID: UUID, speakerName: String, text: String, isFinal: Bool)
    
    // Encoding helpers
    func encode() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func decode(from data: Data) -> NetworkMessage? {
        try? JSONDecoder().decode(NetworkMessage.self, from: data)
    }
}
