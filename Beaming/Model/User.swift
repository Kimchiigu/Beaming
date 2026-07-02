//
//  User.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import Foundation

struct User: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var role: Role
    var joinedTime: Date?
    var isSpeaking: Bool = false
    var isFlashlight: Bool = false
    
    init(name: String, role: Role, id: UUID = UUID()) {
        self.id = id
        self.name = name
        self.role = role
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
