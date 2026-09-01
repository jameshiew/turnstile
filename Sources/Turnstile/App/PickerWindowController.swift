import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  init(model: AppModel) {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 560, height: 450),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "Turnstile"
    window.contentViewController = NSHostingController(rootView: RootView(model: model))
    PickerWindowPresentation.configure(window, asPicker: false)
    window.setContentSize(NSSize(width: 560, height: 450))
    window.center()

    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}

@MainActor
final class PickerWindowController: NSWindowController, NSWindowDelegate {
  private let model: AppModel

  init(model: AppModel) {
    self.model = model

    let panel = PickerPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )
    panel.contentView = NSHostingView(rootView: PickerContentView(model: model))
    panel.isFloatingPanel = true
    panel.becomesKeyOnlyIfNeeded = false
    PickerWindowPresentation.configure(panel, asPicker: true)

    super.init(window: panel)
    panel.delegate = self
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show(placement: PickerPlacement?) {
    guard let window else { return }

    let browserCount = model.browsers.browsers.count
    let contentSize = PickerWindowPresentation.size(browserCount: browserCount)
    let resolvedPlacement = placement ?? placementAtPointer(for: window)
    let frame: NSRect

    if let resolvedPlacement {
      frame = PickerWindowPresentation.anchoredFrame(
        for: window,
        contentSize: contentSize,
        browserCount: browserCount,
        placement: resolvedPlacement
      )
    } else {
      frame = window.frameRect(
        forContentRect: NSRect(origin: window.frame.origin, size: contentSize))
    }

    window.setFrame(frame, display: false)
    window.makeKeyAndOrderFront(nil)
  }

  func dismiss() {
    model.cancelRouting()
    window?.orderOut(nil)
  }

  func windowDidResignKey(_ notification: Notification) {
    guard model.hasPendingURLs, !model.isRouting else { return }
    dismiss()
  }

  private func placementAtPointer(for window: NSWindow) -> PickerPlacement? {
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

private final class PickerPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}

private struct PickerContentView: View {
  @Bindable var model: AppModel

  var body: some View {
    LinkPickerView(model: model)
      .alert(
        model.presentedError?.title ?? "Turnstile",
        isPresented: Binding(
          get: { model.presentedError != nil && model.hasPendingURLs },
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
