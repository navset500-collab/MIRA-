import AppKit
import ApplicationServices
import Foundation

enum WindowActionController {
    enum Operation {
        case minimize
        case maximizeRestore
    }

    private struct SavedWindow {
        let window: AXUIElement
        let original: CGRect
        let maximized: CGRect
    }

    private static let queue = DispatchQueue(
        label: "mira.window-actions",
        qos: .userInitiated
    )
    private static var saved: [SavedWindow] = []

    static func perform(
        _ operation: Operation,
        completion: @escaping (String) -> Void
    ) {
        DispatchQueue.main.async {
            guard AXIsProcessTrusted() else {
                completion("Window control requires Accessibility permission for MIRA.")
                return
            }

            let front = NSWorkspace.shared.frontmostApplication
            let target = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier
                ? TargetAppTracker.shared.lastApplication
                : front

            guard let target,
                  !target.isTerminated,
                  target.processIdentifier != ProcessInfo.processInfo.processIdentifier
            else {
                completion("Could not find a target app. Open its window first.")
                return
            }

            // AppKit screen information is collected on the main thread.
            let primaryTop = NSScreen.screens.first?.frame.maxY ?? 0
            let displays = NSScreen.screens.map { screen in
                (
                    frame: CGRect(
                        x: screen.frame.minX,
                        y: primaryTop - screen.frame.maxY,
                        width: screen.frame.width,
                        height: screen.frame.height
                    ),
                    usable: CGRect(
                        x: screen.visibleFrame.minX,
                        y: primaryTop - screen.visibleFrame.maxY,
                        width: screen.visibleFrame.width,
                        height: screen.visibleFrame.height
                    )
                )
            }
            let pid = target.processIdentifier
            let name = target.localizedName ?? "the app"

            queue.async {
                func finish(_ message: String) {
                    DispatchQueue.main.async { completion(message) }
                }

                let app = AXUIElementCreateApplication(pid)
                AXUIElementSetMessagingTimeout(app, 0.5)

                guard let window = targetWindow(app) else {
                    finish("Could not find a controllable window in \(name).")
                    return
                }
                AXUIElementSetMessagingTimeout(window, 0.5)

                if case .minimize = operation {
                    guard settable(window, kAXMinimizedAttribute) else {
                        finish("Minimize is unavailable for this window in \(name).")
                        return
                    }

                    let result = AXUIElementSetAttributeValue(
                        window,
                        kAXMinimizedAttribute as CFString,
                        kCFBooleanTrue
                    )
                    guard result == .success else {
                        finish("Minimize failed: Accessibility error \(result.rawValue).")
                        return
                    }

                    Thread.sleep(forTimeInterval: 0.2)
                    finish(boolean(window, kAXMinimizedAttribute) == true
                        ? "Minimized the window in \(name)."
                        : "Minimize requested, but the minimized state could not be confirmed.")
                    return
                }

                if boolean(window, "AXFullScreen") == true {
                    finish("Maximize unavailable while this window is full-screen. Exit full-screen first.")
                    return
                }

                guard settable(window, kAXPositionAttribute),
                      settable(window, kAXSizeAttribute),
                      let current = frame(window)
                else {
                    finish("Move or resize is unavailable for this window in \(name).")
                    return
                }

                let restoringIndex = saved.firstIndex {
                    CFEqual($0.window, window) && close(current, $0.maximized)
                }

                let desired: CGRect
                if let index = restoringIndex {
                    desired = saved[index].original
                } else {
                    guard let display = displays.max(by: {
                        overlap(current, $0.frame) < overlap(current, $1.frame)
                    }) else {
                        finish("Display information unavailable.")
                        return
                    }
                    desired = display.usable
                }

                guard let failure = apply(desired, to: window) else {
                    Thread.sleep(forTimeInterval: 0.25)

                    guard let actual = frame(window) else {
                        finish("Window resize requested, but the resulting size could not be confirmed.")
                        return
                    }

                    guard close(actual, desired) else {
                        finish("Window resize was limited by \(name); the requested bounds were not reached.")
                        return
                    }

                    if let index = restoringIndex {
                        saved.remove(at: index)
                        finish("Restored the window in \(name).")
                    } else {
                        saved.removeAll { CFEqual($0.window, window) }
                        saved.append(SavedWindow(
                            window: window,
                            original: current,
                            maximized: actual
                        ))
                        if saved.count > 32 { saved.removeFirst() }
                        finish("Maximized the window in \(name). Run again to restore.")
                    }
                    return
                }

                finish("Window resize failed: Accessibility error \(failure.rawValue).")
            }
        }
    }

    private static func attribute(
        _ element: AXUIElement,
        _ name: String
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, name as CFString, &value
        ) == .success else { return nil }
        return value
    }

    private static func boolean(
        _ element: AXUIElement,
        _ name: String
    ) -> Bool? {
        attribute(element, name) as? Bool
    }

    private static func settable(
        _ element: AXUIElement,
        _ name: String
    ) -> Bool {
        var value: DarwinBoolean = false
        return AXUIElementIsAttributeSettable(
            element, name as CFString, &value
        ) == .success && value.boolValue
    }

    private static func targetWindow(_ app: AXUIElement) -> AXUIElement? {
        for key in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            if let value = attribute(app, key),
               CFGetTypeID(value) == AXUIElementGetTypeID() {
                let window = value as! AXUIElement
                if boolean(window, kAXMinimizedAttribute) != true {
                    return window
                }
            }
        }

        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        return windows.first {
            boolean($0, kAXMinimizedAttribute) != true
        }
    }

    private static func frame(_ window: AXUIElement) -> CGRect? {
        guard let rawPoint = attribute(window, kAXPositionAttribute),
              let rawSize = attribute(window, kAXSizeAttribute),
              CFGetTypeID(rawPoint) == AXValueGetTypeID(),
              CFGetTypeID(rawSize) == AXValueGetTypeID()
        else { return nil }

        let pointValue = rawPoint as! AXValue
        let sizeValue = rawSize as! AXValue
        guard AXValueGetType(pointValue) == .cgPoint,
              AXValueGetType(sizeValue) == .cgSize
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(pointValue, .cgPoint, &point),
              AXValueGetValue(sizeValue, .cgSize, &size),
              point.x.isFinite, point.y.isFinite,
              size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0
        else { return nil }

        return CGRect(origin: point, size: size)
    }

    private static func apply(
        _ rect: CGRect,
        to window: AXUIElement
    ) -> AXError? {
        var point = rect.origin
        var size = rect.size
        guard let position = AXValueCreate(.cgPoint, &point),
              let dimensions = AXValueCreate(.cgSize, &size)
        else { return .failure }

        // A preliminary move helps when crossing displays. Some apps
        // only accept the final position after the resize.
        _ = AXUIElementSetAttributeValue(
            window, kAXPositionAttribute as CFString, position
        )

        let resized = AXUIElementSetAttributeValue(
            window, kAXSizeAttribute as CFString, dimensions
        )
        guard resized == .success else { return resized }

        let moved = AXUIElementSetAttributeValue(
            window, kAXPositionAttribute as CFString, position
        )
        return moved == .success ? nil : moved
    }

    private static func close(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 8 &&
        abs(a.minY - b.minY) <= 8 &&
        abs(a.width - b.width) <= 8 &&
        abs(a.height - b.height) <= 8
    }

    private static func overlap(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
