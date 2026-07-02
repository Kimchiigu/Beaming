//
//  RoomCardView.swift
//  Beaming
//
//  Created by Axel Nino Nakata on 02/07/26.
//

import SwiftUI

struct RoomCardView: View {
    let room: Room
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(room.name)
                    .font(.headline)
                    .foregroundColor(.black)
                
                Spacer()
                
                Text("\(room.capacity) / 8")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    let mockHost = User(name: "Axel", role: .deaf)
    let mockGuest = User(name: "Jesslyn", role: .hearing)
    
    let mockRoom = Room(
        id: UUID(),
        isHost: mockHost,
        guests: [mockGuest]
    )
    
    RoomCardView(room: mockRoom) {
    }
}
