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
    let mouseLocation = NSEvent.mouseLocation
    let preferredScreen = NSScreen.screens.first {
      NSMouseInRect(mouseLocation, $0.frame, false)
    }
    model.receive(urls, preferredScreenFrame: preferredScreen?.visibleFrame)
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
    Task { @MainActor in
      await Task.yield()
      guard let window = application.windows.first(where: \.canBecomeKey) else { return }

      if model.hasPendingURLs, let screenFrame = model.preferredPickerScreenFrame {
        window.orderOut(nil)
        PickerWindowPresentation.configure(window, asPicker: true)
        let contentSize = PickerWindowPresentation.size(
          browserCount: model.browsers.browsers.count
        )
        let frame = PickerWindowPresentation.centeredFrame(
          for: window,
          contentSize: contentSize,
          in: screenFrame
        )
        window.setFrame(frame, display: false)
        await Task.yield()
      }

      window.makeKeyAndOrderFront(nil)
      NSRunningApplication.current.activate(options: [.activateAllWindows])
    }
  }
}
