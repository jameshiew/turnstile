import SwiftUI

@main
struct TurnstileApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") {
          appDelegate.showSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
      }

      CommandGroup(replacing: .newItem) {}
    }
  }
}
