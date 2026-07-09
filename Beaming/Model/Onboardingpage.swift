//
//  Onboardingpage.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Static content for the illustrated (non-form) onboarding slides.
/// Only the first two onboarding screens use this — the third screen is an
/// interactive form and lives in its own view (`OnboardingFormView`).
struct OnboardingPage: Identifiable {
    let id: Int
    let systemImage: String
    let iconTint: Color
    let titleLine1: String
    let titleLine2: String
    let titleLine2Color: Color
    let description: String
    let accentColor: Color

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            systemImage: "bubble.left.and.bubble.right.fill",
            iconTint: .blue,
            titleLine1: "Welcome to",
            titleLine2: "Beaming",
            titleLine2Color: .blue,
            description: "An offline meeting app that helps everyone know who is speaking. Built for clarity. Designed for inclusion.",
            accentColor: .blue
        ),
        OnboardingPage(
            id: 1,
            systemImage: "checkmark.shield.fill",
            iconTint: .green,
            titleLine1: "Private. Local.",
            titleLine2: "Always Secure.",
            titleLine2Color: .green,
            description: "Beaming works offline using local network only. Your data stays on your devices.",
            accentColor: .green
        )
    ]
}
