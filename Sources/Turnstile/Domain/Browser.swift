import Foundation

struct Browser: Codable, Hashable, Identifiable, Sendable {
  let bundleIdentifier: String
  let displayName: String
  let applicationURL: URL
  let profile: ChromeProfile?

  init(
    bundleIdentifier: String,
    displayName: String,
    applicationURL: URL,
    profile: ChromeProfile? = nil
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.displayName = displayName
    self.applicationURL = applicationURL
    self.profile = profile
  }

  var id: String {
    bundleIdentifier.lowercased() + (profile.map { "#\($0.directory)" } ?? "")
  }

  var destinationName: String {
    profile.map { "\(displayName) – \($0.name)" } ?? displayName
  }

  var chromeDataDirectoryName: String? {
    switch bundleIdentifier.lowercased() {
    case "com.google.chrome": "Chrome"
    case "com.google.chrome.beta": "Chrome Beta"
    case "com.google.chrome.dev": "Chrome Dev"
    case "com.google.chrome.canary": "Chrome Canary"
    case "com.google.chrome.for.testing": "Chrome for Testing"
    default: nil
    }
  }

  var isValid: Bool {
    !bundleIdentifier.isEmpty && !displayName.isEmpty
      && (profile == nil || (chromeDataDirectoryName != nil && profile?.isValid == true))
  }

  func withProfile(_ profile: ChromeProfile) -> Browser {
    Browser(
      bundleIdentifier: bundleIdentifier,
      displayName: displayName,
      applicationURL: applicationURL,
      profile: profile
    )
  }
}

struct ChromeProfile: Codable, Hashable, Sendable {
  let directory: String
  let name: String

  var isValid: Bool {
    !name.isEmpty && !directory.isEmpty
      && ![".", "..", "Guest Profile", "System Profile"].contains(directory)
      && !directory.contains("/") && !directory.contains("\\") && !directory.contains("\0")
  }
}

struct BrowserCollection: Equatable, Sendable {
  enum MoveDirection: Sendable {
    case towardStart
    case towardEnd
  }

  private(set) var elements: [Browser]

  init(_ elements: [Browser] = []) throws {
    var identifiers = Set<String>()

    for browser in elements {
      guard browser.isValid else {
        throw BrowserCollectionError.invalidBrowser
      }
      guard identifiers.insert(browser.id).inserted else {
        throw BrowserCollectionError.duplicateBrowser(browser.destinationName)
      }
    }

    self.elements = elements
  }

  mutating func add(_ browser: Browser) throws {
    guard browser.isValid else {
      throw BrowserCollectionError.invalidBrowser
    }
    guard !elements.contains(where: { $0.id == browser.id }) else {
      throw BrowserCollectionError.duplicateBrowser(browser.destinationName)
    }
    elements.append(browser)
  }

  mutating func remove(id: Browser.ID) {
    elements.removeAll { $0.id == id }
  }

  mutating func move(id: Browser.ID, direction: MoveDirection) {
    guard let source = elements.firstIndex(where: { $0.id == id }) else { return }

    let destination =
      switch direction {
      case .towardStart: source - 1
      case .towardEnd: source + 1
      }

    guard elements.indices.contains(destination) else { return }
    elements.swapAt(source, destination)
  }

  mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
    let validSource = source.filter(elements.indices.contains)
    guard !validSource.isEmpty else { return }

    let moving = validSource.map { elements[$0] }
    for index in validSource.reversed() {
      elements.remove(at: index)
    }

    let removedBeforeDestination = validSource.count(where: { $0 < destination })
    let insertionIndex = min(
      max(0, destination - removedBeforeDestination),
      elements.endIndex
    )
    elements.insert(contentsOf: moving, at: insertionIndex)
  }

  func canMove(id: Browser.ID, direction: MoveDirection) -> Bool {
    guard let index = elements.firstIndex(where: { $0.id == id }) else { return false }

    return switch direction {
    case .towardStart: index > elements.startIndex
    case .towardEnd: index < elements.index(before: elements.endIndex)
    }
  }
}

enum BrowserCollectionError: LocalizedError, Equatable {
  case duplicateBrowser(String)
  case invalidBrowser

  var errorDescription: String? {
    switch self {
    case .duplicateBrowser(let name):
      "\(name) has already been added."
    case .invalidBrowser:
      "The saved browser list contains an invalid entry."
    }
  }
}
