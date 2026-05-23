// swift-tools-version: 6.0
// Vireo — a notch-resident English coach for macOS.
//
// NOTE on building:
//   • `swift build` resolves dependencies and compiles the executable target.
//   • For the menubar / notch app to actually run with the right entitlements
//     (Accessibility, hardened runtime, signing), open Vireo.xcodeproj in
//     Xcode 16+ and build there. See README.md → "Development setup."

import PackageDescription

let package = Package(
    name: "Vireo",
    platforms: [
        // String form because PackageDescription's `.v26` enum case isn't
        // present in older toolchains; the string form is accepted everywhere.
        .macOS("26.0"),
    ],
    products: [
        .executable(name: "Vireo", targets: ["Vireo"]),
    ],
    dependencies: [
        .package(url: "https://github.com/MrKai77/DynamicNotchKit", from: "1.0.0"),
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
        .package(url: "https://github.com/open-spaced-repetition/swift-fsrs", from: "1.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "Vireo",
            dependencies: [
                .product(name: "DynamicNotchKit", package: "DynamicNotchKit"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "FSRS", package: "swift-fsrs"),
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Vireo"
        ),
        .testTarget(
            name: "VireoTests",
            dependencies: ["Vireo"],
            path: "Tests/VireoTests"
        ),
    ]
)
