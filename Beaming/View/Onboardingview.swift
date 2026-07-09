//
//  Onboardingview.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// The 3-step onboarding flow (Welcome → Privacy → Profile form).
/// Shown only on first launch — see `AppState.hasCompletedOnboarding`.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $viewModel.currentPage) {
                ForEach(OnboardingPage.all) { page in
                    OnboardingSlideView(page: page)
                        .tag(page.id)
                }

                OnboardingFormView(viewModel: viewModel)
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: viewModel.currentPage)

            OnboardingPageIndicator(
                numberOfPages: viewModel.totalPages,
                currentPage: viewModel.currentPage,
                activeColor: currentAccentColor
            )
            .padding(.bottom, 12)

            if viewModel.isLastPage {
                Button {
                    viewModel.completeOnboarding(appState: appState)
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .disabled(!viewModel.isFormValid)
                .opacity(viewModel.isFormValid ? 1 : 0.5)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .animation(.easeInOut(duration: 0.15), value: viewModel.isFormValid)
            }
        }
        .background(Color(.systemBackground))
    }

    /// Drives the active dot color: blue on the welcome slide, green on the
    /// privacy slide, purple on the profile form — matches the design.
    private var currentAccentColor: Color {
        if viewModel.currentPage < OnboardingPage.all.count {
            return OnboardingPage.all[viewModel.currentPage].accentColor
        }
        return .purple
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
