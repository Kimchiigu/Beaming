//
//  Onboardingviewmodel.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import Foundation
import Observation

/// Drives the entire onboarding flow: page navigation + the "get to know
/// you" form. Views stay dumb — all validation and persistence logic lives
/// here, per MVVM.
@Observable
final class OnboardingViewModel {

    /// 0 and 1 are the illustrated slides, 2 is the profile form.
    var currentPage: Int = 0
    let totalPages = 3

    var username: String = ""
    var selectedRole: OnboardingRole?
    var isRolePickerExpanded: Bool = false

    /// Continue button on the last page is disabled until both fields are filled.
    var isFormValid: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedRole != nil
    }

    var isLastPage: Bool {
        currentPage == totalPages - 1
    }

    func goToPreviousPage() {
        guard currentPage > 0 else { return }
        currentPage -= 1
    }

    func goToNextPage() {
        guard currentPage < totalPages - 1 else { return }
        currentPage += 1
    }

    func select(role: OnboardingRole) {
        selectedRole = role
        isRolePickerExpanded = false
    }

    /// Persists the collected profile into `AppState`, which marks
    /// onboarding as completed for all future launches.
    func completeOnboarding(appState: AppState) {
        guard isFormValid, let selectedRole else { return }
        appState.completeOnboarding(
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            role: selectedRole
        )
    }
}
