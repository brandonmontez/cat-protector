import CoreGraphics
import Foundation

/// The decision-making heart of the app, kept free of any system wiring so it
/// can be unit tested. Given a stream of input events it decides, for each one,
/// whether to let it through, drop it, or treat it as the toggle shortcut.
struct LockEngine {
    enum Action: Equatable {
        /// Deliver the event to the system as normal.
        case pass
        /// Drop the event so no app ever sees it.
        case swallow
        /// The toggle shortcut was pressed: flip the lock and drop the event.
        case toggle
    }

    private(set) var isLocked = false
    var hotkey: Hotkey

    /// While true every event passes untouched. Used while the user is
    /// recording a new shortcut so their key presses reach the recorder.
    var isPassthrough = false

    /// Modifier state as reported by the most recent flagsChanged event.
    /// Kept as a fallback in case a key event's own flags are ever stale.
    private(set) var trackedFlags: CGEventFlags = []

    /// Key code whose next keyUp should be dropped, so an app never receives
    /// a lonely keyUp for the shortcut key after we swallowed its keyDown.
    private var pendingKeyUp: Int64?

    init(hotkey: Hotkey) {
        self.hotkey = hotkey
    }

    mutating func setLocked(_ locked: Bool) {
        isLocked = locked
    }

    mutating func toggle() {
        isLocked.toggle()
    }

    /// Decides what to do with one event. `keyCode` and `isRepeat` are only
    /// meaningful for keyboard events and can be zero/false otherwise.
    mutating func process(type: CGEventType, keyCode: Int64, flags: CGEventFlags, isRepeat: Bool) -> Action {
        if isPassthrough {
            return .pass
        }

        switch type {
        case .flagsChanged:
            trackedFlags = flags

        case .keyDown:
            let isHotkey = hotkey.matches(keyCode: keyCode, flags: flags)
                || hotkey.matches(keyCode: keyCode, flags: trackedFlags)
            if isHotkey {
                // Holding the key down auto-repeats; only the first press counts.
                if isRepeat {
                    return .swallow
                }
                pendingKeyUp = keyCode
                isLocked.toggle()
                return .toggle
            }

        case .keyUp:
            if let pending = pendingKeyUp, pending == keyCode {
                pendingKeyUp = nil
                return .swallow
            }

        default:
            break
        }

        return isLocked ? .swallow : .pass
    }
}
