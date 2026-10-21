import Foundation
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

private struct CursorCalibrationProfile: Codable {
    let centerX: Double
    let centerY: Double
    let leftX: Double
    let rightX: Double
    let topY: Double
    let bottomY: Double
    let palm: [Double]
    let fist: [Double]
}

final class PointerController: ObservableObject {
    // mira.simpleCursor.v1
    // Enabled is user intent. Tracking and authorization are separate states.
    @Published private(set) var isEnabled = false
    @Published private(set) var status = "Cursor Control off"

    // Compatibility with older dashboard code.
    @Published private(set) var calibrationStep: Int? = nil
    var calibrationInstruction: String {
        "No calibration required. Open Palm moves; hold Fist to click."
    }

    private var frameSubscription: AnyCancellable?
    private var connectedCamera: ObjectIdentifier?
    private var monitor: Timer?

    private var lastFrame = Date.distantPast
    private var lastMove = Date.distantPast
    private var position: CGPoint?
    private var palmSince: Date?
    private var fistSince: Date?
    private var clickArmed = false

    // mira.cursor.scrolling.v1
    private var scrollSince: Date?
    private var scrollOriginY: Double?
    private var lastScrollTime: Date?
    private var scrollRemainder = 0.0

    func connect(to camera: HandCameraModel) {
        let identity = ObjectIdentifier(camera)
        guard connectedCamera != identity || frameSubscription == nil else {
            return
        }

        frameSubscription?.cancel()
        connectedCamera = identity
        frameSubscription = camera.$cursorFrameNumber
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak camera] _ in
                guard let self, let camera else { return }
                self.update(
                camera.landmarks,
                gesture: camera.prediction?.gesture
            )
            }
    }

    func setEnabled(_ enabled: Bool) {
        guard enabled else {
            stop()
            return
        }

        // Repeated enable calls do not accumulate timers.
        monitor?.invalidate()
        monitor = nil
        resetTracking()
        isEnabled = true
        UserDefaults.standard.set(
            true, forKey: "mira.cursor.feedbackActive"
        )
        lastFrame = Date.distantPast

        if !AXIsProcessTrusted() {
            let options = [
                kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
            ] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            status = "Accessibility permission required"
        } else {
            status = "Waiting for camera and Open Palm"
        }

        monitor = Timer.scheduledTimer(
            withTimeInterval: 0.25, repeats: true
        ) { [weak self] _ in
            self?.checkHealth()
        }
    }

    func stop() {
        isEnabled = false
        UserDefaults.standard.set(
            false, forKey: "mira.cursor.feedbackActive"
        )
        monitor?.invalidate()
        monitor = nil
        resetTracking()
        status = "Cursor Control off"
    }

    private func checkHealth() {
        guard isEnabled else { return }

        if !AXIsProcessTrusted() {
            resetTracking()
            status = "Accessibility permission required"
            return
        }

        if Date().timeIntervalSince(lastFrame) > 0.6 {
            resetTracking()
            status = "Waiting for camera frames — start the camera"
        }
    }

    func update(_ landmarks: [HandLandmark], gesture: HandGesture?) {
        let receivedAt = Date()
        if receivedAt.timeIntervalSince(lastFrame) > 0.25 {
            resetTracking()
        }
        lastFrame = receivedAt
        guard isEnabled else { return }

        guard AXIsProcessTrusted() else {
            resetTracking()
            status = "Accessibility permission required"
            return
        }

        guard let hand = geometry(landmarks) else {
            resetTracking()
            status = "Tracking paused — show your palm and fingers"
            return
        }

        let now = Date()

        if hand.isScrollPose {
            palmSince = nil
            fistSince = nil
            clickArmed = false
            scroll(y: hand.y, now: now)
            return
        }

        clearScrolling()

        // Three clear extended fingers permit movement.
        // Clicking requires all four clear curled fingers.
        let palm = hand.openCount >= 3
        let fist = hand.validCount == 4 && hand.closedCount == 4

        if palm {
            fistSince = nil
            if palmSince == nil { palmSince = now }

            if now.timeIntervalSince(palmSince ?? now) >= 0.15 {
                clickArmed = true
            }

            move(x: hand.x, y: hand.y, now: now)
            return
        }

        palmSince = nil

        if fist {
            guard clickArmed, let location = position else {
                fistSince = nil
                status = "Show Open Palm before clicking"
                return
            }

            if fistSince == nil { fistSince = now }
            let held = now.timeIntervalSince(fistSince ?? now)

            guard held >= 0.30 else {
                status = "Hold Fist to click"
                return
            }

            // Disarm before posting either event.
            clickArmed = false
            fistSince = nil

            guard let down = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseDown,
                mouseCursorPosition: location,
                mouseButton: .left
            ), let up = CGEvent(
                mouseEventSource: nil,
                mouseType: .leftMouseUp,
                mouseCursorPosition: location,
                mouseButton: .left
            ) else {
                status = "Could not create click events"
                return
            }

            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            status = "Click sent — Open Palm rearms"
            return
        }

        // An ambiguous pose cancels and disarms a pending click.
        fistSince = nil
        clickArmed = false
        status = "Tracking hand — open your palm to move"
    }

    private func move(x: Double, y: Double, now: Date) {
        let saved = UserDefaults.standard.double(
            forKey: "mira.cursor.halfRange"
        )
        let reach = saved > 0
            ? min(0.35, max(0.15, saved))
            : 0.20

        // Vision coordinates: upward-positive Y.
        // Mirror X so hand movement behaves like the mirrored preview.
        let nx = min(1, max(0, 0.5 + (0.50 - x) / (2 * reach)))
        let ny = min(1, max(0, 0.5 + (0.45 - y) / (2 * reach)))
        let screen = CGDisplayBounds(CGMainDisplayID())

        let target = CGPoint(
            x: screen.minX + CGFloat(nx) * max(1, screen.width - 1),
            y: screen.minY + CGFloat(ny) * max(1, screen.height - 1)
        )
        let old = position ?? CGEvent(source: nil)?.location ?? target
        let distance = hypot(target.x - old.x, target.y - old.y)
        let dt = lastMove == Date.distantPast
            ? 1.0 / 30.0
            : min(0.10, max(0.001, now.timeIntervalSince(lastMove)))
        let tau = distance > 20 ? 0.025 : 0.060
        let alpha = CGFloat(1 - exp(-dt / tau))

        var next = CGPoint(
            x: old.x + (target.x - old.x) * alpha,
            y: old.y + (target.y - old.y) * alpha
        )
        if nx == 0 || nx == 1 { next.x = target.x }
        if ny == 0 || ny == 1 { next.y = target.y }

        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: next,
            mouseButton: .left
        ) else {
            resetTracking()
            status = "Could not create cursor event"
            return
        }

        event.post(tap: .cghidEventTap)
        position = next
        lastMove = now
        status = "Cursor Control active — Open Palm moves"
    }

    private struct Geometry {
        let x: Double
        let y: Double
        let validCount: Int
        let openCount: Int
        let closedCount: Int
        let isScrollPose: Bool
    }

    private func geometry(_ landmarks: [HandLandmark]) -> Geometry? {
        func point(_ name: String) -> CGPoint? {
            guard let p = landmarks.first(where: {
                $0.id == name
                    && $0.confidence >= 0.15
                    && $0.x.isFinite
                    && $0.y.isFinite
            }) else { return nil }
            return CGPoint(x: p.x, y: p.y)
        }

        guard let wrist = point("wrist"),
              let base = point("middleMCP") ?? point("indexMCP") else {
            return nil
        }

        let scale = hypot(base.x - wrist.x, base.y - wrist.y)
        guard scale > 0.005 else { return nil }

        var valid = 0
        var open = 0
        var closed = 0
        var extendedFingers = Set<String>()
        var curledFingers = Set<String>()

        for finger in ["index", "middle", "ring", "little"] {
            guard let mcp = point(finger + "MCP"),
                  let pip = point(finger + "PIP"),
                  let tip = point(finger + "Tip") else {
                continue
            }

            let ax = mcp.x - pip.x
            let ay = mcp.y - pip.y
            let bx = tip.x - pip.x
            let by = tip.y - pip.y
            let denominator = hypot(ax, ay) * hypot(bx, by)
            guard denominator > 0.000001 else { continue }

            let cosine = min(1, max(-1, (ax * bx + ay * by) / denominator))
            let straightness = acos(Double(cosine)) / Double.pi
            let extensionDistance = Double((
                hypot(tip.x - wrist.x, tip.y - wrist.y)
                - hypot(pip.x - wrist.x, pip.y - wrist.y)
            ) / scale)

            valid += 1
            if straightness >= 0.65 && extensionDistance >= 0.12 {
                open += 1
                extendedFingers.insert(finger)
            }
            if straightness <= 0.75 && extensionDistance <= 0.05 {
                closed += 1
                curledFingers.insert(finger)
            }
        }

        guard valid >= 3 else { return nil }

        return Geometry(
            x: Double((wrist.x + base.x) / 2),
            y: Double((wrist.y + base.y) / 2),
            validCount: valid,
            openCount: open,
            closedCount: closed,
            isScrollPose: valid == 4
                && extendedFingers == Set(["index", "middle"])
                && curledFingers.contains("ring")
                && curledFingers.contains("little")
        )
    }

    private func scroll(y: Double, now: Date) {
        if scrollSince == nil {
            scrollSince = now
            status = "Hold Index + Middle briefly, then move your hand up/down"
        }

        guard now.timeIntervalSince(scrollSince ?? now) >= 0.22 else {
            return
        }

        guard let origin = scrollOriginY,
              let previous = lastScrollTime else {
            scrollOriginY = y
            lastScrollTime = now
            scrollRemainder = 0
            status = "Scrolling — move hand up/down; Open Palm returns to cursor"
            return
        }

        let dt = min(0.10, max(0, now.timeIntervalSince(previous)))
        lastScrollTime = now

        // Vision-style coordinates increase upward.
        let displacement = y - origin
        let deadZone = 0.025

        guard abs(displacement) > deadZone else {
            scrollRemainder = 0
            return
        }

        // Capped speed; accumulated fractions preserve gentle scrolling.
        let magnitude = min(
            650.0,
            max(0, abs(displacement) - deadZone) * 3500.0
        )
        let direction = displacement > 0 ? 1.0 : -1.0
        scrollRemainder += direction * magnitude * dt
        let pixels = Int32(scrollRemainder.rounded(.towardZero))
        guard pixels != 0 else { return }
        scrollRemainder -= Double(pixels)

        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: pixels,
            wheel2: 0,
            wheel3: 0
        ) else {
            resetTracking()
            status = "Could not create scroll event"
            return
        }

        event.location = CGEvent(source: nil)?.location
            ?? position
            ?? .zero
        event.post(tap: .cghidEventTap)
        status = "Scrolling — event sent; return hand to center to stop"
    }

    private func clearScrolling() {
        scrollSince = nil
        scrollOriginY = nil
        lastScrollTime = nil
        scrollRemainder = 0
    }

    private func resetTracking() {
        clearScrolling()
        palmSince = nil
        fistSince = nil
        clickArmed = false
        position = nil
        lastMove = Date.distantPast
    }

    // Compatibility only: calibration is no longer a startup requirement.
    func beginCalibration() {
        status = "No calibration required — enable Cursor Control"
    }

    func captureCalibrationStep() {}
    func cancelCalibration() {}

    deinit {
        monitor?.invalidate()
        frameSubscription?.cancel()
    }
}
