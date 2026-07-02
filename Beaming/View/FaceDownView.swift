//
//  FaceDownView.swift
//  Beaming
//
//  Created by Beaming Team on 02/07/26.
//

import SwiftUI

/// Full-screen locked overlay shown when a hearing user's phone is face-down.
/// Prevents accidental touches during an active meeting.
struct FaceDownView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Meeting Active")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your phone is face-down.\nFlip it over to access controls.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview {
    FaceDownView()
}
