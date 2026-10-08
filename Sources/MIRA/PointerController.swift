import MIRACore
import AppKit
import ApplicationServices
import Combine
import CoreGraphics

final class TargetAppTracker {
    static let shared = TargetAppTracker()
    private(set) var lastApplication: NSRunningApplication?
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        remember(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.remember(
                notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                    as? NSRunningApplication
            )
        }
    }

    private func remember(_ app: NSRunningApplication?) {
        guard let app,
              app.activationPolicy == .regular,
              app.bundleIdentifier != Bundle.main.bundleIdentifier
        else { return }
        lastApplication = app
    }
}

final class PointerController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var status = "Cursor Control off"

    private var position: CGPoint?
    private var clickArmed = false
    private var openFrames = 0
    private var fistFrames = 0
    private var fistStarted: Date?
    private var lastFrame = Date.distantPast
    private var watchdog: Timer?

    func setEnabled(_ enabled: Bool) {
        guard enabled else {
            stop()
            return
        }
        guard AXIsProcessTrusted() else {
            isEnabled = false
            status = "Accessibility unavailable for this running MIRA build."
            return
        }

        position = nil
        clickArmed = false
        openFrames = 0
        fistFrames = 0
        fistStarted = nil
        lastFrame = Date()
        isEnabled = true
        status = "Open palm moves. Close your hand to click."

        watchdog?.invalidate()
        watchdog = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) {
            [weak self] _ in
            guard let self, self.isEnabled else { return }
            if Date().timeIntervalSince(self.lastFrame) > 0.5 {
                self.resetClick()
                self.status = "Hand tracking paused. Show an open palm."
            }
        }
    }

    func stop() {
        watchdog?.invalidate()
        watchdog = nil
        isEnabled = false
        position = nil
        resetClick()
        status = "Cursor Control off"
    }

    func update(_ landmarks: [HandLandmark], gesture: HandGesture?) {
        guard isEnabled else { return }
        lastFrame = Date()

        guard AXIsProcessTrusted() else {
            stop()
            status = "Accessibility unavailable for this running MIRA build."
            return
        }

        func point(_ name: String) -> CGPoint? {
            guard let p = landmarks.first(where: {
                $0.id == name && $0.confidence >= 0.12
            }) else { return nil }
            return CGPoint(x: p.x, y: p.y)
        }

        switch gesture {
        case .openPalm:
            fistFrames = 0
            fistStarted = nil

            let anchor: CGPoint?
            if let wrist = point("wrist"), let base = point("middleMCP") {
                anchor = CGPoint(
                    x: (wrist.x + base.x) / 2,
                    y: (wrist.y + base.y) / 2
                )
            } else {
                anchor = point("palm-center")
            }

            guard let anchor else {
                resetClick()
                status = "Keep your open palm clearly visible."
                return
            }

            openFrames += 1
            if openFrames >= 3 { clickArmed = true }

            let screen = CGDisplayBounds(CGMainDisplayID())
            let x = min(1, max(0, ((1 - anchor.x) - 0.15) / 0.70))
            let y = min(1, max(0, ((1 - anchor.y) - 0.15) / 0.70))
            let target = CGPoint(
                x: screen.minX + x * max(1, screen.width - 1),
                y: screen.minY + y * max(1, screen.height - 1)
            )

            let next: CGPoint
            if let previous = position {
                next = CGPoint(
                    x: previous.x + (target.x - previous.x) * 0.45,
                    y: previous.y + (target.y - previous.y) * 0.45
                )
            } else {
                next = target
            }

            position = next
            post(.mouseMoved, at: next)
            status = "Open palm: moving cursor. Fist: click."

        case .fist:
            openFrames = 0
            guard clickArmed, let position else {
                status = "Show an open palm before the next click."
                return
            }

            if fistStarted == nil { fistStarted = Date() }
            fistFrames += 1

            guard fistFrames >= 3,
                  Date().timeIntervalSince(fistStarted ?? Date()) >= 0.15
            else {
                status = "Hold your fist briefly to click."
                return
            }

            post(.leftMouseDown, at: position)
            post(.leftMouseUp, at: position)
            clickArmed = false
            fistFrames = 0
            fistStarted = nil
            status = "Clicked. Open your hand to move or click again."

        default:
            openFrames = 0
            fistFrames = 0
            fistStarted = nil
            if landmarks.isEmpty { clickArmed = false }
            status = "Use an open palm to move or a fist to click."
        }
    }

    private func resetClick() {
        clickArmed = false
        openFrames = 0
        fistFrames = 0
        fistStarted = nil
    }

    private func post(_ type: CGEventType, at point: CGPoint) {
        CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: point,
            mouseButton: .left
        )?.post(tap: .cghidEventTap)
    }
}
