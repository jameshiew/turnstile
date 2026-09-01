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

      if model.hasPendingURLs,
        let screenFrame = model.preferredPickerScreenFrame
          ?? screenContainingMouse()?.visibleFrame
          ?? window.screen?.visibleFrame
      {
        frame.origin = NSPoint(
          x: screenFrame.midX - frame.width / 2,
          y: screenFrame.midY - frame.height / 2
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

  private func screenContainingMouse() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    return NSScreen.screens.first {
      NSMouseInRect(mouseLocation, $0.frame, false)
    }
  }

}

@MainActor
enum PickerWindowPresentation {
  static func size(browserCount: Int) -> NSSize {
    let visibleBrowserCount = min(max(browserCount, 1), 5)
    let width = min(520, max(320, CGFloat(visibleBrowserCount * 94 + 28)))
    return NSSize(width: width, height: 190)
  }

  static func centeredFrame(
    for window: NSWindow,
    contentSize: NSSize,
    in screenFrame: NSRect
  ) -> NSRect {
    let targetFrame = window.frameRect(
      forContentRect: NSRect(origin: .zero, size: contentSize)
    )
    var frame = window.frame
    frame.size = targetFrame.size
    frame.origin = NSPoint(
      x: screenFrame.midX - frame.width / 2,
      y: screenFrame.midY - frame.height / 2
    )
    return frame
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
