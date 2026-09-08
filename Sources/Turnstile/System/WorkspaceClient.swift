import AppKit
import UniformTypeIdentifiers

@MainActor
protocol WorkspaceClient: AnyObject {
  func chooseBrowser() async -> URL?
  func browser(at applicationURL: URL) throws -> Browser
  func profiles(for browser: Browser) throws -> [Browser]
  func icon(for browser: Browser) -> NSImage
  func isAvailable(_ browser: Browser) -> Bool
  func open(_ urls: [URL], in browser: Browser) async throws
  func makeDefaultBrowser() async throws
  func isDefaultBrowser() -> Bool
}

@MainActor
final class SystemWorkspaceClient: WorkspaceClient {
  private let workspace: NSWorkspace
  private let fileManager: FileManager
  private let bundle: Bundle
  private let profileStore: ChromeProfileStore

  init(
    workspace: NSWorkspace = .shared,
    fileManager: FileManager = .default,
    bundle: Bundle = .main,
    profileStore: ChromeProfileStore = ChromeProfileStore()
  ) {
    self.workspace = workspace
    self.fileManager = fileManager
    self.bundle = bundle
    self.profileStore = profileStore
  }

  func chooseBrowser() async -> URL? {
    let panel = NSOpenPanel()
    panel.title = "Add Browser"
    panel.message = "Choose a browser application."
    panel.prompt = "Add"
    panel.allowedContentTypes = [.applicationBundle]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.treatsFilePackagesAsDirectories = false
    panel.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)

    let response: NSApplication.ModalResponse
    let hostWindow =
      NSApplication.shared.keyWindow
      ?? NSApplication.shared.windows.first(where: \.isVisible)
    if let hostWindow {
      response = await panel.beginSheetModal(for: hostWindow)
    } else {
      response = panel.runModal()
    }

    return response == .OK ? panel.url : nil
  }

  func browser(at applicationURL: URL) throws -> Browser {
    guard applicationURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
      let selectedBundle = Bundle(url: applicationURL),
      let bundleIdentifier = selectedBundle.bundleIdentifier,
      !bundleIdentifier.isEmpty
    else {
      throw WorkspaceClientError.invalidApplication
    }

    guard bundleIdentifier != bundle.bundleIdentifier else {
      throw WorkspaceClientError.cannotAddTurnstile
    }
    guard
      handlesWebURLs(
        applicationURL: applicationURL,
        applicationBundle: selectedBundle,
        bundleIdentifier: bundleIdentifier
      )
    else {
      throw WorkspaceClientError.notAWebBrowser
    }

    let localizedName =
      selectedBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
    let bundleName = selectedBundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    let fallbackName = applicationURL.deletingPathExtension().lastPathComponent
    let displayName = [localizedName, bundleName, fallbackName]
      .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first(where: { !$0.isEmpty })

    guard let displayName else {
      throw WorkspaceClientError.invalidApplication
    }

    return Browser(
      bundleIdentifier: bundleIdentifier,
      displayName: displayName,
      applicationURL: applicationURL.standardizedFileURL
    )
  }

  func icon(for browser: Browser) -> NSImage {
    let applicationURL = resolvedApplicationURL(for: browser) ?? browser.applicationURL
    let image = workspace.icon(forFile: applicationURL.path)
    return image.copy() as? NSImage ?? image
  }

  func profiles(for browser: Browser) throws -> [Browser] {
    try profileStore.profiles(for: browser)
  }

  func isAvailable(_ browser: Browser) -> Bool {
    resolvedApplicationURL(for: browser) != nil && profileStore.isAvailable(browser)
  }

  func open(_ urls: [URL], in browser: Browser) async throws {
    guard !urls.isEmpty, urls.allSatisfy(\.isRoutableBrowserURL) else {
      throw WorkspaceClientError.invalidURL
    }
    guard let applicationURL = resolvedApplicationURL(for: browser) else {
      throw WorkspaceClientError.applicationNotFound(browser.displayName)
    }
    guard Bundle(url: applicationURL)?.bundleIdentifier != bundle.bundleIdentifier else {
      throw WorkspaceClientError.cannotAddTurnstile
    }
    guard profileStore.isAvailable(browser) else {
      throw WorkspaceClientError.profileNotFound(browser.destinationName)
    }

    let configuration = openConfiguration(for: browser, urls: urls)

    if browser.profile != nil {
      _ = try await workspace.openApplication(at: applicationURL, configuration: configuration)
      return
    }

    _ = try await workspace.open(
      urls,
      withApplicationAt: applicationURL,
      configuration: configuration
    )
  }

  func openConfiguration(for browser: Browser, urls: [URL]) -> NSWorkspace.OpenConfiguration {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.addsToRecentItems = false
    if let profile = browser.profile, let dataURL = profileStore.dataDirectory(for: browser) {
      configuration.createsNewApplicationInstance = true
      configuration.arguments =
        [
          "--user-data-dir=\(dataURL.path)",
          "--profile-directory=\(profile.directory)",
        ]
        + urls.map(\.absoluteString)
    }
    return configuration
  }

  func makeDefaultBrowser() async throws {
    guard bundle.bundleURL.pathExtension == "app" else {
      throw WorkspaceClientError.notRunningAsApplication
    }

    try await workspace.setDefaultApplication(
      at: bundle.bundleURL,
      toOpenURLsWithScheme: "http"
    )
    try await workspace.setDefaultApplication(
      at: bundle.bundleURL,
      toOpenURLsWithScheme: "https"
    )
    try await workspace.setDefaultApplication(at: bundle.bundleURL, toOpen: .html)
  }

  func isDefaultBrowser() -> Bool {
    guard let ownIdentifier = bundle.bundleIdentifier,
      let htmlHandlerURL = workspace.urlForApplication(toOpen: UTType.html),
      Bundle(url: htmlHandlerURL)?.bundleIdentifier == ownIdentifier
    else { return false }

    return ["http://example.com", "https://example.com"].allSatisfy { value in
      guard let url = URL(string: value),
        let handlerURL = workspace.urlForApplication(toOpen: url)
      else {
        return false
      }
      return Bundle(url: handlerURL)?.bundleIdentifier == ownIdentifier
    }
  }

  private func resolvedApplicationURL(for browser: Browser) -> URL? {
    let savedURLIsValid =
      fileManager.fileExists(atPath: browser.applicationURL.path)
      && Bundle(url: browser.applicationURL)?.bundleIdentifier == browser.bundleIdentifier
    if savedURLIsValid {
      return browser.applicationURL
    }

    return workspace.urlForApplication(withBundleIdentifier: browser.bundleIdentifier)
  }

  private func handlesWebURLs(
    applicationURL: URL,
    applicationBundle: Bundle,
    bundleIdentifier: String
  ) -> Bool {
    let declaredSchemes =
      (applicationBundle.object(forInfoDictionaryKey: "CFBundleURLTypes")
      as? [[String: Any]] ?? [])
      .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
      .map { $0.lowercased() }

    if ["http", "https"].allSatisfy(declaredSchemes.contains) {
      return true
    }

    return ["http://example.com", "https://example.com"].allSatisfy { value in
      guard let url = URL(string: value) else { return false }
      return workspace.urlsForApplications(toOpen: url).contains { candidate in
        candidate.standardizedFileURL == applicationURL.standardizedFileURL
          || Bundle(url: candidate)?.bundleIdentifier == bundleIdentifier
      }
    }
  }
}

extension URL {
  var isRoutableBrowserURL: Bool {
    if isFileURL { return true }
    guard let scheme = scheme?.lowercased() else { return false }
    return scheme == "http" || scheme == "https"
  }
}

enum WorkspaceClientError: LocalizedError, Equatable {
  case applicationNotFound(String)
  case cannotAddTurnstile
  case invalidApplication
  case invalidURL
  case notAWebBrowser
  case notRunningAsApplication
  case profileNotFound(String)

  var errorDescription: String? {
    switch self {
    case .applicationNotFound(let name):
      "\(name) could not be found. Remove it and add it again."
    case .cannotAddTurnstile:
      "Turnstile cannot route a link back to itself."
    case .invalidApplication:
      "The selected item is not a valid macOS application."
    case .invalidURL:
      "Turnstile can only route HTTP and HTTPS links and local files."
    case .notAWebBrowser:
      "The selected application does not handle both HTTP and HTTPS links."
    case .notRunningAsApplication:
      "Turnstile must be run from its app bundle before it can become the default browser."
    case .profileNotFound(let name):
      "The profile for \(name) could not be found. Remove it and add it again."
    }
  }
}
