//
//  AppState.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import Foundation
import Observation

@Observable
class AppState {
    var currentUser: User?
    var hasOnboarded: Bool {
        get { UserDefaults.standard.bool(forKey: "hasOnboarded") }
        set { UserDefaults.standard.set(newValue, forKey: "hasOnboarded") }
    }
    
    init() {
        loadUser()
    }
    
    func saveUser(name: String, role: Role) {
        let id: UUID
        if let storedID = UserDefaults.standard.string(forKey: "userID"),
           let uuid = UUID(uuidString: storedID) {
            id = uuid
        } else {
            id = UUID()
            UserDefaults.standard.set(id.uuidString, forKey: "userID")
        }
        
        UserDefaults.standard.set(name, forKey: "userName")
        UserDefaults.standard.set(role.rawValue, forKey: "userRole")
        
        currentUser = User(name: name, role: role, id: id)
        hasOnboarded = true
    }
    
    func loadUser() {
        guard hasOnboarded,
              let name = UserDefaults.standard.string(forKey: "userName"),
              let roleRaw = UserDefaults.standard.string(forKey: "userRole"),
              let role = Role(rawValue: roleRaw),
              let idString = UserDefaults.standard.string(forKey: "userID"),
              let id = UUID(uuidString: idString)
        else {
            currentUser = nil
            return
        }
        currentUser = User(name: name, role: role, id: id)
    }
    
    func resetOnboarding() {
        hasOnboarded = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userRole")
        UserDefaults.standard.removeObject(forKey: "userID")
    }
}
