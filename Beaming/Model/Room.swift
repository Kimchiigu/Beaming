//
//  Room.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import Foundation

struct Room: Identifiable {
    var id: UUID
    var name: String
    var capacity: Int // max 8
    var isHost: User
    var isSpeaker: UUID?
    var guests: [User]
    
    init(id: UUID, isHost: User, guests: [User]) {
        self.id = id
        self.isHost = isHost
        self.name = isHost.name + "'s room"
        self.capacity = guests.count + 1
        self.guests = guests
    }
}
