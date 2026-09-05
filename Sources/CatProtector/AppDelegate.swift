import AppKit
import AVFoundation
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, AVAudioPlayerDelegate {
    static let appName = "Cat Protector"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    private let settings = Settings.shared
    private lazy var inputLock = InputLock(hotkey: settings.hotkey)
    private let overlay = OverlayWindow()

    private var statusItem: NSStatusItem!
    private let lockMenuItem = NSMenuItem()
    private let shortcutMenuItem = NSMenuItem()
    private let bannerMenuItem = NSMenuItem()
    private let soundMenuItem = NSMenuItem()
    private let loginMenuItem = NSMenuItem()
    private let permissionMenuItem = NSMenuItem()

    // Everything the toggle path touches is created once, up front, so that
    // flipping the lock never allocates, loads from disk, or talks to another process.
    private let unlockedIcon = AppDelegate.makeStatusIcon(symbol: "pawprint", description: "Input unlocked")
    private lazy var lockSound = makePlayer(systemSound: "Purr")
    private lazy var unlockSound = makePlayer(systemSound: "Pop")
    /// Audio starts on this queue so a slow first start can never hold up the
    /// banner and icon, which are committed when the main thread's run loop turns.
    private let soundQueue = DispatchQueue(label: "com.catprotector.CatProtector.sound", qos: .userInteractive)

    private var recorderWindow: ShortcutRecorderWindow?
    private var permissionTimer: Timer?

    /// Fallback reminder for full-screen apps, where the menu bar is hidden:
    /// one pill per screen, shown only for a moment after a blocked key press or click.
    private var reminderPills: [ReminderPill] = []
    private var hidePillsWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpStatusItem()
        inputLock.onLockChanged = { [weak self] locked in
            self?.lockStateDidChange(locked)
        }
        inputLock.onBlockedInput = { [weak self] in
            self?.someoneTouchedTheKeyboard()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        overlay.prewarm()
        warmUpAudio()
        startWhenPermitted()
    }

    func applicationWillTerminate(_ notification: Notification) {
        inputLock.stop()
    }

    // MARK: - Permission + tap startup

    private func startWhenPermitted() {
        if Permissions.hasAccessibilityAccess(promptIfNeeded: true) {
            startTap()
            return
        }

        // macOS has just shown its own "would like to control this computer"
        // dialog and added the app to the Accessibility list.
        // Poll until the user flips the switch in System Settings, then start.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            if Permissions.hasAccessibilityAccess(promptIfNeeded: false) {
                timer.invalidate()
                self.permissionTimer = nil
                self.startTap()
            }
        }
        refreshMenu()
    }

    private func startTap() {
        do {
            try inputLock.start()
        } catch {
            let alert = NSAlert()
            alert.messageText = "\(Self.appName) could not start"
            alert.informativeText = error.localizedDescription
            alert.addButton(withTitle: "Open Accessibility Settings")
            alert.addButton(withTitle: "Quit")
            if alert.runModal() == .alertFirstButtonReturn {
                Permissions.openAccessibilitySettings()
            } else {
                NSApp.terminate(nil)
            }
        }
        refreshMenu()
    }

    // MARK: - Status item and menu

    private static func makeStatusIcon(symbol: String, description: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)
        image?.isTemplate = true
        return image
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.toolTip = Self.appName

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self

        lockMenuItem.target = self
        lockMenuItem.action = #selector(toggleLock)
        menu.addItem(lockMenuItem)

        shortcutMenuItem.target = self
        shortcutMenuItem.action = #selector(changeShortcut)
        menu.addItem(shortcutMenuItem)

        menu.addItem(.separator())

        bannerMenuItem.title = "Show On-Screen Banner"
        bannerMenuItem.target = self
        bannerMenuItem.action = #selector(toggleBanner)
        menu.addItem(bannerMenuItem)

        soundMenuItem.title = "Play Sound"
        soundMenuItem.target = self
        soundMenuItem.action = #selector(toggleSound)
        menu.addItem(soundMenuItem)

        loginMenuItem.title = "Start at Login"
        loginMenuItem.target = self
        loginMenuItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(loginMenuItem)

        menu.addItem(.separator())

        permissionMenuItem.title = "Grant Accessibility Access…"
        permissionMenuItem.target = self
        permissionMenuItem.action = #selector(openAccessibilitySettings)
        menu.addItem(permissionMenuItem)

        let aboutItem = NSMenuItem(title: "About \(Self.appName)", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit \(Self.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshMenu()
    }

    /// The menu is refreshed right before it opens, so slow lookups such as the
    /// login item status never run on the lock/unlock path.
    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenu()
    }

    private func refreshMenu() {
        let locked = inputLock.isLocked
        let running = inputLock.isRunning

        updateStatusIcon(locked: locked)
        lockMenuItem.title = locked ? "Unlock Keyboard & Trackpad" : "Lock Keyboard & Trackpad"
        lockMenuItem.isEnabled = running
        shortcutMenuItem.title = "Shortcut: \(inputLock.hotkey.displayString)…"
        bannerMenuItem.state = settings.showsBanner ? .on : .off
        soundMenuItem.state = settings.playsSound ? .on : .off
        loginMenuItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        permissionMenuItem.isHidden = running
    }

    /// Unlocked: just the paw print. Locked: the shortcut itself, right there
    /// in the menu bar where you would look for it.
    private func updateStatusIcon(locked: Bool) {
        guard let button = statusItem.button else { return }
        let shortcut = inputLock.hotkey.displayString

        if locked {
            // Text only: the shortcut glyphs are easier to read without an icon crowding them.
            statusItem.length = NSStatusItem.variableLength
            button.image = nil
            button.imagePosition = .noImage
            button.title = "\(shortcut) to unlock"
        } else {
            statusItem.length = NSStatusItem.squareLength
            button.image = unlockedIcon
            button.imagePosition = unlockedIcon == nil ? .noImage : .imageOnly
            button.title = unlockedIcon == nil ? "🐾" : ""
        }
        button.toolTip = locked
            ? "\(Self.appName): locked. Press \(shortcut) to unlock."
            : "\(Self.appName): unlocked. Press \(shortcut) to lock."
    }

    // MARK: - Lock state

    /// Runs on the main thread the instant the lock flips. Only cheap,
    /// pre-built work happens here so the feedback is effectively immediate.
    private func lockStateDidChange(_ locked: Bool) {
        Diagnostics.logger.debug("feedback starting on main thread; locked=\(locked)")
        updateStatusIcon(locked: locked)
        lockMenuItem.title = locked ? "Unlock Keyboard & Trackpad" : "Lock Keyboard & Trackpad"

        if !locked {
            hideReminderPills()
        }

        if settings.showsBanner {
            let shortcut = inputLock.hotkey.displayString
            if locked {
                overlay.show(
                    icon: "🐾",
                    title: "Cat mode on",
                    subtitle: "Keyboard and trackpad are locked.\nPress \(shortcut) to unlock.",
                    duration: 5
                )
            } else {
                overlay.show(
                    icon: "😺",
                    title: "Unlocked",
                    subtitle: "Keyboard and trackpad are back.",
                    duration: 1.5
                )
            }
            Diagnostics.logger.debug("banner shown")
        }

        if settings.playsSound {
            let player = locked ? lockSound : unlockSound
            soundQueue.async {
                player?.volume = 1
                player?.currentTime = 0
                player?.play()
                Diagnostics.logger.debug("sound started")
            }
        }
    }

    // MARK: - Reminder pills

    /// Someone pressed a key or clicked while locked. The menu bar already
    /// shows the shortcut, but a full-screen app hides the menu bar, so flash
    /// the reminder on every screen for a few seconds.
    private func someoneTouchedTheKeyboard() {
        if reminderPills.isEmpty {
            let text = "🔒  \(inputLock.hotkey.displayString) to unlock"
            reminderPills = NSScreen.screens.map { ReminderPill(screen: $0, text: text) }
            reminderPills.forEach { $0.present() }
        }
        hidePillsWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.hideReminderPills() }
        hidePillsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    private func hideReminderPills() {
        hidePillsWorkItem?.cancel()
        hidePillsWorkItem = nil
        reminderPills.forEach { $0.dismiss() }
        reminderPills = []
    }

    @objc private func screensChanged() {
        hideReminderPills()
    }

    // MARK: - Sounds

    /// AVAudioPlayer kept primed with `prepareToPlay` starts noticeably faster
    /// than NSSound, which spins up playback from scratch every time.
    private func makePlayer(systemSound name: String) -> AVAudioPlayer? {
        let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff")
        guard let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.delegate = self
        player.prepareToPlay()
        return player
    }

    /// The very first playback after launch can take up to a second while
    /// Core Audio brings the output device up. Do that silently now instead
    /// of on the user's first lock.
    private func warmUpAudio() {
        let players = [lockSound, unlockSound]
        soundQueue.async {
            for player in players {
                player?.volume = 0
                player?.play()
                player?.stop()
                player?.currentTime = 0
                player?.volume = 1
                player?.prepareToPlay()
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Re-prime so the next toggle is just as fast.
        player.volume = 1
        player.prepareToPlay()
    }

    // MARK: - Actions

    @objc private func toggleLock() {
        inputLock.toggle()
    }

    @objc private func changeShortcut() {
        if let existing = recorderWindow {
            existing.present()
            return
        }

        inputLock.isPassthrough = true
        let window = ShortcutRecorderWindow(current: inputLock.hotkey)
        window.onRecorded = { [weak self] hotkey in
            guard let self else { return }
            self.settings.hotkey = hotkey
            self.inputLock.hotkey = hotkey
            self.finishRecording()
        }
        window.onCancelled = { [weak self] in
            self?.finishRecording()
        }
        recorderWindow = window
        window.present()
    }

    private func finishRecording() {
        inputLock.isPassthrough = false
        recorderWindow = nil
        refreshMenu()
    }

    @objc private func toggleBanner() {
        settings.showsBanner.toggle()
    }

    @objc private func toggleSound() {
        settings.playsSound.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not change the login item"
            alert.informativeText = """
            \(error.localizedDescription)

            Start at Login only works when \(Self.appName) is running from a proper app bundle \
            (for example from your Applications folder).
            """
            alert.runModal()
        }
    }

    @objc private func openAccessibilitySettings() {
        Permissions.openAccessibilitySettings()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Locks your keyboard and trackpad so your cat can nap on them in peace.\n\nFree and open source under the MIT License.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.labelColor]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: Self.appName,
            .applicationVersion: Self.version,
            .credits: credits,
        ])
    }
}
