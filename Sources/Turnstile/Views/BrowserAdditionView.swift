import SwiftUI

struct BrowserAdditionView: View {
  @Bindable var model: AppModel
  let addition: BrowserAddition
  @State private var selectedIDs = Set<Browser.ID>()

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Add \(addition.browser.displayName)")
        .font(.title2.weight(.semibold))
      Text("Choose the profiles you want to offer when a link arrives.")
        .foregroundStyle(.secondary)

      List {
        Section("Browser") {
          choice(addition.browser, subtitle: "Use the last-used profile")
        }
        Section("Profiles") {
          ForEach(addition.profiles) { browser in
            choice(browser, subtitle: browser.profile?.directory ?? "")
          }
          if let message = addition.message {
            Text(message)
              .font(.callout)
              .foregroundStyle(.secondary)
          }
        }
      }
      .listStyle(.inset)
      .frame(height: 260)

      if let error = model.browserAdditionError {
        Text(error)
          .foregroundStyle(.red)
      }

      HStack {
        Spacer()
        Button("Cancel", action: model.dismissBrowserAddition)
          .keyboardShortcut(.cancelAction)
        Button("Add Selected") {
          model.addSelectedBrowsers(ids: selectedIDs)
        }
        .keyboardShortcut(.defaultAction)
        .disabled(selectedIDs.isEmpty)
      }
    }
    .padding(24)
    .frame(width: 460)
  }

  private func choice(_ browser: Browser, subtitle: String) -> some View {
    let isAdded = model.browsers.browsers.contains { $0.id == browser.id }
    return HStack {
      Toggle(
        isOn: Binding(
          get: { selectedIDs.contains(browser.id) },
          set: { selected in
            if selected {
              selectedIDs.insert(browser.id)
            } else {
              selectedIDs.remove(browser.id)
            }
          }
        )
      ) {
        VStack(alignment: .leading, spacing: 2) {
          Text(browser.profile?.name ?? browser.displayName)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .toggleStyle(.checkbox)
      .disabled(isAdded)

      Spacer()
      if isAdded {
        Text("Added")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.vertical, 4)
  }
}

extension View {
  func browserAdditionSheet(
    model: AppModel, presentation: BrowserAddition.Presentation
  ) -> some View {
    sheet(
      item: Binding(
        get: {
          model.browserAddition?.presentation == presentation ? model.browserAddition : nil
        },
        set: { value in
          if value == nil, model.browserAddition?.presentation == presentation {
            model.dismissBrowserAddition()
          }
        }
      )
    ) { addition in
      BrowserAdditionView(model: model, addition: addition)
    }
  }
}
