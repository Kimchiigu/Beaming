//
//  Onboardingformview.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Third onboarding step: collects username + role via two selectable cards.
/// Purely presentational — all state and validation lives in `OnboardingViewModel`.
struct OnboardingFormView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isUsernameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Kenalan, yuk!")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.top, 12)

                TextField("Nama", text: $viewModel.username)
                    .focused($isUsernameFocused)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .overlay(Capsule().stroke(Color.black.opacity(0.08)))
                    )

                VStack(alignment: .leading, spacing: 16) {
                    Text("Pilih peranmu")
                        .font(.system(size: 17, weight: .semibold))

                    ForEach(OnboardingRole.allCases) { role in
                        CardField(
                            role: role,
                            isSelected: viewModel.selectedRole == role,
                            action: { viewModel.select(role: role) }
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

#Preview {
    OnboardingFormView(viewModel: OnboardingViewModel())
}
