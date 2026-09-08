import Foundation
import Testing

@testable import Turnstile

struct ChromeProfileStoreTests {
  @Test
  func discoversNamedProfilesAndSkipsMissingOrInvalidEntries() throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let state: [String: Any] = [
      "profile": [
        "info_cache": [
          "Default": ["name": "Personal"],
          "Profile 1": ["name": "Work"],
          "Profile 2": ["name": "  "],
          "Profile 3": ["name": "Work"],
          "Missing": ["name": "Deleted"],
          "Guest Profile": ["name": "Guest"],
          "System Profile": ["name": "System"],
          "Omitted": ["name": "Hidden", "is_omitted": true],
          "Ephemeral": ["name": "Temporary", "is_ephemeral": true],
          "../Escape": ["name": "Escape"],
          "Malformed": "invalid",
        ] as [String: Any]
      ]
    ]
    try JSONSerialization.data(withJSONObject: state).write(to: fixture.stateURL)
    for directory in [
      "Default", "Profile 1", "Profile 2", "Profile 3", "Guest Profile", "System Profile",
      "Omitted", "Ephemeral",
    ] {
      try FileManager.default.createDirectory(
        at: fixture.dataURL.appending(path: directory), withIntermediateDirectories: true
      )
    }

    let profiles = try fixture.store.profiles(for: fixture.browser)

    #expect(
      profiles.compactMap(\.profile) == [
        ChromeProfile(directory: "Default", name: "Personal"),
        ChromeProfile(directory: "Profile 2", name: "Profile 2"),
        ChromeProfile(directory: "Profile 1", name: "Work"),
        ChromeProfile(directory: "Profile 3", name: "Work"),
      ])
    #expect(profiles.allSatisfy { $0.applicationURL == fixture.browser.applicationURL })
  }

  @Test
  func returnsNoProfilesBeforeChromeHasCreatedLocalState() throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }

    #expect(try fixture.store.profiles(for: fixture.browser).isEmpty)
    #expect(try fixture.store.profiles(for: makeBrowser(name: "Safari")).isEmpty)
  }

  @Test(arguments: ["not JSON", "[]"])
  func reportsMalformedLocalState(contents: String) throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    try Data(contents.utf8).write(to: fixture.stateURL)

    #expect(throws: (any Error).self) { try fixture.store.profiles(for: fixture.browser) }
  }

  @Test
  func treatsMissingDirectoriesAndRegularFilesAsUnavailableProfiles() throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let browser = fixture.browser.withProfile(ChromeProfile(directory: "Default", name: "Personal"))

    #expect(!fixture.store.isAvailable(browser))
    try Data().write(to: fixture.dataURL.appending(path: "Default"))
    #expect(!fixture.store.isAvailable(browser))
    #expect(fixture.store.isAvailable(fixture.browser))
  }

  @Test
  func keepsChromeChannelsInTheirOwnDataDirectories() throws {
    let fixture = try makeFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    let beta = makeBrowser(name: "Chrome Beta", bundleIdentifier: "com.google.Chrome.beta")
    let profile = ChromeProfile(directory: "Default", name: "Personal")
    try FileManager.default.createDirectory(
      at: fixture.dataURL.appending(path: "Default"), withIntermediateDirectories: true
    )

    #expect(fixture.store.isAvailable(fixture.browser.withProfile(profile)))
    #expect(!fixture.store.isAvailable(beta.withProfile(profile)))
  }

  private func makeFixture() throws -> Fixture {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let browser = makeBrowser(name: "Chrome", bundleIdentifier: "com.google.Chrome")
    let store = ChromeProfileStore(applicationSupportURL: root)
    let dataURL = try #require(store.dataDirectory(for: browser))
    try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
    return Fixture(root: root, dataURL: dataURL, browser: browser, store: store)
  }

  private struct Fixture {
    let root: URL
    let dataURL: URL
    let browser: Browser
    let store: ChromeProfileStore
    var stateURL: URL { dataURL.appending(path: "Local State") }
  }
}
