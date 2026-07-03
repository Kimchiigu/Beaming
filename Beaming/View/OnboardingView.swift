//
//  OnboardingView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var name: String = ""
    @State private var selectedRole: Role?
    @State private var showPermissionAlert: Bool = false
    @State private var permissionMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // MARK: Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hello There!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("""
Welcome to Beaming! Enter your name and select your role to get started.
""")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: Name

                    VStack(alignment: .leading, spacing: 10) {

                        Text("Name")
                            .font(.headline)
                        TextField("Enter your name", text: $name)
                            .textInputAutocapitalization(.words)
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // MARK: Role
                    VStack(alignment: .leading, spacing: 10) {

                        Text("Role")
                            .font(.headline)

                        Picker("Select your role", selection: $selectedRole) {

                            Text("Select your role")
                                .tag(nil as Role?)

                            ForEach(Role.allCases, id: \.self) { role in
                                Text(role.title)
                                    .tag(role as Role?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }

            Spacer(minLength: 0)

            Button {
                handleContinue()
            } label: {
                Text("CONTINUE")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedRole == nil)
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .foregroundColor(.white)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationBarHidden(true)
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(permissionMessage)
        }
    }
    
    // MARK: - Actions
    
    private func handleContinue() {
        guard let role = selectedRole else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Request permissions based on role
        requestPermissions(for: role) {
            // Save user and complete onboarding
            appState.saveUser(name: trimmedName, role: role)
        }
    }
    
    private func requestPermissions(for role: Role, completion: @escaping () -> Void) {
        switch role {
        case .hearing:
            // Hearing users need microphone permission
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        completion()
                    } else {
                        permissionMessage = "Microphone access is required for hearing users to detect speech. Please enable it in Settings."
                        showPermissionAlert = true
                        // Still allow proceeding — the app will work without mic
                        completion()
                    }
                }
            }
        case .deaf:
            // Deaf users only need local network (prompted automatically by iOS)
            completion()
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
}

