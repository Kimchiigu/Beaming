//
//  ContentView.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                NavigationStack {
                    HomeView()
                }
            } else {
                OnboardingView()
            }
        }
        .environment(appState)
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
