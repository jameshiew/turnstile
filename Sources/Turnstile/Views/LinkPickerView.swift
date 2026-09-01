import AppKit
import SwiftUI

struct LinkPickerView: View {
  @Bindable var model: AppModel
  @State private var hoveredBrowserID: Browser.ID?

  var body: some View {
    VStack(spacing: 0) {
      if model.browsers.browsers.isEmpty {
        emptyState
      } else {
        browserChoices
      }

      keyboardHint
        .padding(.top, 5)

      Divider()
        .padding(.vertical, 8)

      linkSummary
    }
    .padding(PickerWindowPresentation.contentPadding)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(.separator.opacity(0.7), lineWidth: 0.5)
    }
    .padding(PickerWindowPresentation.outerPadding)
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
    HStack(spacing: 10) {
      Image(systemName: "link")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.tint)
        .frame(width: 30, height: 30)
        .background(.tint.opacity(0.12), in: Circle())

      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 6) {
          Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)

          if model.pendingURLs.count > 1 {
            Text("\(model.pendingURLs.count)")
              .font(.caption2.monospacedDigit().weight(.medium))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 5)
              .padding(.vertical, 1)
              .background(.quaternary, in: Capsule())
          }
        }

        Text(model.pendingURLs.first?.absoluteString ?? "")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer(minLength: 4)

      Button {
        cancel()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 10, weight: .semibold))
          .frame(width: 24, height: 24)
          .background(.quaternary, in: Circle())
      }
      .buttonStyle(.plain)
      .keyboardShortcut(.cancelAction)
      .help("Cancel")
      .disabled(model.isRouting)
    }
  }

  private var browserChoices: some View {
    ScrollView(.horizontal) {
      LazyHStack(spacing: PickerWindowPresentation.browserChoiceSpacing) {
        ForEach(Array(model.browsers.browsers.enumerated()), id: \.element.id) { entry in
          let index = entry.offset
          let browser = entry.element
          let isAvailable = model.isAvailable(browser)

          Button {
            route(to: browser)
          } label: {
            BrowserChoice(
              browser: browser,
              icon: model.icon(for: browser),
              shortcut: index < 9 ? index + 1 : nil,
              isAvailable: isAvailable,
              isHighlighted: hoveredBrowserID == browser.id
                || (hoveredBrowserID == nil && index == 0)
            )
          }
          .buttonStyle(.plain)
          .disabled(model.isRouting || !isAvailable)
          .modifier(NumberShortcut(index: index))
          .onHover { isHovering in
            hoveredBrowserID = isHovering ? browser.id : nil
          }
          .accessibilityLabel("Open in \(browser.displayName)")
        }
      }
      .frame(minWidth: minimumChoiceRowWidth)
    }
    .scrollIndicators(.hidden)
    .frame(height: PickerWindowPresentation.browserChoiceHeight)
    .padding(.top, PickerWindowPresentation.browserChoicesTopPadding)
    .overlay {
      if model.isRouting {
        ProgressView()
          .controlSize(.small)
          .padding(10)
          .background(.regularMaterial, in: Circle())
      }
    }
  }

  private var emptyState: some View {
    HStack(spacing: 10) {
      Image(systemName: "globe")
        .font(.title3)
        .foregroundStyle(.secondary)

      Text("Add a browser before routing this link.")
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Button("Add Browser…") {
        Task { await model.addBrowser() }
      }
      .controlSize(.small)
      .disabled(model.isAddingBrowser)
    }
    .frame(
      height: PickerWindowPresentation.browserChoiceHeight
        + PickerWindowPresentation.browserChoicesTopPadding
    )
  }

  private var keyboardHint: some View {
    Group {
      if let firstBrowser = model.browsers.browsers.first {
        Text("Return: \(firstBrowser.displayName)  •  Numbers: choose  •  Esc: close")
      } else {
        Text("Esc: close")
      }
    }
    .font(.caption2)
    .foregroundStyle(.tertiary)
    .lineLimit(1)
    .minimumScaleFactor(0.8)
    .frame(maxWidth: .infinity, alignment: .center)
  }

  private var minimumChoiceRowWidth: CGFloat {
    PickerWindowPresentation.size(browserCount: model.browsers.browsers.count).width
      - 2 * PickerWindowPresentation.panelContentInset
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

private struct BrowserChoice: View {
  let browser: Browser
  let icon: NSImage
  let shortcut: Int?
  let isAvailable: Bool
  let isHighlighted: Bool

  var body: some View {
    VStack(spacing: 4) {
      ZStack(alignment: .topTrailing) {
        Image(nsImage: icon)
          .resizable()
          .scaledToFit()
          .frame(
            width: PickerWindowPresentation.browserIconSize,
            height: PickerWindowPresentation.browserIconSize
          )

        if let shortcut {
          Text("\(shortcut)")
            .font(.system(size: 9, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(width: 16, height: 16)
            .background(.regularMaterial, in: Circle())
            .offset(x: 6, y: -4)
        }
      }

      Text(browser.displayName)
        .font(.caption)
        .lineLimit(1)
        .truncationMode(.tail)
    }
    .frame(
      width: PickerWindowPresentation.browserChoiceWidth,
      height: PickerWindowPresentation.browserChoiceHeight,
      alignment: .top
    )
    .background(
      isHighlighted ? Color.accentColor.opacity(0.12) : Color.clear,
      in: RoundedRectangle(cornerRadius: 12, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(
          isHighlighted ? Color.accentColor.opacity(0.45) : Color.clear,
          lineWidth: 1
        )
    }
    .opacity(isAvailable ? 1 : 0.45)
    .overlay(alignment: .topLeading) {
      if !isAvailable {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.caption2)
          .foregroundStyle(.orange)
          .padding(5)
      }
    }
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
