import AppKit

/// The app's name as the bundle states it (from app.json), so menus and buttons follow a rename.
let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "AppTranslatorSimple"

/// A value from app.json, which build.sh copies into Info.plist.
/// A debug build has no bundle; Scripts/screenshots.sh passes the values in as environment variables.
private func appConfig(_ key: String, env: String) -> String? {
    (Bundle.main.infoDictionary?[key] as? String) ?? ProcessInfo.processInfo.environment[env]
}

let appVersion = appConfig("CFBundleShortVersionString", env: "APP_VERSION") ?? "dev"

/// Nil without "repository" in app.json; the links are then left out.
enum AppLinks {
    static let repository = appConfig("AppRepository", env: "APP_REPOSITORY").flatMap { URL(string: $0) }
    static let changelog = repository?.appending(path: "blob/main/CHANGELOG.md")
}

/// The standard macOS About window, with a line about the app and links under the version.
@MainActor
enum AboutPanel {
    static func show() {
        let credits = NSMutableAttributedString(
            string: "Menu bar translator: copy twice (⌘C C).",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        )
        if let changelog = AppLinks.changelog, let repository = AppLinks.repository {
            credits.append(NSAttributedString(string: "\n"))
            credits.append(link("What's new", changelog))
            credits.append(NSAttributedString(string: " · ", attributes: [.font: NSFont.systemFont(ofSize: 11)]))
            credits.append(link("Source on GitHub", repository))
        }
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        credits.addAttribute(.paragraphStyle, value: centered, range: NSRange(location: 0, length: credits.length))

        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
            .version: "",    // CFBundleVersion equals the short version; do not print it twice
        ])
    }

    private static func link(_ title: String, _ url: URL) -> NSAttributedString {
        NSAttributedString(string: title, attributes: [.link: url, .font: NSFont.systemFont(ofSize: 11)])
    }
}
