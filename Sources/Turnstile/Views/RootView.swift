import AppKit
import SwiftUI

struct RootView: View {
  @Bindable var model: AppModel

  var body: some View {
    Group {
      if model.hasPendingURLs {
        LinkPickerView(model: model)
      } else {
        BrowserSettingsView(model: model)
      }
    }
    .frame(
      minWidth: 520,
      minHeight: model.hasPendingURLs ? 300 : 420
    )
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
          ?? NSApplication.shared.windows.first(where: \.isVisible)
      else {
        return
      }

      let contentSize = NSSize(
        width: 560,
        height: model.hasPendingURLs ? 340 : 450
      )
      let targetFrame = window.frameRect(
        forContentRect: NSRect(origin: .zero, size: contentSize)
      )
      var frame = window.frame
      frame.origin.y += frame.height - targetFrame.height
      frame.size = targetFrame.size
      window.setFrame(frame, display: true, animate: true)
    }
  }
}
