//
//  HomeView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: HomeViewModel?
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                homeContent(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if viewModel == nil, let user = appState.currentUser {
                let vm = HomeViewModel(currentUser: user)
                self.viewModel = vm
                vm.startDiscovery()
            } else if let vm = viewModel {
                // Returning from a meeting — reset state and restart discovery
                vm.resetAfterMeeting()
            }
        }
    }
    
    @ViewBuilder
    private func homeContent(viewModel: HomeViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // MARK: Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome,")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text(viewModel.currentUser.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    // Role picker — tap to change
                    Menu {
                        ForEach(Role.allCases, id: \.self) { role in
                            Button {
                                viewModel.changeRole(to: role, appState: appState)
                            } label: {
                                HStack {
                                    Text(role.title)
                                    if role == viewModel.currentUser.role {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.currentUser.role.title)
                                .font(.subheadline)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                        .padding(.top, 4)
                    }
                }
                
                Spacer()
                
                // Sync button
                Button {
                    viewModel.refreshRooms()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            
            // MARK: Available Rooms
            if viewModel.availableRooms.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No rooms found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Create a room or wait for others to appear.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.availableRooms) { room in
                            Button {
                                viewModel.joinRoom(room: room)
                            } label: {
                                HStack {
                                    Text(room.roomName)
                                        .font(.headline)
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.title3)
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
                    .padding(.horizontal)
                }
            }
            
            // MARK: Create Room Button
            Button(action: {
                viewModel.createRoom()
            }) {
                HStack {
                    if viewModel.isJoining {
                        ProgressView()
                            .tint(.white)
                        Text("Connecting...")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else {
                        Text("+ Create Room")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(viewModel.isJoining ? Color.gray : Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(viewModel.isJoining)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationDestination(isPresented: Binding(
            get: { viewModel.navigateToMeeting },
            set: { viewModel.navigateToMeeting = $0 }
        )) {
            if let meetingVM = viewModel.activeMeetingVM {
                MeetingView(viewModel: meetingVM)
                    .environment(appState)
            }
        }
        .alert("Room Notification", isPresented: Binding(
            get: { viewModel.showAlert },
            set: { viewModel.showAlert = $0 }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(AppState())
    }
}
