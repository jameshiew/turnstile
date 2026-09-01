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
    let preferredScreen =
      NSScreen.screens.first {
        NSMouseInRect(mouseLocation, $0.frame, false)
      }
      ?? NSScreen.main
      ?? NSScreen.screens.first
    let placement = preferredScreen.map {
      PickerPlacement(anchor: mouseLocation, visibleScreenFrame: $0.visibleFrame)
    }
    model.receive(urls, preferredPickerPlacement: placement)
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
    let existingWindow = application.windows.first(where: \.canBecomeKey)
    if model.hasPendingURLs {
      existingWindow?.alphaValue = 0
    }

    Task { @MainActor in
      await Task.yield()
      guard
        let window = existingWindow
          ?? application.windows.first(where: \.canBecomeKey)
      else {
        return
      }

      if model.hasPendingURLs, let placement = model.preferredPickerPlacement {
        PickerWindowPresentation.configure(window, asPicker: true)
        let contentSize = PickerWindowPresentation.size(
          browserCount: model.browsers.browsers.count
        )
        let frame = PickerWindowPresentation.anchoredFrame(
          for: window,
          contentSize: contentSize,
          browserCount: model.browsers.browsers.count,
          placement: placement
        )
        window.setFrame(frame, display: false)
        await Task.yield()
      }

      window.alphaValue = 1
      window.makeKeyAndOrderFront(nil)
      NSRunningApplication.current.activate(options: [.activateAllWindows])
    }
  }
}
