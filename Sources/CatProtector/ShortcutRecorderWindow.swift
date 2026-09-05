import AppKit
import Carbon.HIToolbox

/// A tiny window that waits for the user to press a key combination and
/// reports it back as a `Hotkey`.
final class ShortcutRecorderWindow: NSWindow {
    var onRecorded: ((Hotkey) -> Void)?
    var onCancelled: (() -> Void)?

    private let recorderView = RecorderView()
    private var finished = false

    init(current: Hotkey) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "Change Shortcut"
        isReleasedWhenClosed = false
        level = .floating
        center()

        recorderView.currentShortcut = current
        recorderView.onKeyPress = { [weak self] hotkey in
            self?.finish(with: hotkey)
        }
        recorderView.onEscape = { [weak self] in
            self?.cancel()
        }
        contentView = recorderView
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        makeFirstResponder(recorderView)
    }

    override func close() {
        if !finished {
            finished = true
            onCancelled?()
        }
        super.close()
    }

    private func finish(with hotkey: Hotkey) {
        guard !finished else { return }
        finished = true
        onRecorded?(hotkey)
        super.close()
    }

    private func cancel() {
        close()
    }
}

private final class RecorderView: NSView {
    var currentShortcut: Hotkey = .defaultHotkey {
        didSet { updateLabels() }
    }
    var onKeyPress: ((Hotkey) -> Void)?
    var onEscape: (() -> Void)?

    private let heading = NSTextField(labelWithString: "Press your new shortcut")
    private let preview = NSTextField(labelWithString: "")
    private let hint = NSTextField(wrappingLabelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)

        heading.font = .systemFont(ofSize: 15, weight: .semibold)
        heading.alignment = .center

        preview.font = .monospacedSystemFont(ofSize: 28, weight: .medium)
        preview.alignment = .center

        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor
        hint.alignment = .center
        hint.preferredMaxLayoutWidth = 330

        let stack = NSStackView(views: [heading, preview, hint])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        updateLabels()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var acceptsFirstResponder: Bool { true }

    private func updateLabels(modifiers: HotkeyModifiers = []) {
        preview.stringValue = modifiers.isEmpty ? currentShortcut.displayString : modifiers.symbols + "…"
        hint.stringValue = "Include at least one of ⌃ ⌥ ⌘ so a stray paw cannot trigger it.\nPress Esc to keep \(currentShortcut.displayString)."
    }

    override func flagsChanged(with event: NSEvent) {
        updateLabels(modifiers: HotkeyModifiers(nsFlags: event.modifierFlags))
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = HotkeyModifiers(nsFlags: event.modifierFlags)

        if event.keyCode == UInt16(kVK_Escape), modifiers.isEmpty {
            onEscape?()
            return
        }

        guard modifiers.isSafeForShortcut else {
            NSSound.beep()
            hint.stringValue = "That shortcut needs ⌃, ⌥, or ⌘. Try again, or press Esc to cancel."
            return
        }

        onKeyPress?(Hotkey(keyCode: event.keyCode, modifiers: modifiers))
    }
}
