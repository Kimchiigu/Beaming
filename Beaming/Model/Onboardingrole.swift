//
//  Onboardingrole.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import Foundation

/// The two roles a user can pick during onboarding.
/// Used later to personalize the app experience (captions layout, permissions, etc).
enum OnboardingRole: String, CaseIterable, Identifiable, Codable {
    case temanTuli = "Teman Tuli"
    case temanDengar = "Teman Dengar"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var imageName: String {
        switch self {
        case .temanTuli: return "role1"
        case .temanDengar: return "role2"
        }
    }

    var description: String {
        switch self {
        case .temanTuli: return "Mengetahui siapa yang berbicara & membaca transkrip"
        case .temanDengar: return "Membantu teman tuli mengikuti obrolan"
        }
    }
}
