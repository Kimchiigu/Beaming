//
//  Onboardingformview.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// Third onboarding step: collects username + role.
/// Purely presentational — all state and validation lives in `OnboardingViewModel`.
struct OnboardingFormView: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var isUsernameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button {
                    withAnimation { viewModel.goToPreviousPage() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.background.secondary))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Let's get to know you 👋")
                            .font(.system(size: 28, weight: .bold))
                        Text("Tell us your name and role to personalize your experience.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Username")
                            .font(.subheadline.weight(.semibold))
                        TextField("Enter your username", text: $viewModel.username)
                            .focused($isUsernameFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(.background.secondary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Role")
                            .font(.subheadline.weight(.semibold))
                        RoleDropdownField(
                            selectedRole: viewModel.selectedRole,
                            isExpanded: $viewModel.isRolePickerExpanded,
                            onSelect: { viewModel.select(role: $0) }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
    }
}

#Preview {
    OnboardingFormView(viewModel: OnboardingViewModel())
}
