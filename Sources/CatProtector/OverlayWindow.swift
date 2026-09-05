import AppKit

/// A translucent, click-through banner shown near the top of the screen when
/// the lock turns on or off, so the user always knows what state they are in
/// and how to get out of it.
///
/// Everything is built and laid out once up front so `show` is just "set the
/// text and order front": no allocation, no animation, no waiting.
final class OverlayWindow: NSPanel {
    private let iconLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private var hideWorkItem: DispatchWorkItem?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .screenSaver
        ignoresMouseEvents = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // Shadows on translucent windows delay first display while macOS computes their shape.
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        contentView = makeContentView()
    }

    /// Forces the window server to create the window's backing store now, so
    /// the very first `show` is as fast as every later one. Call once at launch.
    func prewarm() {
        iconLabel.stringValue = "🐾"
        titleLabel.stringValue = "Cat mode on"
        subtitleLabel.stringValue = "Keyboard and trackpad are locked.\nPress ⌃⌥⌘L to unlock."
        layoutAndPosition()
        alphaValue = 0
        orderFrontRegardless()
        displayIfNeeded()
        orderOut(nil)
        alphaValue = 1
    }

    private func makeContentView() -> NSView {
        let effectView = NSVisualEffectView()
        effectView.material = .hudWindow
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.wantsLayer = true
        effectView.layer?.cornerRadius = 18
        effectView.layer?.cornerCurve = .continuous
        effectView.layer?.masksToBounds = true

        iconLabel.font = .systemFont(ofSize: 40)
        iconLabel.alignment = .center

        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.alignment = .center
        titleLabel.textColor = .labelColor

        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.maximumNumberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.preferredMaxLayoutWidth = 300

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .centerX
        textStack.spacing = 4

        let stack = NSStackView(views: [iconLabel, textStack])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 28, bottom: 22, right: 28)
        stack.translatesAutoresizingMaskIntoConstraints = false

        effectView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: effectView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
        ])
        return effectView
    }

    /// Shows the banner immediately and fades it out after `duration` seconds.
    func show(icon: String, title: String, subtitle: String, duration: TimeInterval) {
        hideWorkItem?.cancel()

        iconLabel.stringValue = icon
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        layoutAndPosition()

        // Appear instantly. Fading in feels slow when you are waiting for
        // confirmation that your keyboard is safe.
        alphaValue = 1
        orderFrontRegardless()

        let workItem = DispatchWorkItem { [weak self] in self?.hide() }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    func hide() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.alphaValue == 0 else { return }
            self.orderOut(nil)
        })
    }

    private func layoutAndPosition() {
        contentView?.layoutSubtreeIfNeeded()
        let size = contentView?.fittingSize ?? NSSize(width: 360, height: 120)
        setContentSize(size)

        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let x = screen.frame.midX - frame.width / 2
        let y = screen.frame.maxY - frame.height - 60
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
