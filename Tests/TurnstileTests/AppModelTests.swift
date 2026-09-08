import Foundation
import Testing

@testable import Turnstile

@MainActor
struct AppModelTests {
  @Test
  func receivesWebLinksAndFilesAndRoutesThemTogether() async throws {
    let browser = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(browsers: [browser])
    let workspace = WorkspaceClientSpy()
    let model = AppModel(repository: repository, workspace: workspace)
    let http = try #require(URL(string: "http://example.com/one"))
    let https = try #require(URL(string: "https://example.com/two"))
    let file = URL(filePath: "/tmp/local page #1 %.html")
    let unsupported = try #require(URL(string: "mailto:someone@example.com"))
    let preferredPlacement = PickerPlacement(
      anchor: CGPoint(x: 3_000, y: 900),
      visibleScreenFrame: CGRect(x: 1_920, y: 0, width: 2_560, height: 1_440)
    )

    model.receive([http, file, unsupported, https], preferredPickerPlacement: preferredPlacement)
    #expect(model.preferredPickerPlacement == preferredPlacement)
    let didOpen = await model.routePendingURLs(to: browser)

    #expect(didOpen)
    #expect(workspace.openedURLs == [http, file, https])
    #expect(workspace.openedBrowser == browser)
    #expect(model.preferredPickerPlacement == nil)
    #expect(!model.hasPendingURLs)
  }

  @Test
  func receivesLocalHTMLFilesWithoutAWebLink() async {
    let browser = makeBrowser(name: "Safari")
    let workspace = WorkspaceClientSpy()
    let model = AppModel(
      repository: InMemoryBrowserRepository(browsers: [browser]),
      workspace: workspace
    )
    let files = [URL(filePath: "/tmp/some.html"), URL(filePath: "/tmp/another page.htm")]

    model.receive(files)

    #expect(model.hasPendingURLs)
    #expect(model.pendingURLs == files)
    #expect(await model.routePendingURLs(to: browser))
    #expect(workspace.openedURLs == files)
    #expect(!model.hasPendingURLs)
  }

  @Test(arguments: ["https://example.com", "file:///tmp/local%20page.html"])
  func keepsLinksPendingWhenTheBrowserFailsToOpen(value: String) async throws {
    let browser = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(browsers: [browser])
    let workspace = WorkspaceClientSpy()
    workspace.openError = TestFailure.expected
    let model = AppModel(repository: repository, workspace: workspace)
    let url = try #require(URL(string: value))

    model.receive([url])
    let didOpen = await model.routePendingURLs(to: browser)

    #expect(!didOpen)
    #expect(model.pendingURLs == [url])
    #expect(model.presentedError?.title == "Link Could Not Be Opened")
  }

  @Test
  func defaultsToFirstAvailableBrowser() {
    let unavailableBrowser = makeBrowser(name: "Missing")
    let availableBrowser = makeBrowser(name: "Safari")
    let repository = InMemoryBrowserRepository(
      browsers: [unavailableBrowser, availableBrowser]
    )
    let workspace = WorkspaceClientSpy()
    workspace.availableBrowserIDs = [availableBrowser.id]
    let model = AppModel(repository: repository, workspace: workspace)

    #expect(model.defaultBrowser == availableBrowser)
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
