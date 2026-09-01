import AppKit
import Foundation
import Observation

@MainActor
protocol ApplicationActivationPolicySetting: AnyObject {
  @discardableResult
  func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool
}

extension NSApplication: ApplicationActivationPolicySetting {}

@MainActor
@Observable
final class ApplicationSettings {
  static let showsDockIconKey = "showsDockIcon"

  private(set) var showsDockIcon: Bool

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let application: any ApplicationActivationPolicySetting

  init(
    defaults: UserDefaults = .standard,
    application: any ApplicationActivationPolicySetting = NSApplication.shared
  ) {
    self.defaults = defaults
    self.application = application
    showsDockIcon = defaults.bool(forKey: Self.showsDockIconKey)
  }

  func applyDockIconPreference() {
    application.setActivationPolicy(showsDockIcon ? .regular : .accessory)
  }

  func setShowsDockIcon(_ showsDockIcon: Bool) {
    self.showsDockIcon = showsDockIcon
    defaults.set(showsDockIcon, forKey: Self.showsDockIconKey)
    applyDockIconPreference()
  }
}
