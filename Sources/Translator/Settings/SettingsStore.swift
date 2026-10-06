import Foundation
import Observation
import TranslatorCore

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
        self.settings = defaults.data(forKey: Self.key).map(Settings.decode(from:)) ?? Settings()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
