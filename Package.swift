// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "AppTranslatorSimple",
    platforms: [.macOS(.v15)],
    products: [
        // The app's name is set apart from the code's: it changes with the naming of the series,
        // the targets do not. Must match "name" in app.json (CFBundleExecutable).
        .executable(name: "AppTranslatorSimple", targets: ["Translator"]),
    ],
    targets: [
        // Settings, the translation pipeline, the methods' engines — no AppKit, imported by tests.
        .target(name: "TranslatorCore"),
        .executableTarget(
            name: "Translator",
            dependencies: ["TranslatorCore"]
        ),
        .testTarget(
            name: "TranslatorCoreTests",
            dependencies: ["TranslatorCore"]
        ),
    ]
)
