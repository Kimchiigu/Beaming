//
//  Onboardingslideview.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Generic illustrated onboarding slide, driven entirely by `OnboardingPage`
/// data. Reused for both onboarding illustration screens — no duplicate
/// view code between them.
struct OnboardingSlideView: View {
    let page: OnboardingPage

    private let imageTextSpacing: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            VStack(spacing: imageTextSpacing) {
                Image(page.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)

                VStack(alignment: .leading, spacing: 12) {
                    Text(page.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.black)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(page.description)
                        .font(.body)
                        .foregroundStyle(.black.opacity(0.65))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
            }

            Spacer()
        }
        .background(
            ZStack {
                Color.white

                Circle()
                    .fill(Color(hex: "94F2CF").opacity(0.8))
                    .frame(width: 260, height: 260)
                    .blur(radius: 60)
                    .offset(x: 120, y: -280)

                Circle()
                    .fill(Color(hex: "94F2CF").opacity(0.8))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -130, y: 300)
            }
            .ignoresSafeArea()
        )
    }
}

#Preview {
    OnboardingSlideView(page: OnboardingPage.all[0])
}
