//
//  Roledropdownfield.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

/// A single selectable role card: illustration + title + description.
/// Tapping it directly selects the role — replaces the old dropdown since
/// the new design shows both roles as full cards at once.
struct CardField: View {
    let role: OnboardingRole
    let isSelected: Bool
    let action: () -> Void

    private let accentColor = Color(hex: "6C63A6")

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(role.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)

                Text(role.displayName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)

                Text(role.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? accentColor : Color.black.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        CardField(role: .temanTuli, isSelected: true) {}
        CardField(role: .temanDengar, isSelected: false) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
