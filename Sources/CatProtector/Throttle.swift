import Foundation

/// Lets an action through at most once per interval. Used so a cat walking
/// across the keyboard does not flood the main thread with "input blocked"
/// notifications.
struct Throttle {
    let interval: TimeInterval
    private var lastAllowed: TimeInterval?

    init(interval: TimeInterval) {
        self.interval = interval
    }

    /// Returns true if enough time has passed since the last allowed call.
    mutating func allow(at time: TimeInterval) -> Bool {
        if let last = lastAllowed, time - last < interval {
            return false
        }
        lastAllowed = time
        return true
    }
}
