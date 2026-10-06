import Foundation
import Observation
import LLMTranslatorCore

/// What the user set in Settings, kept as one JSON value in UserDefaults.
@MainActor
@Observable
final class SettingsStore {
    private static let key = "Settings"

    @ObservationIgnored private let defaults: UserDefaults

    var settings: Settings {
        didSet {
            guard settings != oldValue else { return }
            save()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let stored = try? JSONDecoder().decode(Settings.self, from: data) {
            self.settings = stored
        } else {
            self.settings = Settings()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
