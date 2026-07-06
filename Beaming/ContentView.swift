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
            HomeView()
                .environment(appState)
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
