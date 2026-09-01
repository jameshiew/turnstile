import AppKit
import SwiftUI

struct RootView: View {
  @Bindable var model: AppModel

  var body: some View {
    Group {
      if model.hasPendingURLs {
        LinkPickerView(model: model)
          .frame(width: pickerSize.width, height: pickerSize.height)
          .ignoresSafeArea()
      } else {
        BrowserSettingsView(model: model)
          .frame(minWidth: 520, minHeight: 420)
      }
    }
    .alert(
      model.presentedError?.title ?? "Turnstile",
      isPresented: Binding(
        get: { model.presentedError != nil },
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
    .onAppear {
      resizeWindow()
    }
    .onChange(of: model.hasPendingURLs) {
      resizeWindow()
    }
  }

  private func resizeWindow() {
    Task { @MainActor in
      await Task.yield()
      guard
        let window = NSApplication.shared.keyWindow
          ?? NSApplication.shared.windows.first(where: \.canBecomeKey)
      else {
        return
      }

      PickerWindowPresentation.configure(window, asPicker: model.hasPendingURLs)

      let contentSize =
        model.hasPendingURLs
        ? pickerSize
        : NSSize(width: 560, height: 450)
      let targetFrame = window.frameRect(
        forContentRect: NSRect(origin: .zero, size: contentSize)
      )
      var frame = window.frame
      frame.size = targetFrame.size

      if model.hasPendingURLs, let placement = preferredPickerPlacement(for: window) {
        frame.origin = PickerWindowPresentation.anchoredOrigin(
          windowSize: frame.size,
          browserCount: model.browsers.browsers.count,
          placement: placement
        )
      } else {
        frame.origin.y += window.frame.height - frame.height
      }

      window.setFrame(frame, display: true, animate: false)
    }
  }

  private var pickerSize: NSSize {
    PickerWindowPresentation.size(browserCount: model.browsers.browsers.count)
  }

  private func preferredPickerPlacement(for window: NSWindow) -> PickerPlacement? {
    if let placement = model.preferredPickerPlacement {
      return placement
    }

    let mouseLocation = NSEvent.mouseLocation
    let screen =
      NSScreen.screens.first {
        NSMouseInRect(mouseLocation, $0.frame, false)
      }
      ?? window.screen

    return screen.map {
      PickerPlacement(anchor: mouseLocation, visibleScreenFrame: $0.visibleFrame)
    }
  }

}

@MainActor
enum PickerWindowPresentation {
  static let outerPadding: CGFloat = 1
  static let contentPadding: CGFloat = 14
  static let browserChoiceWidth: CGFloat = 88
  static let browserChoiceHeight: CGFloat = 78
  static let browserChoiceSpacing: CGFloat = 8
  static let browserIconSize: CGFloat = 48
  static let browserChoicesTopPadding: CGFloat = 10

  static var panelContentInset: CGFloat {
    outerPadding + contentPadding
  }

  static func size(browserCount: Int) -> NSSize {
    let visibleBrowserCount = min(max(browserCount, 1), 5)
    let width = min(520, max(320, CGFloat(visibleBrowserCount * 94 + 28)))
    return NSSize(width: width, height: 190)
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
