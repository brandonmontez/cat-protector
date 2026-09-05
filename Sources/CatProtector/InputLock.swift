import CoreGraphics
import Foundation

/// Installs a system-wide event tap and feeds every keyboard, mouse, trackpad,
/// and media-key event through the `LockEngine`.
///
/// The tap runs on its own thread so a busy main thread (a dialog, a menu) can
/// never delay input handling. All mutable state lives behind a lock.
final class InputLock {
    enum Error: Swift.Error, LocalizedError {
        case tapCreationFailed

        var errorDescription: String? {
            switch self {
            case .tapCreationFailed:
                return "Could not install the input event tap. Make sure Cat Protector has Accessibility access in System Settings."
            }
        }
    }

    /// Called on the main thread whenever the lock state flips.
    var onLockChanged: ((Bool) -> Void)?

    /// Called on the main thread, at most a couple of times a second, when a
    /// key press or click is blocked. Someone is touching the keyboard.
    var onBlockedInput: (() -> Void)?
    private var blockedInputThrottle = Throttle(interval: 0.5)

    private let stateLock = NSLock()
    private var engine: LockEngine

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tapThread: Thread?
    private var tapRunLoop: CFRunLoop?

    init(hotkey: Hotkey) {
        engine = LockEngine(hotkey: hotkey)
    }

    deinit {
        stop()
    }

    // MARK: - State

    var isLocked: Bool {
        stateLock.withLock { engine.isLocked }
    }

    var isRunning: Bool {
        stateLock.withLock { tap != nil }
    }

    var hotkey: Hotkey {
        get { stateLock.withLock { engine.hotkey } }
        set { stateLock.withLock { engine.hotkey = newValue } }
    }

    /// While true, every event passes straight through (see `LockEngine.isPassthrough`).
    var isPassthrough: Bool {
        get { stateLock.withLock { engine.isPassthrough } }
        set { stateLock.withLock { engine.isPassthrough = newValue } }
    }

    func lock() {
        setLocked(true)
    }

    func unlock() {
        setLocked(false)
    }

    func toggle() {
        setLocked(!isLocked)
    }

    private func setLocked(_ locked: Bool) {
        let changed: Bool = stateLock.withLock {
            // Never claim to be locked when there is no tap to enforce it.
            guard locked != engine.isLocked, !locked || tap != nil else { return false }
            engine.setLocked(locked)
            return true
        }
        if changed {
            notifyLockChanged(locked)
        }
    }

    private func notifyLockChanged(_ locked: Bool) {
        if Thread.isMainThread {
            onLockChanged?(locked)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onLockChanged?(locked)
            }
        }
    }

    // MARK: - Event tap lifecycle

    func start() throws {
        try stateLock.withLock {
            guard tap == nil else { return }

            // Listen to everything: keys, modifiers, mouse, scroll, gestures,
            // and the "system defined" events that carry media and volume keys.
            let allEvents: CGEventMask = ~0
            let userInfo = Unmanaged.passUnretained(self).toOpaque()

            guard let tap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: allEvents,
                callback: inputLockEventCallback,
                userInfo: userInfo
            ) else {
                throw Error.tapCreationFailed
            }

            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            self.tap = tap
            self.runLoopSource = source

            let ready = DispatchSemaphore(value: 0)
            let thread = Thread { [weak self] in
                guard let self, let source else { ready.signal(); return }
                CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
                self.tapRunLoop = CFRunLoopGetCurrent()
                CGEvent.tapEnable(tap: tap, enable: true)
                ready.signal()
                CFRunLoopRun()
            }
            thread.name = "CatProtector.EventTap"
            thread.qualityOfService = .userInteractive
            self.tapThread = thread
            thread.start()
            ready.wait()
        }
    }

    func stop() {
        unlock()
        stateLock.withLock {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: false)
                CFMachPortInvalidate(tap)
            }
            if let runLoop = tapRunLoop {
                CFRunLoopStop(runLoop)
            }
            tap = nil
            runLoopSource = nil
            tapRunLoop = nil
            tapThread = nil
        }
    }

    // MARK: - Event handling (runs on the tap thread)

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // macOS disables a tap it thinks is unresponsive. Re-enable and carry on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            stateLock.withLock {
                if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            }
            return Unmanaged.passUnretained(event)
        }

        let isKeyboardEvent = type == .keyDown || type == .keyUp
        let keyCode = isKeyboardEvent ? event.getIntegerValueField(.keyboardEventKeycode) : 0
        let isRepeat = type == .keyDown && event.getIntegerValueField(.keyboardEventAutorepeat) != 0

        let (action, nowLocked): (LockEngine.Action, Bool) = stateLock.withLock {
            let action = engine.process(type: type, keyCode: keyCode, flags: event.flags, isRepeat: isRepeat)
            return (action, engine.isLocked)
        }

        switch action {
        case .pass:
            return Unmanaged.passUnretained(event)
        case .swallow:
            if Self.isDeliberateInput(type) {
                let shouldNotify = stateLock.withLock {
                    blockedInputThrottle.allow(at: ProcessInfo.processInfo.systemUptime)
                }
                if shouldNotify {
                    DispatchQueue.main.async { [weak self] in self?.onBlockedInput?() }
                }
            }
            return nil
        case .toggle:
            let age = Diagnostics.millisecondsSince(eventTimestamp: event.timestamp)
            Diagnostics.logger.debug("shortcut seen \(age, format: .fixed(precision: 1)) ms after the key was pressed; locked=\(nowLocked)")
            notifyLockChanged(nowLocked)
            return nil
        }
    }
}

extension InputLock {
    /// Key presses and clicks, as opposed to the mouse-move and modifier noise
    /// a resting paw produces.
    fileprivate static func isDeliberateInput(_ type: CGEventType) -> Bool {
        switch type {
        case .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown:
            return true
        default:
            return false
        }
    }
}

/// C-compatible trampoline into `InputLock.handle`.
private let inputLockEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let inputLock = Unmanaged<InputLock>.fromOpaque(userInfo).takeUnretainedValue()
    return inputLock.handle(type: type, event: event)
}
