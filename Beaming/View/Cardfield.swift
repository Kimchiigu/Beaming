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

    private let accentColor = Color(hex: "6C63A6")

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {

                // Illustration
                Image(role.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 122, height: 122)
                    .offset(x: 5, y: 12)

                // Text
                VStack(alignment: .leading, spacing: 6) {
                    Text(role.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.black)

                    Text(role.description)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.leading, 98)
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? accentColor : Color.black.opacity(0.06),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 10, y: 4)
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
