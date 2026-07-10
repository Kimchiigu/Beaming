//
//  Onboardingview.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// The 3-step onboarding flow (Welcome → Phone position → Profile form).
/// Shown only on first launch — see `AppState.hasCompletedOnboarding`.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = OnboardingViewModel()

    /// Used for the profile form page, which has no OnboardingPage entry.
    private let formAccentColor = Color(hex: "6C63A6")

    private var currentAccentColor: Color {
        if viewModel.currentPage < OnboardingPage.all.count {
            return OnboardingPage.all[viewModel.currentPage].accentColor
        }
        return formAccentColor
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $viewModel.currentPage) {
                ForEach(OnboardingPage.all) { page in
                    OnboardingSlideView(page: page)
                        .tag(page.id)
                }

                OnboardingFormView(viewModel: viewModel)
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentPage)
            .ignoresSafeArea()

            bottomControls
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 16) {
            OnboardingPageIndicator(
                numberOfPages: viewModel.totalPages,
                currentPage: viewModel.currentPage,
                activeColor: currentAccentColor
            )

            Button {
                if viewModel.isLastPage {
                    viewModel.completeOnboarding(appState: appState)
                } else {
                    withAnimation {
                        viewModel.goToNextPage()
                    }
                }
            } label: {
                Text(viewModel.isLastPage ? "Mulai" : "Selanjutnya")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .background(currentAccentColor, in: Capsule())
            .disabled(viewModel.isLastPage && !viewModel.isFormValid)
            .opacity(
                viewModel.isLastPage && !viewModel.isFormValid
                ? 0.5
                : 1
            )
            .animation(
                .easeInOut(duration: 0.15),
                value: viewModel.isFormValid
            )
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
