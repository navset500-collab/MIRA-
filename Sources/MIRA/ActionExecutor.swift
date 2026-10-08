import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import MIRACore

enum ActionExecutor {
    private static let scriptQueue = DispatchQueue(label: "mira.actions.scripts")

    static func execute(
        _ action: MIRAAction,
        volumeDirection: Int = 10,
        completion: @escaping (String) -> Void
    ) {
        switch action {
        case .screenshot:
            captureScreenshot(completion: completion)
        case .playPauseMusic:
            runScript(
                "tell application \"Music\" to playpause",
                success: "Apple Music play / pause sent",
                completion: completion
            )
        case .nextTrack:
            runScript(
                "tell application \"Music\" to next track",
                success: "Next Music track requested",
                completion: completion
            )
        case .previousTrack:
            runScript(
                "tell application \"Music\" to previous track",
                success: "Previous Music track requested",
                completion: completion
            )
        case .volumeControl:
            let change = volumeDirection < 0 ? -10 : 10
            runScript(
                """
                set v to (output volume of (get volume settings)) + \(change)
                if v > 100 then set v to 100
                if v < 0 then set v to 0
                set volume output volume v
                """,
                success: change < 0 ? "Volume decreased" : "Volume increased",
                completion: completion
            )
        case .openNotes:
            toggleApplication("com.apple.Notes", label: "Notes", completion: completion)
        case .openCalendar:
            toggleApplication("com.apple.Calendar", label: "Calendar", completion: completion)
        case .openSpotify:
            toggleApplication("com.spotify.client", label: "Spotify", completion: completion)
        case .spotifyPlayPause:
            guard NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.spotify.client"
            ) != nil else {
                completion("Install Spotify's desktop app to use this control")
                return
            }
            runScript(
                "tell application \"Spotify\" to playpause",
                success: "Spotify play / pause sent",
                completion: completion
            )
        case .chromeTabToggle:
            BrowserActionController.shared.toggle(
                key: action.rawValue, url: "chrome://newtab/",
                label: "Chrome tab", completion: completion
            )
        case .openGmail:
            BrowserActionController.shared.toggle(
                key: action.rawValue, url: "https://mail.google.com/",
                label: "Gmail", completion: completion
            )
        case .openYouTube:
            BrowserActionController.shared.toggle(
                key: action.rawValue, url: "https://www.youtube.com/",
                label: "YouTube", completion: completion
            )
        case .openChatGPT:
            BrowserActionController.shared.toggle(
                key: action.rawValue, url: "https://chatgpt.com/",
                label: "ChatGPT", completion: completion
            )
        case .openMessenger:
            BrowserActionController.shared.toggle(
                key: action.rawValue, url: "https://www.messenger.com/",
                label: "Messenger", completion: completion
            )
        case .maximizeWindow:
            maximizeWindow(completion: completion)
        case .minimizeWindow:
            minimizeWindow(completion: completion)
        case .cursorControl, .toggleActions:
            completion("This mode switch is handled by the dashboard")
        default:
            completion("No action assigned")
        }
    }

    private static func runScript(
        _ source: String,
        success: String,
        completion: @escaping (String) -> Void
    ) {
        scriptQueue.async {
            guard let script = NSAppleScript(source: source) else {
                DispatchQueue.main.async { completion("Could not prepare action") }
                return
            }
            var error: NSDictionary?
            _ = script.executeAndReturnError(&error)
            let message = error.map {
                ($0["NSAppleScriptErrorMessage"] as? String)
                    ?? "Action failed. Check Automation permissions."
            } ?? success
            DispatchQueue.main.async { completion(message) }
        }
    }

    private static func toggleApplication(
        _ identifier: String,
        label: String,
        completion: @escaping (String) -> Void
    ) {
        if let app = NSRunningApplication.runningApplications(
            withBundleIdentifier: identifier
        ).first {
            completion(app.terminate()
                ? "\(label) quit requested"
                : "\(label) could not be asked to quit")
            return
        }

        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: identifier
        ) else {
            completion("\(label) is not installed")
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, error in
            DispatchQueue.main.async {
                if let app {
                    app.activate(options: [.activateIgnoringOtherApps])
                }
                completion(error == nil ? "\(label) opened" : "Could not open \(label)")
            }
        }
    }

    private static func maximizeWindow(completion: @escaping (String) -> Void) {
        guard AXIsProcessTrusted() else {
            completion("Maximize requires Accessibility access for this MIRA build.")
            return
        }

        let front = NSWorkspace.shared.frontmostApplication
        let target = front?.bundleIdentifier == Bundle.main.bundleIdentifier
            ? TargetAppTracker.shared.lastApplication : front

        guard let target, !target.isTerminated else {
            completion("Open the target app once so MIRA knows which window to control.")
            return
        }

        target.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            resizeTargetWindow(target, completion: completion)
        }
    }

    private static func resizeTargetWindow(
        _ target: NSRunningApplication,
        completion: @escaping (String) -> Void
    ) {
        guard !target.isTerminated else {
            completion("The target app has closed.")
            return
        }

        let app = AXUIElementCreateApplication(target.processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.5)

        var window: AXUIElement?
        var focused: CFTypeRef?

        if AXUIElementCopyAttributeValue(
            app, kAXFocusedWindowAttribute as CFString, &focused
        ) == .success, let focused,
           CFGetTypeID(focused) == AXUIElementGetTypeID() {
            window = (focused as! AXUIElement)
        }

        if window == nil {
            var allWindows: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                app, kAXWindowsAttribute as CFString, &allWindows
            ) == .success,
               let windows = allWindows as? [AXUIElement] {
                window = windows.first
            }
        }

        guard let window else {
            completion("No controllable window found in \(target.localizedName ?? "the target app").")
            return
        }

        _ = AXUIElementSetAttributeValue(
            window, kAXMinimizedAttribute as CFString, kCFBooleanFalse
        )
        _ = AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard let screen = NSScreen.screens.first else {
                completion("Display information unavailable.")
                return
            }

            let visible = screen.visibleFrame
            let primaryHeight = screen.frame.maxY
            var point = CGPoint(
                x: visible.minX,
                y: primaryHeight - visible.maxY
            )
            var size = visible.size

            guard let pointValue = AXValueCreate(.cgPoint, &point),
                  let sizeValue = AXValueCreate(.cgSize, &size) else {
                completion("Could not prepare window dimensions.")
                return
            }

            var canMove: DarwinBoolean = false
            var canResize: DarwinBoolean = false
            _ = AXUIElementIsAttributeSettable(
                window, kAXPositionAttribute as CFString, &canMove
            )
            _ = AXUIElementIsAttributeSettable(
                window, kAXSizeAttribute as CFString, &canResize
            )

            guard canResize.boolValue else {
                completion("This app does not allow external window resizing.")
                return
            }

            if canMove.boolValue {
                _ = AXUIElementSetAttributeValue(
                    window, kAXPositionAttribute as CFString, pointValue
                )
            }

            let resized = AXUIElementSetAttributeValue(
                window, kAXSizeAttribute as CFString, sizeValue
            )

            // Some applications adjust position after resizing.
            if canMove.boolValue {
                _ = AXUIElementSetAttributeValue(
                    window, kAXPositionAttribute as CFString, pointValue
                )
            }

            completion(resized == .success
                ? "Requested maximum window size for \(target.localizedName ?? "the app")."
                : "Window resize failed (Accessibility error \(resized.rawValue)).")
        }
    }

    private static func minimizeWindow(completion: @escaping (String) -> Void) {
        guard AXIsProcessTrusted() else {
            completion("Accessibility unavailable. Enable this MIRA build in Settings, then quit and reopen it.")
            return
        }

        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            == Bundle.main.bundleIdentifier {
            guard let target = TargetAppTracker.shared.lastApplication,
                  !target.isTerminated else {
                completion("Open the target app once before minimizing its window")
                return
            }
            target.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier
                    == target.processIdentifier else {
                    completion("Could not activate the target app")
                    return
                }
                minimizeWindow(completion: completion)
            }
            return
        }

        guard let down = CGEvent(
            keyboardEventSource: nil, virtualKey: 46, keyDown: true
        ), let up = CGEvent(
            keyboardEventSource: nil, virtualKey: 46, keyDown: false
        ) else {
            completion("Could not create minimize shortcut")
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
        completion("Minimize shortcut sent")
    }

    private static func captureScreenshot(completion: @escaping (String) -> Void) {
        guard CGPreflightScreenCaptureAccess() else {
            completion("Enable MIRA in Privacy & Security > Screen Recording, then quit and reopen it.")
            return
        }

        let destination = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
            .appendingPathComponent("MIRA-\(UUID().uuidString).png")

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", destination.path]
            process.standardError = pipe
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let detail = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let saved = process.terminationStatus == 0
                    && FileManager.default.fileExists(atPath: destination.path)
                DispatchQueue.main.async {
                    completion(saved ? "Screenshot saved to Desktop"
                        : detail.isEmpty ? "Screenshot failed. Check Desktop access."
                        : "Screenshot failed: \(String(detail.prefix(180)))")
                }
            } catch {
                DispatchQueue.main.async {
                    completion("Screenshot could not start: \(error.localizedDescription)")
                }
            }
        }
    }
}
