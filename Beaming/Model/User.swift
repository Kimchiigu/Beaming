//
//  User.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import Foundation

struct User: Identifiable {
    var id: UUID = UUID()
    var name: String
    var role: Role
    var joinedTime: Date?
    var isSpeaking: Bool = false
    var isFlashlight: Bool = false
    
    init(name: String, role: Role) {
        self.name = name
        self.role = role
    }
}
