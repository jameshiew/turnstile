import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model: AppModel
  private var statusItem: NSStatusItem?

  override init() {
    model = AppModel(
      repository: UserDefaultsBrowserRepository(),
      workspace: SystemWorkspaceClient()
    )
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = statusItem.button {
      let image = NSImage(
        systemSymbolName: "arrow.triangle.branch",
        accessibilityDescription: "Turnstile"
      )
      image?.isTemplate = true
      button.image = image
      button.imagePosition = .imageOnly
      button.toolTip = "Turnstile"
    }
    statusItem.menu = makeStatusMenu()
    self.statusItem = statusItem
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
    false
  }

  func makeStatusMenu() -> NSMenu {
    let menu = NSMenu()

    let settingsItem = NSMenuItem(
      title: "Settings…",
      action: #selector(showSettings),
      keyEquivalent: ","
    )
    settingsItem.target = self
    settingsItem.keyEquivalentModifierMask = [.command]
    menu.addItem(settingsItem)

    menu.addItem(.separator())

    let aboutItem = NSMenuItem(
      title: "About Turnstile",
      action: #selector(showAbout),
      keyEquivalent: ""
    )
    aboutItem.target = self
    menu.addItem(aboutItem)

    menu.addItem(.separator())

    let quitItem = NSMenuItem(
      title: "Quit Turnstile",
      action: #selector(quit),
      keyEquivalent: "q"
    )
    quitItem.target = self
    quitItem.keyEquivalentModifierMask = [.command]
    menu.addItem(quitItem)

    return menu
  }

  @objc private func showSettings() {
    bringWindowForward(in: NSApplication.shared)
  }

  @objc private func showAbout() {
    NSRunningApplication.current.activate(options: [.activateAllWindows])
    NSApplication.shared.orderFrontStandardAboutPanel(nil)
  }

  @objc private func quit() {
    NSApplication.shared.terminate(nil)
  }

  private func bringWindowForward(in application: NSApplication) {
    let existingWindow =
      application.windows.first {
        $0.identifier == PickerWindowPresentation.windowIdentifier
      }
      ?? application.windows.first(where: \.canBecomeKey)
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
