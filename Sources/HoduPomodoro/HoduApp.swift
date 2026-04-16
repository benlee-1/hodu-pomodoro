import SwiftUI

@main
struct HoduApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Hodu Pomodoro 🍊") {
            ContentView()
                .environmentObject(state)
                .frame(minWidth: 520, minHeight: 420)
        }
        .windowResizability(.contentMinSize)
    }
}
