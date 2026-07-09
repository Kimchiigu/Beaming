//
//  Onboardingpageindicator.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Reusable dot page indicator. The active dot is tinted with the current
/// page's accent color; inactive dots stay neutral gray — matches the
/// design where the active dot color changes per onboarding step.
struct OnboardingPageIndicator: View {
    let numberOfPages: Int
    let currentPage: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? activeColor : Color(.systemGray4))
                    .frame(width: index == currentPage ? 20 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }
}

#Preview {
    OnboardingPageIndicator(numberOfPages: 3, currentPage: 1, activeColor: .green)
}
