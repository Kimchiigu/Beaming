//
//  HomeView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            Text("Welcome,\n\(viewModel.currentUser.name)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.horizontal)
                .padding(.top, 20)
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.availableRooms) { room in
                        RoomCardView(room: room) {
                            viewModel.joinRoom(room: room)
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Button(action: {
                viewModel.createRoom()
            }) {
                Text("+ Create room")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.black, lineWidth: 2)
                    )
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        
        .onAppear {
            viewModel.loadDummyData()
        }
        .alert("Room Notification", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

#Preview {
    HomeView()
}
