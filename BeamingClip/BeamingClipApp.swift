//
//  BeamingClipApp.swift
//  BeamingClip
//
//  Created by Axel Nino Nakata on 10/07/26.
//

import SwiftUI

@main
struct BeamingClipApp: App {
    @State private var appState = AppState()
    @State private var invocationURL: URL?

    var body: some Scene {
        WindowGroup {
            AppClipJoinView(invocationURL: $invocationURL)
                .environment(appState)
                .preferredColorScheme(.light)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    invocationURL = url
                }
        }
    }
}
