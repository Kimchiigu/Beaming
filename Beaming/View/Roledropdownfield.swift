//
//  Roledropdownfield.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// A custom inline dropdown (rather than a system Picker) so the expanded
/// list can show each role's colored icon exactly as designed.
struct RoleDropdownField: View {
    let selectedRole: OnboardingRole?
    @Binding var isExpanded: Bool
    let onSelect: (OnboardingRole) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(selectedRole?.displayName ?? "Select your role")
                        .foregroundStyle(selectedRole == nil ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.background.secondary)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 2) {
                    ForEach(OnboardingRole.allCases) { role in
                        Button {
                            onSelect(role)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(role.tintColor.opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: role.iconName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(role.tintColor)
                                }
                                Text(role.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.background.secondary)
                )
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

#Preview {
    @Previewable @State var isExpanded = true
    return RoleDropdownField(selectedRole: nil, isExpanded: $isExpanded) { _ in }
        .padding()
}
