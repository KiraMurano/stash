import Foundation

/// When Stash asks GitHub about a new version: the first time ten seconds after the app has
/// settled, then once a day. The time of the last check is kept, so ten restarts in a row make
/// one request, not ten.
struct UpdateSchedule {
    static let interval: TimeInterval = 24 * 60 * 60
    /// The first check waits, so it never competes with the app's own start.
    static let launchDelay: TimeInterval = 10

    private enum Keys {
        static let automatic = "CheckForUpdatesAutomatically"
        static let lastCheck = "LastUpdateCheck"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.automatic) == nil {
            defaults.set(true, forKey: Keys.automatic)
        }
    }

    var isAutomatic: Bool {
        get { defaults.bool(forKey: Keys.automatic) }
        nonmutating set { defaults.set(newValue, forKey: Keys.automatic) }
    }

    var lastCheck: Date? {
        get { defaults.object(forKey: Keys.lastCheck) as? Date }
        nonmutating set { defaults.set(newValue, forKey: Keys.lastCheck) }
    }

    func isDue(now: Date) -> Bool {
        guard isAutomatic else { return false }
        guard let lastCheck else { return true }
        // A mark from the future means the clock was moved; it must not lock checks out forever.
        let elapsed = now.timeIntervalSince(lastCheck)
        return elapsed >= Self.interval || elapsed < 0
    }
}
