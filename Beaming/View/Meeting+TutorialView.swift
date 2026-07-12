//
//  Meeting+TutorialView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 11/07/26.
//

import SwiftUI

/// One of the two tabs shown to a deaf ("Teman Tuli") participant: a short explainer
/// that the phone's light turns on when someone speaks.
struct Meeting_TutorialView: View {
    var body: some View {
        ZStack {
            Image("TutorialBackground")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()

            VStack {
                Text("Lampu HP akan **menyala**\nketika orang berbicara")
                    .multilineTextAlignment(.center)
                    .padding(.top, 64)

                Spacer()
            }
        }
    }
}

/// Reusable glass dropdown list — used by MeetingView for the participants popover.
struct DropdownMenuList: View {
    let names: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(names, id: \.self) { name in
                        Text(name)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundStyle(.black.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 28)
            }
        }
        .frame(width: 180, height: 320)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 15, x: 0, y: 10)
    }
}

#Preview {
    Meeting_TutorialView()
}
