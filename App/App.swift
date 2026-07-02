import SwiftUI
import UserNotifications

@main
struct TwallApp: App {
    @State private var appState = AppState()
    @State private var showSettings = !AppState.hasCredentials

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                        .environment(appState)
                }
                .onAppear {
                    Task {
                        try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    }
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}
