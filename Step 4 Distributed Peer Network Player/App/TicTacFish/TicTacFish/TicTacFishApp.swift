/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Entry point for the iOS app.
*/

import SwiftUI
import Native
import OpenAPIURLSession

@main
struct TicTacFishApp: App {
    var body: some Scene {
        WindowGroup {
            MainMenuView(
                client: .init(
                    serverURL: URL(string: "http://localhost:8080")!,
                    transport: URLSessionTransport()
                )
            )
        }
    }
}

