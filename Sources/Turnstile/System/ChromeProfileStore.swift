import Foundation

struct ChromeProfileStore {
  private let fileManager: FileManager
  private let applicationSupportURL: URL

  init(
    fileManager: FileManager = .default,
    applicationSupportURL: URL? = nil
  ) {
    self.fileManager = fileManager
    self.applicationSupportURL =
      applicationSupportURL
      ?? fileManager.homeDirectoryForCurrentUser.appending(path: "Library/Application Support")
  }

  func profiles(for browser: Browser) throws -> [Browser] {
    guard let dataURL = dataDirectory(for: browser) else { return [] }
    let stateURL = dataURL.appending(path: "Local State")
    let data: Data
    do {
      data = try Data(contentsOf: stateURL)
    } catch CocoaError.fileReadNoSuchFile {
      return []
    }
    guard let state = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ChromeProfileStoreError.invalidLocalState
    }
    guard let profileState = state["profile"] as? [String: Any],
      let cache = profileState["info_cache"] as? [String: Any]
    else { return [] }

    return cache.compactMap { directory, value -> ChromeProfile? in
      guard let attributes = value as? [String: Any],
        attributes["is_omitted"] as? Bool != true,
        attributes["is_ephemeral"] as? Bool != true
      else { return nil }
      let name = (attributes["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
      let profile = ChromeProfile(
        directory: directory,
        name: name.flatMap { $0.isEmpty ? nil : $0 } ?? directory
      )
      return isAvailable(browser.withProfile(profile)) ? profile : nil
    }
    .sorted {
      let comparison = $0.name.localizedStandardCompare($1.name)
      return comparison == .orderedSame
        ? $0.directory < $1.directory
        : comparison == .orderedAscending
    }
    .map(browser.withProfile)
  }

  func isAvailable(_ browser: Browser) -> Bool {
    guard let profile = browser.profile else { return true }
    guard profile.isValid, let dataURL = dataDirectory(for: browser) else { return false }
    var isDirectory: ObjCBool = false
    return fileManager.fileExists(
      atPath: dataURL.appending(path: profile.directory).path,
      isDirectory: &isDirectory
    ) && isDirectory.boolValue
  }

  func dataDirectory(for browser: Browser) -> URL? {
    browser.chromeDataDirectoryName.map {
      applicationSupportURL.appending(path: "Google/\($0)", directoryHint: .isDirectory)
    }
  }
}

enum ChromeProfileStoreError: LocalizedError {
  case invalidLocalState

  var errorDescription: String? {
    "Chrome’s profile list could not be read. Open Chrome and try again."
  }
}
