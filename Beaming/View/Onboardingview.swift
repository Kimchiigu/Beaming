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

    private let brandGreen = Color(hex: "1F6E4C")

    var body: some View {
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

        .ignoresSafeArea()

        .overlay(alignment: .bottom) {

            VStack(spacing: 16) {

                OnboardingPageIndicator(

                    numberOfPages: viewModel.totalPages,

                    currentPage: viewModel.currentPage,

                    activeColor: brandGreen

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

                    Text(viewModel.isLastPage ? "Continue" : "Selanjutnya")

                        .font(.headline.weight(.semibold))

                        .foregroundStyle(.white)

                        .frame(maxWidth: .infinity)

                        .padding(.vertical, 16)

                }

                .background(brandGreen, in: Capsule())

            }

            .padding(.horizontal, 24)

            .padding(.bottom, 24)

        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}
