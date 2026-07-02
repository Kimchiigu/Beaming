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
            if appState.hasOnboarded, appState.currentUser != nil {
                HomeView()
                    .environment(appState)
            } else {
                OnboardingView()
                    .environment(appState)
            }
        }
    }
}

#Preview {
    ContentView()
}
