// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Turnstile",
  platforms: [
    .macOS(.v26)
  ],
  products: [
    .executable(name: "Turnstile", targets: ["Turnstile"])
  ],
  targets: [
    .executableTarget(
      name: "Turnstile",
      exclude: ["Resources"]
    ),
    .testTarget(
      name: "TurnstileTests",
      dependencies: ["Turnstile"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
