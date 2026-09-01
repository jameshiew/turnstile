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

    #expect(window.identifier == PickerWindowPresentation.windowIdentifier)
    #expect(!window.isReleasedWhenClosed)
  }
}
