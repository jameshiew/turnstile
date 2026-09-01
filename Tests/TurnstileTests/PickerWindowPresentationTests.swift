import AppKit
import Testing

@testable import Turnstile

@MainActor
struct PickerWindowPresentationTests {
  private let screenFrame = NSRect(x: 0, y: 0, width: 1_000, height: 800)
  private let windowSize = NSSize(width: 320, height: 190)

  @Test
  func positionsPickerBelowAndCenteredOnAnchor() {
    let origin = PickerWindowPresentation.anchoredOrigin(
      windowSize: windowSize,
      placement: PickerPlacement(
        anchor: NSPoint(x: 500, y: 600),
        visibleScreenFrame: screenFrame
      )
    )

    #expect(origin == NSPoint(x: 340, y: 398))
  }

  @Test
  func positionsPickerAboveAnchorWhenThereIsNoRoomBelow() {
    let origin = PickerWindowPresentation.anchoredOrigin(
      windowSize: windowSize,
      placement: PickerPlacement(
        anchor: NSPoint(x: 500, y: 100),
        visibleScreenFrame: screenFrame
      )
    )

    #expect(origin == NSPoint(x: 340, y: 112))
  }

  @Test
  func keepsPickerInsideVisibleScreenEdges() {
    let origin = PickerWindowPresentation.anchoredOrigin(
      windowSize: windowSize,
      placement: PickerPlacement(
        anchor: NSPoint(x: 10, y: 790),
        visibleScreenFrame: screenFrame
      )
    )

    #expect(origin == NSPoint(x: 8, y: 588))
  }
}
