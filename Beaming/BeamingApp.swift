//
//  BeamingApp.swift
//  Beaming
//
//  Created by Christopher Hardy Gunawan on 02/07/26.
//

import SwiftUI

@main
struct BeamingApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    NotificationCenter.default.post(
                        name: .appClipJoinURL,
                        object: nil,
                        userInfo: ["url": url]
                    )
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        NotificationCenter.default.post(
                            name: .appClipJoinURL,
                            object: nil,
                            userInfo: ["url": url]
                        )
                    }
                }
        }
    }
}

extension Notification.Name {
    static let appClipJoinURL = Notification.Name("appClipJoinURL")
}
