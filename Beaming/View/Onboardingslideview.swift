//
//  Onboardingslideview.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Generic illustrated onboarding slide, driven entirely by `OnboardingPage`
/// data. Reused for both the "Welcome" and "Privacy" screens — no duplicate
/// view code between them.
struct OnboardingSlideView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(page.iconTint.opacity(0.12))
                        .frame(width: 220, height: 220)
                    Image(systemName: page.systemImage)
                        .font(.system(size: 84, weight: .medium))
                        .foregroundStyle(page.iconTint.gradient)
                }
                Spacer()
            }

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                (Text(page.titleLine1 + "\n").foregroundStyle(.primary)
                    + Text(page.titleLine2).foregroundStyle(page.titleLine2Color))
                    .font(.system(size: 30, weight: .bold))

                Text(page.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    OnboardingSlideView(page: OnboardingPage.all[0])
}
