import AppKit

/// Small non-activating status pill that remains visible over full-screen apps.
enum FeedbackCenter {
    private static var panel: NSPanel?
    private static var label: NSTextField?
    private static var hideWorkItem: DispatchWorkItem?

    // mira.hoverEitherMode.standalone.v1
    static func dismissWhenModesOff() {
        DispatchQueue.main.async {
            let eitherModeOn =
                UserDefaults.standard.bool(forKey: "mira.actionsEnabled")
                || UserDefaults.standard.bool(forKey: "mira.cursor.feedbackActive")

            guard !eitherModeOn else { return }
            hideWorkItem?.cancel()
            hideWorkItem = nil
            panel?.orderOut(nil)
        }
    }

    static func show(_ message: String, kind: Kind = .neutral) {
        let modesAllowFeedback =
            UserDefaults.standard.bool(forKey: "mira.actionsEnabled")
            || UserDefaults.standard.bool(forKey: "mira.cursor.feedbackActive")

        UserDefaults.standard.set(
            modesAllowFeedback,
            forKey: "mira.feedbackEnabled"
        )
        guard modesAllowFeedback else { return }

        DispatchQueue.main.async {
            let target = panel ?? makePanel()
            panel = target

            label?.stringValue = message
            label?.textColor = color(for: kind)

            resize(for: message)
            target.orderFrontRegardless()

            hideWorkItem?.cancel()
            let work = DispatchWorkItem {
                panel?.orderOut(nil)
            }
            hideWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 3.0, execute: work
            )
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 46),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 23
        background.layer?.masksToBounds = true
        background.translatesAutoresizingMaskIntoConstraints = false

        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .white

        panel.contentView = background
        background.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                equalTo: background.leadingAnchor, constant: 22
            ),
            label.trailingAnchor.constraint(
                equalTo: background.trailingAnchor, constant: -22
            ),
            label.centerYAnchor.constraint(
                equalTo: background.centerYAnchor
            ),
            background.heightAnchor.constraint(equalToConstant: 46)
        ])

        position(panel)
        self.label = label
        return panel
    }

    private static func resize(for message: String) {
        guard let panel, label != nil else { return }

        let font = NSFont.systemFont(ofSize: 15, weight: .medium)
        let width = (message as NSString).size(
            withAttributes: [.font: font]
        ).width

        let contentWidth = min(760, max(520, width + 52))
        let frame = NSRect(
            x: 0, y: 0,
            width: contentWidth,
            height: 46
        )
        panel.setFrame(frame, display: true)
        position(panel)
    }

    private static func position(_ panel: NSPanel) {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        panel.setFrameOrigin(
            NSPoint(
                x: screen.midX - panel.frame.width / 2,
                y: screen.maxY - 76
            )
        )
    }

    private static func color(for kind: Kind) -> NSColor {
        switch kind {
        case .success: NSColor(
            calibratedRed: 0.20,
            green: 0.95,
            blue: 0.45,
            alpha: 1
        )
        case .warning, .danger: NSColor(
            calibratedRed: 1.00,
            green: 0.35,
            blue: 0.35,
            alpha: 1
        )
        case .neutral: .white
        }
    }

    enum Kind {
        case neutral, success, warning, danger
    }
}
