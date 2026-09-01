import SwiftUI

@main
struct TurnstileApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup("Turnstile") {
      RootView(model: appDelegate.model)
    }
    .defaultSize(width: 560, height: 480)
    .windowResizability(.contentMinSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
    }
  }
}
