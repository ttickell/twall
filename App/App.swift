import SwiftUI
import UserNotifications

@main
struct TwallApp: App {
    @State private var appState = AppState()
    @State private var showOnboarding = !AppState.hasCredentials

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView()
                        .environment(appState)
                }
                .onAppear {
                    Task {
                        try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                    }
                }
        }
        .defaultSize(width: 900, height: 600)
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
