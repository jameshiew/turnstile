import AppKit
import Testing

@testable import Turnstile

@MainActor
struct ApplicationBundleTests {
  @Test
  func declaresBothWebURLSchemes() throws {
    let applicationInfo = try applicationInfo()
    let urlTypes = try #require(
      applicationInfo["CFBundleURLTypes"] as? [[String: Any]]
    )
    let schemes = Set(
      urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    )

    #expect(schemes.isSuperset(of: ["http", "https"]))
  }

  @Test
  func declaresHTMLDocumentsForOpeningFromFinderAndCLI() throws {
    let applicationInfo = try applicationInfo()
    let documentTypes = try #require(applicationInfo["CFBundleDocumentTypes"] as? [[String: Any]])
    let htmlType = try #require(
      documentTypes.first {
        ($0["LSItemContentTypes"] as? [String])?.contains("public.html") == true
      }
    )

    #expect(htmlType["CFBundleTypeRole"] as? String == "Viewer")
    #expect(htmlType["LSHandlerRank"] as? String == "Alternate")
  }

  @Test
  func launchesWithoutADockIcon() throws {
    let applicationInfo = try applicationInfo()

    #expect(applicationInfo["LSUIElement"] as? Bool == true)
  }

  @Test
  func declaresConcreteBundleIdentity() throws {
    let applicationInfo = try applicationInfo()

    #expect(applicationInfo["CFBundleExecutable"] as? String == "Turnstile")
    #expect(applicationInfo["CFBundleIdentifier"] as? String == "net.hiew.turnstile")
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

  private func applicationInfo() throws -> [String: Any] {
    let packageRoot = URL(filePath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let infoURL =
      packageRoot
      .appending(path: "Sources/Turnstile/Resources/ApplicationInfo.plist")
    let data = try Data(contentsOf: infoURL)
    let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)

    return try #require(propertyList as? [String: Any])
  }
}
