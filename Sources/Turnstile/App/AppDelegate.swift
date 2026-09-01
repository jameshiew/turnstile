import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model: AppModel
  private var statusItem: NSStatusItem?
  private lazy var pickerWindowController = PickerWindowController(model: model)

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
    guard model.hasPendingURLs else { return }

    Task { @MainActor in
      await Task.yield()
      settingsWindow(in: application)?.orderOut(nil)
      await Task.yield()
      pickerWindowController.show(placement: model.preferredPickerPlacement)
    }
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if model.hasPendingURLs {
      pickerWindowController.show(placement: model.preferredPickerPlacement)
    } else {
      bringSettingsWindowForward(in: sender)
    }
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
    pickerWindowController.dismiss()
    bringSettingsWindowForward(in: NSApplication.shared)
  }

  @objc private func showAbout() {
    NSRunningApplication.current.activate(options: [.activateAllWindows])
    NSApplication.shared.orderFrontStandardAboutPanel(nil)
  }

  @objc private func quit() {
    NSApplication.shared.terminate(nil)
  }

  private func bringSettingsWindowForward(in application: NSApplication) {
    let existingWindow = settingsWindow(in: application)
    Task { @MainActor in
      await Task.yield()
      guard
        let window = existingWindow
          ?? settingsWindow(in: application)
      else {
        return
      }

      window.makeKeyAndOrderFront(nil)
      NSRunningApplication.current.activate(options: [.activateAllWindows])
    }
  }

  private func settingsWindow(in application: NSApplication) -> NSWindow? {
    application.windows.first {
      $0.identifier == PickerWindowPresentation.settingsWindowIdentifier
    }
      ?? application.windows.first {
        $0.identifier != PickerWindowPresentation.pickerWindowIdentifier
          && $0.canBecomeKey
          && $0.title == "Turnstile"
      }
  }
}
