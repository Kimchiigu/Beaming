//
//  User.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import Foundation

/// A participant in a discussion. Every participant is a speaker — the phone
/// blinks its flashlight when they speak. There is no deaf/hearing distinction.
struct User: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var joinedTime: Date?

    init(name: String, id: UUID = UUID()) {
        self.id = id
        self.name = name
    }

    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
