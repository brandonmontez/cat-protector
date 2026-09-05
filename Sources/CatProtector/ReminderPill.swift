import AppKit

/// A small, click-through pill showing the unlock shortcut. The menu bar
/// normally carries that reminder, but full-screen apps hide the menu bar, so
/// this appears briefly whenever a blocked key press or click happens.
final class ReminderPill: NSPanel {
    init(screen: NSScreen, text: String) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 30),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .screenSaver
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 15
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: effectView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: effectView.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: effectView.topAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -6),
        ])
        contentView = effectView

        contentView?.layoutSubtreeIfNeeded()
        setContentSize(contentView?.fittingSize ?? NSSize(width: 200, height: 30))

        // Top-right corner, tucked under the menu bar, where nothing important happens in a video.
        let area = screen.visibleFrame
        setFrameOrigin(NSPoint(x: area.maxX - frame.width - 12, y: area.maxY - frame.height - 12))
    }

    func present() {
        alphaValue = 1
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
    }
}
