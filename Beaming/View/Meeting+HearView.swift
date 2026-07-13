//
//  Meeting+HearView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 12/07/26.
//

import SwiftUI

/// Shown to a hearing ("Teman Dengar") participant: the phone goes face-down and its
/// flashlight blinks when they speak. No transcript, no app bar.
struct Meeting_HearView: View {
    var body: some View {
        ZStack {
            Image("MeetingHearBackground")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()

            VStack {
                Spacer()

                Text("Letakkan HP Anda dengan")
                Text("layar menghadap ke bawah")
                    .bold()
                    .padding(.bottom, 24)

                Text("Flashlight akan berkedip saat")
                    .bold()
                Text("Anda berbicara")
            }
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    Meeting_HearView()
}
