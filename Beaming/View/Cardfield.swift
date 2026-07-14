//
//  Roledropdownfield.swift
//  Beaming
//
//  Created by Muhammad Fadhil Abidin on 09/07/26.
//

import SwiftUI

struct CardField: View {
    let role: OnboardingRole
    let isSelected: Bool
    let hasSelection: Bool
    let action: () -> Void

    private let accentColor = Color(hex: "715DD1")

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {

                // Illustration
                Image(role.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 122, height: 122)
                    .offset(x: 15, y: 16)

                // Text
                VStack(alignment: .leading, spacing: 5) {
                    Text(role.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .black)

                    Text(role.description)
                        .font(.system(size: 15))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.9) : .secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 115)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? accentColor : .white))
            .shadow(
                color: .black.opacity(0.05),
                radius: 10,
                y: 4
            )
            .grayscale(hasSelection && !isSelected ? 1 : 0)
            .opacity(hasSelection && !isSelected ? 0.7 : 1)
            .animation(.easeInOut(duration: 0.2), value: hasSelection)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        CardField(
            role: .temanTuli,
            isSelected: true,
            hasSelection: true
        ) {}

        CardField(
            role: .temanDengar,
            isSelected: false,
            hasSelection: true
        ) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
