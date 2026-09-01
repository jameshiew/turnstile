import Foundation
import Testing

@testable import Turnstile

@MainActor
struct AppModelTests {
  @Test
  func receivesOnlyWebLinksAndRoutesThemTogether() async throws {
    let browser = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(browsers: [browser])
    let workspace = WorkspaceClientSpy()
    let model = AppModel(repository: repository, workspace: workspace)
    let http = try #require(URL(string: "http://example.com/one"))
    let https = try #require(URL(string: "https://example.com/two"))
    let file = URL(filePath: "/tmp/not-a-web-link")
    let preferredScreenFrame = CGRect(x: 1_920, y: 0, width: 2_560, height: 1_440)

    model.receive([http, file, https], preferredScreenFrame: preferredScreenFrame)
    #expect(model.preferredPickerScreenFrame == preferredScreenFrame)
    let didOpen = await model.routePendingURLs(to: browser)

    #expect(didOpen)
    #expect(workspace.openedURLs == [http, https])
    #expect(workspace.openedBrowser == browser)
    #expect(model.preferredPickerScreenFrame == nil)
    #expect(!model.hasPendingURLs)
  }

  @Test
  func keepsLinksPendingWhenTheBrowserFailsToOpen() async throws {
    let browser = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(browsers: [browser])
    let workspace = WorkspaceClientSpy()
    workspace.openError = TestFailure.expected
    let model = AppModel(repository: repository, workspace: workspace)
    let url = try #require(URL(string: "https://example.com"))

    model.receive([url])
    let didOpen = await model.routePendingURLs(to: browser)

    #expect(!didOpen)
    #expect(model.pendingURLs == [url])
    #expect(model.presentedError?.title == "Link Could Not Be Opened")
  }

  @Test
  func addsTheExplicitlySelectedBrowser() async {
    let repository = InMemoryBrowserRepository()
    let workspace = WorkspaceClientSpy()
    workspace.chosenApplicationURL = URL(filePath: "/Applications/Selected.app")
    let model = AppModel(repository: repository, workspace: workspace)

    await model.addBrowser()

    #expect(model.browsers.browsers == [workspace.inspectedBrowser])
    #expect(repository.storedBrowsers == [workspace.inspectedBrowser])
  }

  @Test
  func doesNotPublishAChangeThatCouldNotBePersisted() {
    let safari = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(browsers: [safari])
    let workspace = WorkspaceClientSpy()
    let model = AppModel(repository: repository, workspace: workspace)
    repository.saveError = TestFailure.expected

    model.removeBrowser(id: safari.id)

    #expect(model.browsers.browsers == [safari])
    #expect(model.presentedError?.title == "Browser Could Not Be Removed")
  }

  @Test
  func requiresADestinationBeforeBecomingDefault() async {
    let repository = InMemoryBrowserRepository()
    let workspace = WorkspaceClientSpy()
    let model = AppModel(repository: repository, workspace: workspace)

    await model.setAsDefaultBrowser()

    #expect(!workspace.defaultBrowser)
    #expect(model.presentedError?.title == "Add a Browser First")
  }

  @Test
  func refreshesStatusAfterBecomingDefault() async {
    let browser = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(browsers: [browser])
    let workspace = WorkspaceClientSpy()
    let model = AppModel(repository: repository, workspace: workspace)

    await model.setAsDefaultBrowser()

    #expect(workspace.defaultBrowser)
    #expect(model.isDefaultBrowser)
  }

  @Test
  func acceptsReportedFailureWhenDefaultBrowserChanged() async {
    let browser = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(browsers: [browser])
    let workspace = WorkspaceClientSpy()
    workspace.makeDefaultError = TestFailure.expected
    workspace.becomesDefaultBeforeMakeDefaultError = true
    let model = AppModel(repository: repository, workspace: workspace)

    await model.setAsDefaultBrowser()

    #expect(model.isDefaultBrowser)
    #expect(model.presentedError == nil)
  }

  @Test
  func reportsFailureWhenDefaultBrowserDidNotChange() async {
    let browser = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(browsers: [browser])
    let workspace = WorkspaceClientSpy()
    workspace.makeDefaultError = TestFailure.expected
    let model = AppModel(repository: repository, workspace: workspace)

    await model.setAsDefaultBrowser()

    #expect(!model.isDefaultBrowser)
    #expect(model.presentedError?.title == "Default Browser Could Not Be Changed")
  }
}
