import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model: AppModel

  override init() {
    model = AppModel(
      repository: UserDefaultsBrowserRepository(),
      workspace: SystemWorkspaceClient()
    )
    super.init()
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    model.receive(urls)
    bringWindowForward(in: application)
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    bringWindowForward(in: sender)
    return true
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  private func bringWindowForward(in application: NSApplication) {
    NSRunningApplication.current.activate(options: [.activateAllWindows])

    Task { @MainActor in
      await Task.yield()
      application.windows.first(where: \.canBecomeKey)?.makeKeyAndOrderFront(nil)
    }
  }
}
