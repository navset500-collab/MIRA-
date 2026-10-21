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
        case .playPauseMusic, .spotifyPlayPause:
            guard NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.spotify.client"
            ) != nil else {
                completion("Install Spotify's desktop app to use playback.")
                return
            }
            runScript(
                "tell application \"Spotify\" to playpause",
                success: "Spotify play / pause sent",
                completion: completion
            )
        case .nextTrack, .previousTrack:
            completion("Track shortcuts were removed. Choose another action.")
        case .volumeUp, .volumeDown, .volumeControl:
            let change: Int
            switch action {
            case .volumeDown:
                change = -10
            case .volumeUp:
                change = 10
            default:
                change = volumeDirection < 0 ? -10 : 10
            }

            runScript(
                """
                set currentVolume to output volume of (get volume settings)
                set newVolume to currentVolume + \(change)
                if newVolume > 100 then set newVolume to 100
                if newVolume < 0 then set newVolume to 0
                set volume output volume newVolume
                """,
                success: change < 0
                    ? "Volume down requested"
                    : "Volume up requested",
                completion: completion
            )
        case .openNotes:
            toggleApplication("com.apple.Notes", label: "Notes", completion: completion)
        case .openCalendar:
            toggleApplication("com.apple.Calendar", label: "Calendar", completion: completion)
        case .openSpotify:
            toggleApplication("com.spotify.client", label: "Spotify", completion: completion)
        case .chromeTabToggle:
            BrowserActionController.shared.toggle(
                key: action.rawValue, url: "chrome://newtab/",
                label: "Chrome tab", completion: completion
            )
        case .stockMarket, .openGoogleDocs:
            guard NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.google.Chrome"
            ) != nil else {
                completion("Install Google Chrome to use Stock Market.")
                return
            }
            BrowserActionController.shared.toggle(
                key: MIRAAction.stockMarket.rawValue,
                url: "https://www.google.com/finance/",
                label: "Stock Market",
                completion: completion
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
        case .openInstagram:
            BrowserActionController.shared.toggle(
                key: action.rawValue, url: "https://www.instagram.com/",
                label: "Instagram", completion: completion
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
                    app.activate(options: [])
                }
                completion(error == nil ? "\(label) opened" : "Could not open \(label)")
            }
        }
    }

    private static func maximizeWindow(
        completion: @escaping (String) -> Void
    ) {
        WindowActionController.perform(.maximizeRestore, completion: completion)
    }

    private static func minimizeWindow(
        completion: @escaping (String) -> Void
    ) {
        WindowActionController.perform(.minimize, completion: completion)
    }

    private static func captureScreenshot(
        completion: @escaping (String) -> Void
    ) {
        ScreenshotController.capture(completion: completion)
    }
}
