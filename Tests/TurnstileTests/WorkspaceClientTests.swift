import Foundation
import Testing

@testable import Turnstile

@MainActor
struct WorkspaceClientTests {
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
