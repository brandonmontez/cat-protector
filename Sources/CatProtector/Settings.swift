import Foundation

/// Thin wrapper around UserDefaults so the rest of the app never deals with raw keys.
final class Settings {
    static let shared = Settings()

    private enum Key {
        static let hotkey = "hotkey"
        static let showsBanner = "showsBanner"
        static let playsSound = "playsSound"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hotkey: Hotkey {
        get {
            guard let data = defaults.data(forKey: Key.hotkey),
                  let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data)
            else {
                return .defaultHotkey
            }
            return hotkey
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.hotkey)
            }
        }
    }

    /// Show the on-screen banner when locking and unlocking. Default on.
    var showsBanner: Bool {
        get { bool(forKey: Key.showsBanner, default: true) }
        set { defaults.set(newValue, forKey: Key.showsBanner) }
    }

    /// Play a short sound when locking and unlocking. Default on.
    var playsSound: Bool {
        get { bool(forKey: Key.playsSound, default: true) }
        set { defaults.set(newValue, forKey: Key.playsSound) }
    }

    private func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? defaultValue : defaults.bool(forKey: key)
    }
}
