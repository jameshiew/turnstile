import Foundation
import Testing

@testable import Turnstile

@MainActor
struct ApplicationBundleTests {
  @Test
  func declaresBothWebURLSchemes() throws {
    let applicationBundle = Bundle(for: AppDelegate.self)
    let urlTypes = try #require(
      applicationBundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
    )
    let schemes = Set(
      urlTypes.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    )

    #expect(schemes.isSuperset(of: ["http", "https"]))
  }
}
