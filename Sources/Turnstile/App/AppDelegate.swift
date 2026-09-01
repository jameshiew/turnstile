import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let model: AppModel
  private var statusItem: NSStatusItem?
  private lazy var pickerWindowController = PickerWindowController(model: model)
  private var settingsWindowController: SettingsWindowController?

  override init() {
    model = AppModel(
      repository: UserDefaultsBrowserRepository(),
      workspace: SystemWorkspaceClient()
    )
    super.init()
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    model.settings.applyDockIconPreference()

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

    if Self.shouldShowSettingsOnLaunch(notification) {
      showSettings()
    }
  }

  static func shouldShowSettingsOnLaunch(_ notification: Notification) -> Bool {
    notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool == true
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

    settingsWindowController?.close()
    pickerWindowController.show(placement: model.preferredPickerPlacement)
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if model.hasPendingURLs {
      pickerWindowController.show(placement: model.preferredPickerPlacement)
    } else {
      showSettings()
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

  @objc func showSettings() {
    pickerWindowController.dismiss()
    let controller = settingsWindowController ?? SettingsWindowController(model: model)
    settingsWindowController = controller
    controller.showWindow(nil)
    controller.window?.makeKeyAndOrderFront(nil)
    NSRunningApplication.current.activate(options: [.activateAllWindows])
  }

  @objc private func showAbout() {
    NSRunningApplication.current.activate(options: [.activateAllWindows])
    NSApplication.shared.orderFrontStandardAboutPanel(nil)
  }

  @objc private func quit() {
    NSApplication.shared.terminate(nil)
  }

}
