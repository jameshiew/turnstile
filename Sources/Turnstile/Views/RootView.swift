import AppKit
import SwiftUI

struct RootView: View {
  @Bindable var model: AppModel

  var body: some View {
    BrowserSettingsView(model: model)
      .frame(minWidth: 520, minHeight: 490)
      .alert(
        model.presentedError?.title ?? "Turnstile",
        isPresented: Binding(
          get: { model.presentedError != nil && !model.hasPendingURLs },
          set: { isPresented in
            if !isPresented {
              model.dismissError()
            }
          }
        ),
        presenting: model.presentedError
      ) { _ in
        Button("OK") {
          model.dismissError()
        }
      } message: { error in
        Text(error.message)
      }
  }
}

@MainActor
enum PickerWindowPresentation {
  static let pickerWindowIdentifier = NSUserInterfaceItemIdentifier("TurnstilePickerWindow")
  static let settingsWindowIdentifier = NSUserInterfaceItemIdentifier("TurnstileSettingsWindow")
  static let outerPadding: CGFloat = 1
  static let contentPadding: CGFloat = 14
  static let browserChoiceWidth: CGFloat = 112
  static let browserChoiceHeight: CGFloat = 88
  static let browserChoiceSpacing: CGFloat = 10
  static let browserIconSize: CGFloat = 56
  static let browserChoicesTopPadding: CGFloat = 8
  static let shortcutBadgeSize: CGFloat = 20
  static let shortcutBadgeInset: CGFloat = 6

  static var panelContentInset: CGFloat {
    outerPadding + contentPadding
  }

  static func size(browserCount: Int) -> NSSize {
    let visibleBrowserCount = min(max(browserCount, 1), 5)
    let choicesWidth =
      CGFloat(visibleBrowserCount) * browserChoiceWidth
      + CGFloat(visibleBrowserCount - 1) * browserChoiceSpacing
    let width = min(520, max(320, choicesWidth + 2 * panelContentInset))
    return NSSize(width: width, height: 200)
  }

  static func anchoredFrame(
    for window: NSWindow,
    contentSize: NSSize,
    browserCount: Int,
    placement: PickerPlacement
  ) -> NSRect {
    let targetFrame = window.frameRect(
      forContentRect: NSRect(origin: .zero, size: contentSize)
    )
    var frame = window.frame
    frame.size = targetFrame.size
    frame.origin = anchoredOrigin(
      windowSize: frame.size,
      browserCount: browserCount,
      placement: placement
    )
    return frame
  }

  static func anchoredOrigin(
    windowSize: NSSize,
    browserCount: Int,
    placement: PickerPlacement
  ) -> NSPoint {
    let gap: CGFloat = 12
    let screenPadding: CGFloat = 8
    let availableFrame = placement.visibleScreenFrame.insetBy(
      dx: screenPadding,
      dy: screenPadding
    )
    let anchor = placement.anchor
    let preferredOrigin: NSPoint

    if browserCount > 0 {
      let iconCenter = firstBrowserIconCenter(
        windowSize: windowSize,
        browserCount: browserCount
      )
      preferredOrigin = NSPoint(
        x: anchor.x - iconCenter.x,
        y: anchor.y - iconCenter.y
      )
    } else {
      preferredOrigin = NSPoint(
        x: anchor.x - windowSize.width / 2,
        y: anchor.y - gap - windowSize.height
      )
    }

    let maximumX = max(availableFrame.minX, availableFrame.maxX - windowSize.width)
    let maximumY = max(availableFrame.minY, availableFrame.maxY - windowSize.height)
    let x = min(max(preferredOrigin.x, availableFrame.minX), maximumX)
    let y = min(max(preferredOrigin.y, availableFrame.minY), maximumY)

    return NSPoint(x: x, y: y)
  }

  static func firstBrowserIconCenter(
    windowSize: NSSize,
    browserCount: Int
  ) -> NSPoint {
    let rowWidth = windowSize.width - 2 * panelContentInset
    let choiceCount = max(browserCount, 1)
    let choicesWidth =
      CGFloat(choiceCount) * browserChoiceWidth
      + CGFloat(choiceCount - 1) * browserChoiceSpacing
    let leadingSpace = max(0, (rowWidth - choicesWidth) / 2)
    let x = panelContentInset + leadingSpace + browserChoiceWidth / 2
    let distanceFromTop =
      panelContentInset
      + browserChoicesTopPadding
      + browserIconSize / 2

    return NSPoint(x: x, y: windowSize.height - distanceFromTop)
  }

  static func configure(_ window: NSWindow, asPicker: Bool) {
    window.identifier = asPicker ? pickerWindowIdentifier : settingsWindowIdentifier
    window.isReleasedWhenClosed = false
    window.tabbingMode = .disallowed

    if asPicker {
      window.styleMask.remove([.titled, .closable, .miniaturizable, .fullSizeContentView])
      window.styleMask.insert(.resizable)
      window.titleVisibility = .hidden
      window.level = .floating
      window.backgroundColor = .clear
      window.isOpaque = false
      window.isMovableByWindowBackground = true
      window.collectionBehavior.insert(.moveToActiveSpace)
    } else {
      window.styleMask.insert([.titled, .closable, .miniaturizable, .resizable])
      window.styleMask.remove(.fullSizeContentView)
      window.titleVisibility = .visible
      window.titlebarAppearsTransparent = false
      window.titlebarSeparatorStyle = .automatic
      window.level = .normal
      window.backgroundColor = .windowBackgroundColor
      window.isOpaque = true
      window.isMovableByWindowBackground = false
      window.collectionBehavior.remove(.moveToActiveSpace)
    }

    for buttonType in [
      NSWindow.ButtonType.closeButton,
      .miniaturizeButton,
      .zoomButton,
    ] {
      window.standardWindowButton(buttonType)?.isHidden = asPicker
    }
  }
}
