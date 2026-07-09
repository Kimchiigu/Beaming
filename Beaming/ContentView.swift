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
        NavigationStack {
            Group {
                if appState.hasCompletedOnboarding {
                    HomeView()
                } else {
                    OnboardingView()
                }
            }
            .environment(appState)
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
