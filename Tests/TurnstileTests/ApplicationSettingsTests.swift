import AppKit
import Foundation
import Testing

@testable import Turnstile

@MainActor
struct ApplicationSettingsTests {
  @Test
  func defaultsToHidingTheDockIcon() {
    let context = makeContext()
    defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

    context.settings.applyDockIconPreference()

    #expect(!context.settings.showsDockIcon)
    #expect(context.application.activationPolicies == [.accessory])
  }

  @Test
  func persistsAndAppliesDockIconVisibility() {
    let context = makeContext()
    defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

    context.settings.setShowsDockIcon(true)
    let reloadedSettings = ApplicationSettings(
      defaults: context.defaults,
      application: context.application
    )

    #expect(reloadedSettings.showsDockIcon)
    #expect(context.application.activationPolicies == [.regular])
  }

  private func makeContext() -> (
    settings: ApplicationSettings,
    application: ApplicationActivationPolicySpy,
    defaults: UserDefaults,
    suiteName: String
  ) {
    let suiteName = "TurnstileTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let application = ApplicationActivationPolicySpy()
    return (
      settings: ApplicationSettings(defaults: defaults, application: application),
      application: application,
      defaults: defaults,
      suiteName: suiteName
    )
  }
}

@MainActor
private final class ApplicationActivationPolicySpy: ApplicationActivationPolicySetting {
  private(set) var activationPolicies: [NSApplication.ActivationPolicy] = []

  func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool {
    activationPolicies.append(activationPolicy)
    return true
  }
}
