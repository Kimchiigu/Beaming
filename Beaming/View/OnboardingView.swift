//
//  OnboardingView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

struct OnboardingView: View {
    @State private var name: String = ""
    @State private var selectedRole: Role?

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
Lorem ipsum dolor sit amet, consectetur adipiscing elit.
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

            } label: {
                Text("CONTINUE")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .disabled(name.isEmpty || selectedRole == nil)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    OnboardingView()
}

