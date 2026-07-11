//
//  Onboardingslideview.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Generic illustrated onboarding slide, driven entirely by `OnboardingPage`
/// data. Reused for both onboarding illustration screens — the background
/// treatment switches based on `page.backgroundStyle`.
struct OnboardingSlideView: View {
    let page: OnboardingPage

    var body: some View {
        ZStack {
            backgroundLayer
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                switch page.backgroundStyle {
                case .illustrationBleed:
                    bleedImage

                case .softBlobs:
                    bleedImage
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(page.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)

                    Text(page.description)
                        .font(.body)
                        .foregroundStyle(.black.opacity(0.65))
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 150)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .top)
    }

    /// Full-width image bled to the top edge.
    private var bleedImage: some View {
        Image(page.imageName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(edges: .top)
    }

    /// Kept for compatibility if another style needs centered image later.
    private var centeredImage: some View {
        Image(page.imageName)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 260)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch page.backgroundStyle {
        case .illustrationBleed:
            Color.white

        case .softBlobs:
            Color.white
        }
    }
}

extension OnboardingBackgroundStyle: Equatable {}

#Preview {
    OnboardingSlideView(page: OnboardingPage.all[1])
}
