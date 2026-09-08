import Foundation
import Testing

@testable import Turnstile

@MainActor
struct WorkspaceClientTests {
  @Test
  func launchesProfileURLsAsArgumentsInANewInstance() throws {
    let supportURL = URL(filePath: "/tmp/Turnstile test support")
    let workspace = SystemWorkspaceClient(
      profileStore: ChromeProfileStore(applicationSupportURL: supportURL)
    )
    let browser = makeBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
      .withProfile(ChromeProfile(directory: "Profile 1", name: "Work"))
    let webURL = try #require(URL(string: "https://example.com/?query=a%20b&next=work#test"))
    let file = URL(filePath: "/tmp/local page #1 %.html")

    let configuration = workspace.openConfiguration(for: browser, urls: [webURL, file])

    #expect(configuration.createsNewApplicationInstance)
    #expect(configuration.activates)
    #expect(!configuration.addsToRecentItems)
    #expect(
      configuration.arguments == [
        "--user-data-dir=/tmp/Turnstile test support/Google/Chrome",
        "--profile-directory=Profile 1",
        webURL.absoluteString,
        file.absoluteString,
      ])
  }

  @Test
  func reusesTheRunningInstanceForOrdinaryBrowsers() {
    let configuration = SystemWorkspaceClient().openConfiguration(
      for: makeBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome"),
      urls: [URL(filePath: "/tmp/local.html")]
    )

    #expect(!configuration.createsNewApplicationInstance)
    #expect(configuration.arguments.isEmpty)
  }

  @Test
  func refusesToOpenAMissingProfileBeforeLaunchingChrome() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let applicationURL = root.appending(path: "Chrome.app")
    let contents = applicationURL.appending(path: "Contents")
    try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let info = [
      "CFBundleIdentifier": "com.google.Chrome",
      "CFBundleName": "Chrome",
      "CFBundlePackageType": "APPL",
    ]
    try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
      .write(to: contents.appending(path: "Info.plist"))
    let browser = Browser(
      bundleIdentifier: "com.google.Chrome",
      displayName: "Chrome",
      applicationURL: applicationURL,
      profile: ChromeProfile(directory: "Default", name: "Personal")
    )
    let workspace = SystemWorkspaceClient(
      profileStore: ChromeProfileStore(applicationSupportURL: root)
    )

    #expect(!workspace.isAvailable(browser))
    await #expect(throws: WorkspaceClientError.profileNotFound(browser.destinationName)) {
      try await workspace.open([URL(filePath: "/tmp/test.html")], in: browser)
    }
  }

  @Test
  func acceptsLocalHTMLFilesWhenResolvingTheDestination() async {
    let browser = makeBrowser(
      name: "Missing",
      bundleIdentifier: "test.turnstile.missing.\(UUID().uuidString)"
    )
    let workspace = SystemWorkspaceClient()
    let file = URL(filePath: "/tmp/local page #1 %.html")

    await #expect(throws: WorkspaceClientError.applicationNotFound(browser.displayName)) {
      try await workspace.open([file], in: browser)
    }
  }

  @Test
  func rejectsUnsupportedSchemesBeforeOpeningABrowser() async throws {
    let workspace = SystemWorkspaceClient()
    let file = URL(filePath: "/tmp/some.html")
    let unsupported = try #require(URL(string: "mailto:someone@example.com"))

    await #expect(throws: WorkspaceClientError.invalidURL) {
      try await workspace.open([file, unsupported], in: makeBrowser(name: "Safari"))
    }
  }
}
