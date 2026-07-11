//
//  Onboardingpage.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// How a slide's background should render.
/// - `illustrationBleed`: the asset image itself already contains its own
///   gradient + fade, so it's placed full-bleed at the top with a plain
///   white page underneath (used for page 1).
/// - `softBlobs`: plain white background with soft blurred color blobs in
///   the corners, and a smaller centered illustration (used for page 2).
enum OnboardingBackgroundStyle {
    case illustrationBleed
    case softBlobs
}

/// Static content for the illustrated onboarding slides.
/// Only the first two onboarding screens use this — the third screen is an
/// interactive form and lives in its own view (`OnboardingFormView`).
struct OnboardingPage: Identifiable {
    let id: Int
    let imageName: String
    let title: String
    let description: String
    let backgroundStyle: OnboardingBackgroundStyle
    let accentColor: Color

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            imageName: "onbpage1",
            title: "Selamat datang di Beaming",
            description: "Beaming membantu teman tuli mengetahui siapa yang sedang berbicara.",
            backgroundStyle: .illustrationBleed,
            accentColor: Color(hex: "6C63A6")
        ),
        OnboardingPage(
            id: 1,
            imageName: "onbpage2",
            title: "Flashlight menyala saat berbicara",
            description: "Lampu di HP akan berkedip untuk menunjukkan siapa yang sedang berbicara.",
            backgroundStyle: .illustrationBleed,
            accentColor: Color(hex: "6C63A6")
        ),
        OnboardingPage(
            id: 2,
            imageName: "onbpage3",
            title: "Transkrip muncul di layar HP",
            description: "Obrolan akan berubah menjadi teks agar lebih mudah diikuti teman tuli.",
            backgroundStyle: .illustrationBleed,
            accentColor: Color(hex: "6C63A6")
        )
    ]
}
