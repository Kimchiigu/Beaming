//
//  Onboardingpage.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import Foundation

/// Static content for the illustrated onboarding slides.
/// Only the first two onboarding screens use this — the third screen is an
/// interactive form and lives in its own view (`OnboardingFormView`).
struct OnboardingPage: Identifiable {
    let id: Int
    let imageName: String
    let title: String
    let description: String

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            imageName: "onbpage1",
            title: "Selamat datang di Beaming",
            description: "Beaming membantu teman tuli mengetahui siapa yang sedang berbicara saat percakapan."
        ),
        OnboardingPage(
            id: 1,
            imageName: "onbpage2",
            title: "Posisi HP di atas meja",
            description: "Lampu akan menunjukkan siapa yang sedang berbicara."
        )
    ]
}
