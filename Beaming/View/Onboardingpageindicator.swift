//
//  Onboardingpageindicator.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Reusable dot page indicator. The active dot is filled with the brand
/// green; inactive dots use a soft mint tint to match the design.
struct OnboardingPageIndicator: View {
    let numberOfPages: Int
    let currentPage: Int
    let activeColor: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? activeColor : Color(hex: "715DD1"))
                    .frame(width: index == currentPage ? 20 : 7, height: 7)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentPage)
    }
}

#Preview {
    OnboardingPageIndicator(numberOfPages: 4, currentPage: 0, activeColor: Color(hex: "715DD1"))
}
