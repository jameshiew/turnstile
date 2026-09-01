import Foundation
import Testing

@testable import Turnstile

@Suite(.serialized)
@MainActor
struct BrowserRepositoryTests {
  private struct RepositoryContext {
    let repository: UserDefaultsBrowserRepository
    let defaults: UserDefaults
    let suiteName: String
  }

  @Test
  func roundTripsBrowserOrder() throws {
    let context = makeRepository()
    defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
    let browsers = [makeBrowser(name: "Firefox"), makeBrowser(name: "Safari")]

    try context.repository.save(browsers)

    #expect(try context.repository.load() == browsers)
  }

  @Test
  func rejectsAnUnknownPayloadVersion() throws {
    let context = makeRepository()
    defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
    context.defaults.set(
      Data(#"{"browsers":[],"version":2}"#.utf8),
      forKey: "test-browser-library"
    )

    #expect(throws: BrowserRepositoryError.unsupportedVersion(2)) {
      try context.repository.load()
    }
  }

  private func makeRepository() -> RepositoryContext {
    let suiteName = "TurnstileTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return RepositoryContext(
      repository: UserDefaultsBrowserRepository(
        defaults: defaults,
        key: "test-browser-library"
      ),
      defaults: defaults,
      suiteName: suiteName
    )
  }
}
