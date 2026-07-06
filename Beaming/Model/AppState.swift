//
//  AppState.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import Foundation
import Observation

/// Global app state. There is no onboarding flow — a local identity (stable
/// UUID + a friendly generated name used only for room naming) is created
/// automatically on first launch and persisted.
@Observable
class AppState {
    var currentUser: User

    init() {
        if let idString = UserDefaults.standard.string(forKey: "userID"),
           let id = UUID(uuidString: idString),
           let name = UserDefaults.standard.string(forKey: "userName") {
            currentUser = User(name: name, id: id)
        } else {
            let name = Self.generateName()
            let id = UUID()
            UserDefaults.standard.set(id.uuidString, forKey: "userID")
            UserDefaults.standard.set(name, forKey: "userName")
            currentUser = User(name: name, id: id)
        }
    }

    /// A friendly Indonesian codename, used only for room naming / debugging.
    private static func generateName() -> String {
        let adjectives = ["Ceria", "Bijak", "Berani", "Tenang", "Ramah", "Lucu", "Cerdas"]
        let animals = ["Rubah", "Lumba", "Rusa", "Panda", "Kucing", "Beruang", "Kelinci"]
        let a = adjectives.randomElement() ?? "Ceria"
        let n = animals.randomElement() ?? "Rubah"
        return "\(a) \(n)"
    }
}
