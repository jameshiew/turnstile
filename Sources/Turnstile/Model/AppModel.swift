import AppKit
import Observation

@MainActor
@Observable
final class BrowserLibrary {
  private(set) var browsers: [Browser]
  let loadErrorMessage: String?

  @ObservationIgnored private let repository: any BrowserRepository

  init(repository: any BrowserRepository) {
    self.repository = repository

    do {
      browsers = try BrowserCollection(repository.load()).elements
      loadErrorMessage = nil
    } catch {
      browsers = []
      loadErrorMessage = error.localizedDescription
    }
  }

  func add(_ browser: Browser) throws {
    try update { try $0.add(browser) }
  }

  func remove(id: Browser.ID) throws {
    try update { $0.remove(id: id) }
  }

  func move(id: Browser.ID, direction: BrowserCollection.MoveDirection) throws {
    try update { $0.move(id: id, direction: direction) }
  }

  func move(fromOffsets source: IndexSet, toOffset destination: Int) throws {
    try update { $0.move(fromOffsets: source, toOffset: destination) }
  }

  func canMove(id: Browser.ID, direction: BrowserCollection.MoveDirection) -> Bool {
    guard let collection = try? BrowserCollection(browsers) else { return false }
    return collection.canMove(id: id, direction: direction)
  }

  private func update(_ mutation: (inout BrowserCollection) throws -> Void) throws {
    var updated = try BrowserCollection(browsers)
    try mutation(&updated)
    try repository.save(updated.elements)
    browsers = updated.elements
  }
}

@MainActor
@Observable
final class AppModel {
  let browsers: BrowserLibrary

  private(set) var pendingURLs: [URL] = []
  private(set) var isAddingBrowser = false
  private(set) var isRouting = false
  private(set) var isSettingDefaultBrowser = false
  private(set) var isDefaultBrowser: Bool
  private(set) var presentedError: PresentedError?

  @ObservationIgnored private let workspace: any WorkspaceClient

  init(
    repository: any BrowserRepository,
    workspace: any WorkspaceClient
  ) {
    let browsers = BrowserLibrary(repository: repository)
    self.browsers = browsers
    self.workspace = workspace
    isDefaultBrowser = workspace.isDefaultBrowser()

    if let message = browsers.loadErrorMessage {
      presentedError = PresentedError(
        title: "Browser List Could Not Be Loaded",
        message: message
      )
    }
  }

  var hasPendingURLs: Bool {
    !pendingURLs.isEmpty
  }

  func receive(_ urls: [URL]) {
    pendingURLs.append(contentsOf: urls.filter(\.isRoutableWebURL))
  }

  func addBrowser() async {
    guard !isAddingBrowser else { return }
    isAddingBrowser = true
    defer { isAddingBrowser = false }

    guard let applicationURL = await workspace.chooseBrowser() else { return }

    do {
      try browsers.add(workspace.browser(at: applicationURL))
    } catch {
      present(error, title: "Browser Could Not Be Added")
    }
  }

  func removeBrowser(id: Browser.ID) {
    do {
      try browsers.remove(id: id)
    } catch {
      present(error, title: "Browser Could Not Be Removed")
    }
  }

  func moveBrowser(
    id: Browser.ID,
    direction: BrowserCollection.MoveDirection
  ) {
    do {
      try browsers.move(id: id, direction: direction)
    } catch {
      present(error, title: "Browser Order Could Not Be Saved")
    }
  }

  func moveBrowsers(fromOffsets source: IndexSet, toOffset destination: Int) {
    do {
      try browsers.move(fromOffsets: source, toOffset: destination)
    } catch {
      present(error, title: "Browser Order Could Not Be Saved")
    }
  }

  func routePendingURLs(to browser: Browser) async -> Bool {
    guard !isRouting, !pendingURLs.isEmpty else { return false }

    let urls = pendingURLs
    isRouting = true
    defer { isRouting = false }

    do {
      try await workspace.open(urls, in: browser)
      pendingURLs.removeFirst(min(urls.count, pendingURLs.count))
      return true
    } catch {
      present(error, title: "Link Could Not Be Opened")
      return false
    }
  }

  func cancelRouting() {
    guard !isRouting else { return }
    pendingURLs.removeAll()
  }

  func setAsDefaultBrowser() async {
    guard !isSettingDefaultBrowser else { return }
    guard !browsers.browsers.isEmpty else {
      presentedError = PresentedError(
        title: "Add a Browser First",
        message: "Turnstile needs at least one destination browser before it becomes the default."
      )
      return
    }

    isSettingDefaultBrowser = true
    defer { isSettingDefaultBrowser = false }

    do {
      try await workspace.makeDefaultBrowser()
      refreshDefaultBrowserStatus()
    } catch {
      present(error, title: "Default Browser Could Not Be Changed")
    }
  }

  func refreshDefaultBrowserStatus() {
    isDefaultBrowser = workspace.isDefaultBrowser()
  }

  func icon(for browser: Browser) -> NSImage {
    workspace.icon(for: browser)
  }

  func isAvailable(_ browser: Browser) -> Bool {
    workspace.isAvailable(browser)
  }

  func dismissError() {
    presentedError = nil
  }

  private func present(_ error: any Error, title: String) {
    presentedError = PresentedError(title: title, message: error.localizedDescription)
  }
}

struct PresentedError: Identifiable, Equatable {
  let id = UUID()
  let title: String
  let message: String
}

extension URL {
  fileprivate var isRoutableWebURL: Bool {
    guard let scheme = scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
  }
}
