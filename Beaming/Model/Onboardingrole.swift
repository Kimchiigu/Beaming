//
//  Onboardingrole.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Represents the role a user selects during onboarding.
/// Used later to personalize the app experience (captions layout, permissions, etc).
enum OnboardingRole: String, CaseIterable, Identifiable, Codable {
    case deaf = "Deaf"
    case hearing = "Hearing"
    case interpreter = "Interpreter"
    case teacher = "Teacher"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .deaf: return "ear.trianglebadge.exclamationmark"
        case .hearing: return "ear"
        case .interpreter: return "hands.and.sparkles.fill"
        case .teacher: return "graduationcap.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .deaf: return .purple
        case .hearing: return .blue
        case .interpreter: return .green
        case .teacher: return .orange
        }
    }
}
