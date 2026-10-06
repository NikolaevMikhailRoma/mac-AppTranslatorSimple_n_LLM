// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "LLMTranslator",
    platforms: [.macOS(.v15)],
    targets: [
        // Config, language detection, prompt and API client — no AppKit, imported by tests.
        .target(name: "LLMTranslatorCore"),
        .executableTarget(
            name: "LLMTranslator",
            dependencies: ["LLMTranslatorCore"]
        ),
        .testTarget(
            name: "LLMTranslatorTests",
            dependencies: ["LLMTranslatorCore"]
        ),
    ]
)
