import SwiftUI

struct BrowserSettingsView: View {
  @Bindable var model: AppModel
  @State private var selection: Browser.ID?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      header
      browserList
      defaultBrowserSection
      applicationSection
    }
    .padding(24)
    .task {
      model.refreshDefaultBrowserStatus()
    }
  }

  private var header: some View {
    HStack(spacing: 12) {
      Image(systemName: "arrow.triangle.branch")
        .font(.system(size: 26, weight: .semibold))
        .foregroundStyle(.tint)
        .frame(width: 36, height: 36)

      VStack(alignment: .leading, spacing: 2) {
        Text("Turnstile")
          .font(.title2.weight(.semibold))
        Text("Choose which browser opens each link.")
          .foregroundStyle(.secondary)
      }
    }
  }

  private var browserList: some View {
    GroupBox {
      VStack(spacing: 10) {
        if model.browsers.browsers.isEmpty {
          ContentUnavailableView(
            "No Browsers",
            systemImage: "globe",
            description: Text("Add the browsers you want Turnstile to offer.")
          )
          .frame(maxWidth: .infinity, minHeight: 190)
        } else {
          List(selection: $selection) {
            ForEach(model.browsers.browsers) { browser in
              BrowserRow(
                browser: browser,
                icon: model.icon(for: browser),
                isAvailable: model.isAvailable(browser)
              )
              .tag(browser.id)
            }
            .onMove(perform: model.moveBrowsers)
          }
          .listStyle(.inset(alternatesRowBackgrounds: true))
          .frame(minHeight: 190)
        }

        HStack(spacing: 8) {
          Button {
            Task { await model.addBrowser() }
          } label: {
            Label("Add Browser", systemImage: "plus")
          }
          .disabled(model.isAddingBrowser)

          Button {
            guard let selection else { return }
            model.removeBrowser(id: selection)
            self.selection = nil
          } label: {
            Label("Remove", systemImage: "minus")
          }
          .disabled(selection == nil)

          Spacer()

          Button {
            guard let selection else { return }
            model.moveBrowser(id: selection, direction: .towardStart)
          } label: {
            Image(systemName: "arrow.up")
          }
          .help("Move Up")
          .disabled(!canMoveSelection(.towardStart))

          Button {
            guard let selection else { return }
            model.moveBrowser(id: selection, direction: .towardEnd)
          } label: {
            Image(systemName: "arrow.down")
          }
          .help("Move Down")
          .disabled(!canMoveSelection(.towardEnd))
        }

        Text(
          "The order here is the order shown when a link arrives. Drag rows or use the arrow buttons."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(6)
    } label: {
      Text("Browsers")
        .font(.headline)
    }
  }

  private var defaultBrowserSection: some View {
    GroupBox {
      HStack(spacing: 12) {
        Label(
          model.isDefaultBrowser
            ? "Turnstile is your default browser"
            : "Turnstile is not your default browser",
          systemImage: model.isDefaultBrowser
            ? "checkmark.circle.fill"
            : "circle"
        )
        .foregroundStyle(model.isDefaultBrowser ? .green : .secondary)

        Spacer()

        if model.isSettingDefaultBrowser {
          ProgressView()
            .controlSize(.small)
        }

        Button("Set as Default Browser") {
          Task { await model.setAsDefaultBrowser() }
        }
        .disabled(
          model.isDefaultBrowser
            || model.isSettingDefaultBrowser
            || model.browsers.browsers.isEmpty
        )
      }
      .padding(6)
    }
  }

  private var applicationSection: some View {
    GroupBox {
      Toggle(
        "Show Turnstile in the Dock",
        isOn: Binding(
          get: { model.settings.showsDockIcon },
          set: { model.settings.setShowsDockIcon($0) }
        )
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(6)
    } label: {
      Text("Application")
        .font(.headline)
    }
  }

  private func canMoveSelection(_ direction: BrowserCollection.MoveDirection) -> Bool {
    guard let selection else { return false }
    return model.browsers.canMove(id: selection, direction: direction)
  }
}

private struct BrowserRow: View {
  let browser: Browser
  let icon: NSImage
  let isAvailable: Bool

  var body: some View {
    HStack(spacing: 10) {
      Image(nsImage: icon)
        .resizable()
        .scaledToFit()
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 1) {
        Text(browser.displayName)
          .lineLimit(1)
        Text(browser.bundleIdentifier)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer()

      if !isAvailable {
        Label("Not Found", systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
      }

      Image(systemName: "line.3.horizontal")
        .foregroundStyle(.tertiary)
        .accessibilityLabel("Drag to reorder")
    }
    .padding(.vertical, 3)
  }
}
