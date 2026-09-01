import Foundation

@MainActor
protocol BrowserRepository: AnyObject {
  func load() throws -> [Browser]
  func save(_ browsers: [Browser]) throws
}

@MainActor
final class UserDefaultsBrowserRepository: BrowserRepository {
  private struct Payload: Codable {
    let version: Int
    let browsers: [Browser]
  }

  private let defaults: UserDefaults
  private let key: String
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()

  init(
    defaults: UserDefaults = .standard,
    key: String = "browser-library"
  ) {
    self.defaults = defaults
    self.key = key
    encoder.outputFormatting = [.sortedKeys]
  }

  func load() throws -> [Browser] {
    guard let data = defaults.data(forKey: key) else { return [] }

    let payload = try decoder.decode(Payload.self, from: data)
    guard payload.version == 1 else {
      throw BrowserRepositoryError.unsupportedVersion(payload.version)
    }
    return payload.browsers
  }

  func save(_ browsers: [Browser]) throws {
    let data = try encoder.encode(Payload(version: 1, browsers: browsers))
    defaults.set(data, forKey: key)
  }
}

enum BrowserRepositoryError: LocalizedError, Equatable {
  case unsupportedVersion(Int)

  var errorDescription: String? {
    switch self {
    case .unsupportedVersion(let version):
      "The saved browser list uses unsupported format version \(version)."
    }
  }
}
