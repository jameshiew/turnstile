import AppKit
import Testing

@testable import Turnstile

@MainActor
struct ApplicationBundleTests {
  @Test
  func declaresBothWebURLSchemes() throws {
    let applicationBundle = Bundle(for: AppDelegate.self)
    let urlTypes = try #require(
      applicationBundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
    )
    let schemes = Set(
      urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    )

    #expect(schemes.isSuperset(of: ["http", "https"]))
  }

  @Test
  func staysRunningAfterItsLastWindowCloses() {
    let delegate = AppDelegate()

    #expect(!delegate.applicationShouldTerminateAfterLastWindowClosed(.shared))
  }

  @Test
  func statusMenuContainsApplicationCommands() {
    let menu = AppDelegate().makeStatusMenu()

    #expect(menu.items.count == 5)
    #expect(menu.items[0].title == "Settings…")
    #expect(menu.items[0].keyEquivalent == ",")
    #expect(menu.items[0].keyEquivalentModifierMask == [.command])
    #expect(menu.items[1].isSeparatorItem)
    #expect(menu.items[2].title == "About Turnstile")
    #expect(menu.items[3].isSeparatorItem)
    #expect(menu.items[4].title == "Quit Turnstile")
    #expect(menu.items[4].keyEquivalent == "q")
    #expect(menu.items[4].keyEquivalentModifierMask == [.command])
  }

  @Test
  func opensSettingsOnlyForADefaultLaunch() {
    let defaultLaunch = Notification(
      name: NSApplication.didFinishLaunchingNotification,
      userInfo: [NSApplication.launchIsDefaultUserInfoKey: true]
    )
    let urlLaunch = Notification(
      name: NSApplication.didFinishLaunchingNotification,
      userInfo: [NSApplication.launchIsDefaultUserInfoKey: false]
    )

    #expect(AppDelegate.shouldShowSettingsOnLaunch(defaultLaunch))
    #expect(!AppDelegate.shouldShowSettingsOnLaunch(urlLaunch))
  }
}
