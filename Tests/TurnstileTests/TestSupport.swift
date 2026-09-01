import AppKit
import Foundation

@testable import Turnstile

func makeBrowser(
  name: String,
  bundleIdentifier: String? = nil
) -> Browser {
  Browser(
    bundleIdentifier: bundleIdentifier ?? "test.\(name.lowercased())",
    displayName: name,
    applicationURL: URL(filePath: "/Applications/\(name).app")
  )
}

enum TestFailure: Error {
  case expected
}

@MainActor
final class InMemoryBrowserRepository: BrowserRepository {
  var storedBrowsers: [Browser]
  var loadError: (any Error)?
  var saveError: (any Error)?

  init(browsers: [Browser] = []) {
    storedBrowsers = browsers
  }

  func load() throws -> [Browser] {
    if let loadError {
      throw loadError
    }
    return storedBrowsers
  }

  func save(_ browsers: [Browser]) throws {
    if let saveError {
      throw saveError
    }
    storedBrowsers = browsers
  }
}

@MainActor
final class WorkspaceClientSpy: WorkspaceClient {
  var chosenApplicationURL: URL?
  var inspectedBrowser = makeBrowser(name: "Selected")
  var openedURLs: [URL] = []
  var openedBrowser: Browser?
  var openError: (any Error)?
  var defaultBrowser = false
  var makeDefaultError: (any Error)?
  var availableBrowserIDs = Set<Browser.ID>()

  func chooseBrowser() async -> URL? {
    chosenApplicationURL
  }

  func browser(at applicationURL: URL) throws -> Browser {
    inspectedBrowser
  }

  func icon(for browser: Browser) -> NSImage {
    NSImage(size: NSSize(width: 32, height: 32))
  }

  func isAvailable(_ browser: Browser) -> Bool {
    availableBrowserIDs.isEmpty || availableBrowserIDs.contains(browser.id)
  }

  func open(_ urls: [URL], in browser: Browser) async throws {
    if let openError {
      throw openError
    }
    openedURLs = urls
    openedBrowser = browser
  }

  func makeDefaultBrowser() async throws {
    if let makeDefaultError {
      throw makeDefaultError
    }
    defaultBrowser = true
  }

  func isDefaultBrowser() -> Bool {
    defaultBrowser
  }
}
