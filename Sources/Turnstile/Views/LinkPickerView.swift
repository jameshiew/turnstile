import AppKit
import SwiftUI

struct LinkPickerView: View {
  @Bindable var model: AppModel

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      linkSummary

      if model.browsers.browsers.isEmpty {
        emptyState
      } else {
        browserChoices
      }

      HStack {
        Text("Browsers appear in the order set in Turnstile.")
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Button("Cancel", role: .cancel) {
          cancel()
        }
        .keyboardShortcut(.cancelAction)
        .disabled(model.isRouting)
      }
    }
    .padding(24)
    .onKeyPress(.return) {
      guard let firstBrowser = model.browsers.browsers.first,
        !model.isRouting
      else {
        return .ignored
      }
      route(to: firstBrowser)
      return .handled
    }
  }

  private var linkSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: "link")
          .font(.title2.weight(.semibold))
          .foregroundStyle(.tint)

        Text(title)
          .font(.title2.weight(.semibold))

        if model.pendingURLs.count > 1 {
          Text("\(model.pendingURLs.count) links")
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
        }
      }

      Text(model.pendingURLs.first?.absoluteString ?? "")
        .font(.callout.monospaced())
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .truncationMode(.middle)
        .textSelection(.enabled)
    }
  }

  private var browserChoices: some View {
    ScrollView {
      LazyVStack(spacing: 8) {
        ForEach(Array(model.browsers.browsers.enumerated()), id: \.element.id) { entry in
          let index = entry.offset
          let browser = entry.element
          Button {
            route(to: browser)
          } label: {
            HStack(spacing: 12) {
              Image(nsImage: model.icon(for: browser))
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)

              Text(browser.displayName)
                .font(.body.weight(.medium))

              Spacer()

              if !model.isAvailable(browser) {
                Text("Not Found")
                  .font(.caption)
                  .foregroundStyle(.orange)
              } else if index < 9 {
                Text("\(index + 1)")
                  .font(.caption.monospacedDigit())
                  .foregroundStyle(.secondary)
                  .padding(.horizontal, 7)
                  .padding(.vertical, 3)
                  .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
              }
            }
            .padding(10)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .background(.quinary, in: RoundedRectangle(cornerRadius: 10))
          .overlay {
            RoundedRectangle(cornerRadius: 10)
              .stroke(.separator, lineWidth: 0.5)
          }
          .disabled(model.isRouting || !model.isAvailable(browser))
          .modifier(NumberShortcut(index: index))
        }
      }
    }
    .frame(minHeight: 190)
    .overlay {
      if model.isRouting {
        ProgressView("Opening…")
          .padding(14)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
      }
    }
  }

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No Browsers", systemImage: "globe")
    } description: {
      Text("Add a browser before routing this link.")
    } actions: {
      Button("Add Browser…") {
        Task { await model.addBrowser() }
      }
      .disabled(model.isAddingBrowser)
    }
    .frame(maxWidth: .infinity, minHeight: 220)
  }

  private var title: String {
    guard let url = model.pendingURLs.first else { return "Open Link" }
    return url.host ?? "Open Link"
  }

  private func route(to browser: Browser) {
    Task {
      let didOpen = await model.routePendingURLs(to: browser)
      if didOpen, !model.hasPendingURLs {
        NSApplication.shared.terminate(nil)
      }
    }
  }

  private func cancel() {
    model.cancelRouting()
    NSApplication.shared.terminate(nil)
  }
}

private struct NumberShortcut: ViewModifier {
  let index: Int

  func body(content: Content) -> some View {
    if index < 9 {
      content.keyboardShortcut(
        KeyEquivalent(Character(String(index + 1))),
        modifiers: []
      )
    } else {
      content
    }
  }
}
