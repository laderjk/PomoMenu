import SwiftUI

@main
struct PomoMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(engine: appDelegate.engine)
        }
    }
}
