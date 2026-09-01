import AppKit
import Testing

@testable import Turnstile

@MainActor
struct PickerWindowPresentationTests {
  private let screenFrame = NSRect(x: 0, y: 0, width: 1_000, height: 800)
  private let windowSize = NSSize(width: 320, height: 190)

  @Test
  func positionsFirstBrowserIconCenterOnAnchor() {
    let anchor = NSPoint(x: 500, y: 600)
    for browserCount in [1, 2, 3, 5, 6] {
      let size = PickerWindowPresentation.size(browserCount: browserCount)
      let origin = PickerWindowPresentation.anchoredOrigin(
        windowSize: size,
        browserCount: browserCount,
        placement: PickerPlacement(
          anchor: anchor,
          visibleScreenFrame: screenFrame
        )
      )
      let iconCenter = PickerWindowPresentation.firstBrowserIconCenter(
        windowSize: size,
        browserCount: browserCount
      )

      #expect(origin.x + iconCenter.x == anchor.x)
      #expect(origin.y + iconCenter.y == anchor.y)
    }
  }

  @Test
  func centersSingleBrowserInPicker() {
    let iconCenter = PickerWindowPresentation.firstBrowserIconCenter(
      windowSize: windowSize,
      browserCount: 1
    )

    #expect(iconCenter.x == windowSize.width / 2)
    #expect(iconCenter.y == 139)
  }

  @Test
  func keepsNumberShortcutClearOfBrowserIcon() {
    let iconTrailingEdge =
      PickerWindowPresentation.browserChoiceWidth / 2
      + PickerWindowPresentation.browserIconSize / 2
    let shortcutLeadingEdge =
      PickerWindowPresentation.browserChoiceWidth
      - PickerWindowPresentation.shortcutBadgeInset
      - PickerWindowPresentation.shortcutBadgeSize

    #expect(iconTrailingEdge < shortcutLeadingEdge)
  }

  @Test
  func keepsPickerInsideVisibleScreenEdges() {
    let origin = PickerWindowPresentation.anchoredOrigin(
      windowSize: windowSize,
      browserCount: 2,
      placement: PickerPlacement(
        anchor: NSPoint(x: 10, y: 790),
        visibleScreenFrame: screenFrame
      )
    )

    #expect(origin == NSPoint(x: 8, y: 602))
  }

  @Test
  func retainsConfiguredWindowAfterItCloses() {
    let window = NSWindow()

    PickerWindowPresentation.configure(window, asPicker: false)

    #expect(window.identifier == PickerWindowPresentation.settingsWindowIdentifier)
    #expect(!window.isReleasedWhenClosed)
  }

  @Test
  func createsSettingsOnlyWhenItsControllerIsCreated() throws {
    let model = AppModel(
      repository: InMemoryBrowserRepository(),
      workspace: WorkspaceClientSpy()
    )
    let controller = SettingsWindowController(model: model)
    let window = try #require(controller.window)

    #expect(window.identifier == PickerWindowPresentation.settingsWindowIdentifier)
    #expect(window.title == "Turnstile")
    #expect(window.contentLayoutRect.size == NSSize(width: 560, height: 450))
    #expect(!window.isVisible)
  }

  @Test
  func usesANonactivatingPanelForThePicker() throws {
    let model = AppModel(
      repository: InMemoryBrowserRepository(),
      workspace: WorkspaceClientSpy()
    )
    let controller = PickerWindowController(model: model)
    let panel = try #require(controller.window as? NSPanel)

    #expect(panel.styleMask.contains(.nonactivatingPanel))
    #expect(panel.canBecomeKey)
    #expect(!panel.canBecomeMain)
    #expect(panel.delegate === controller)
  }

  @Test
  func dismissesThePickerWhenItLosesKeyStatus() throws {
    let model = AppModel(
      repository: InMemoryBrowserRepository(),
      workspace: WorkspaceClientSpy()
    )
    let controller = PickerWindowController(model: model)
    let window = try #require(controller.window)
    let url = try #require(URL(string: "https://example.com"))
    model.receive([url])

    controller.windowDidResignKey(
      Notification(name: NSWindow.didResignKeyNotification, object: window)
    )

    #expect(!model.hasPendingURLs)
    #expect(!window.isVisible)
  }
}
