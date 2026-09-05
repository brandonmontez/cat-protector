import Foundation
import os

/// Debug-level timing logs. They cost nothing unless someone is watching, and
/// make "it feels laggy" measurable:
///
///     log stream --predicate 'subsystem == "com.catprotector.CatProtector"' --level debug --style compact
enum Diagnostics {
    static let logger = Logger(subsystem: "com.catprotector.CatProtector", category: "lock")

    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()

    /// Milliseconds elapsed since an event's hardware timestamp.
    /// `CGEvent.timestamp` is in raw `mach_absolute_time` ticks.
    static func millisecondsSince(eventTimestamp: UInt64) -> Double {
        let ticks = mach_absolute_time() &- eventTimestamp
        return Double(ticks) * Double(timebase.numer) / Double(timebase.denom) / 1_000_000
    }
}
