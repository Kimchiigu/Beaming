//
//  AppState.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import Foundation
import Observation

/// Global app state. `currentUser` (stable UUID + generated codename, used
/// only for room naming) is created automatically on first launch — no
/// change there.
///
/// Separately, a one-time *profile* onboarding (username + role) is shown
/// the first time the app opens so the experience can be personalized. Once
/// completed, `hasCompletedOnboarding` flips to true forever (persisted),
/// so returning users skip straight past onboarding.
@Observable
class AppState {
    var currentUser: User

    // MARK: - Profile onboarding (username + role)

    var profileUsername: String?
    var profileRole: OnboardingRole?

    var hasCompletedOnboarding: Bool {
        profileUsername != nil && profileRole != nil
    }

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

        profileUsername = UserDefaults.standard.string(forKey: "profileUsername")
        if let roleRaw = UserDefaults.standard.string(forKey: "profileRole") {
            profileRole = OnboardingRole(rawValue: roleRaw)
        }
    }

    /// Called once, from the onboarding form, when the user taps Continue.
    func completeOnboarding(username: String, role: OnboardingRole) {
        profileUsername = username
        profileRole = role
        UserDefaults.standard.set(username, forKey: "profileUsername")
        UserDefaults.standard.set(role.rawValue, forKey: "profileRole")
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
