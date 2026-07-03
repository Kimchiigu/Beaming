//
//  MeetingView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

struct MeetingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State var viewModel: MeetingViewModel
    
    var body: some View {
        ZStack {
            // Main meeting content
            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.room.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if viewModel.isHost {
                            Text("Host")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(viewModel.room.participantCount)/8")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: Participants List
                List {
                    ForEach(viewModel.room.participants) { participant in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(participant.name)
                                        .font(.body)
                                        .fontWeight(participant.id == viewModel.room.hostID ? .semibold : .regular)
                                    
                                    if participant.id == viewModel.room.hostID {
                                        Text("HOST")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.black)
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Text(participant.role.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Speaker indicator
                            if viewModel.room.isSpeaker == participant.id {
                                Image(systemName: "waveform.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.plain)
                .padding(.bottom, 8)
                
                // MARK: Controls
                controlsSection
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            
            // MARK: Calibration Overlay (Hearing users, before meeting starts)
            if viewModel.showCalibration {
                CalibrationView(viewModel: viewModel)
            }
            // MARK: Face-Down Overlay (Hearing users only, after calibration)
            else if viewModel.isFaceDown && viewModel.localUser.role == .hearing {
                FaceDownView()
            }
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
        .alert("Meeting", isPresented: $viewModel.showAlert) {
            Button("OK", role: .cancel) {
                if viewModel.shouldDismiss {
                    dismiss()
                }
            }
        } message: {
            Text(viewModel.alertMessage)
        }
    }
    
    // MARK: - Controls Section (Role-Based)
    
    @ViewBuilder
    private var controlsSection: some View {
        HStack(spacing: 16) {
            Spacer()
            
            // End Room button (Host only)
            if viewModel.isHost {
                Button {
                    viewModel.endRoom()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.red)
                            .clipShape(Circle())
                        
                        Text("End")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Mic toggle (Hearing users only)
            if viewModel.localUser.role == .hearing {
                Button {
                    viewModel.toggleMute()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: viewModel.isMuted ? "mic.slash.fill" : "mic.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 72, height: 72)
                            .background(viewModel.isMuted ? Color.gray : Color.black)
                            .clipShape(Circle())
                        
                        Text(viewModel.isMuted ? "Unmute" : "Mute")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Leave Room button (Everyone)
            Button {
                viewModel.leaveRoom()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "door.left.hand.open")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                        .frame(width: 56, height: 56)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                    
                    Text("Leave")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

#Preview {
    let user = User(name: "Preview User", role: .hearing)
    let networkManager = NetworkManager()
    let vm = MeetingViewModel(localUser: user, networkManager: networkManager, asHost: true)
    
    NavigationStack {
        MeetingView(viewModel: vm)
            .environment(AppState())
    }
}
