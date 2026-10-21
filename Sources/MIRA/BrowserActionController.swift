import AppKit
import Foundation

final class BrowserActionController {
    // mira.browser.reliableToggle.v2
    static let shared = BrowserActionController()

    private let queue = DispatchQueue(label: "mira.browser.actions")
    private let chromeBundleID = "com.google.Chrome"

    func toggle(
        key: String,
        url: String,
        label: String,
        completion: @escaping (String) -> Void
    ) {
        guard NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: chromeBundleID
        ) != nil else {
            finish("Install Google Chrome to use this control.", completion)
            return
        }

        guard let targetURL = URL(string: url),
              let scheme = targetURL.scheme,
              ["https", "http", "chrome"].contains(scheme.lowercased())
        else {
            finish("Could not prepare the browser URL.", completion)
            return
        }

        queue.async {
            let defaults = UserDefaults.standard
            let storageKey = "mira.browser.tracked.v2." + key

            let currentPID = NSRunningApplication.runningApplications(
                withBundleIdentifier: self.chromeBundleID
            ).first?.processIdentifier

            let stored = defaults.dictionary(forKey: storageKey)
            let storedPID = (stored?["pid"] as? NSNumber)?.int32Value
            let storedID = (stored?["tabID"] as? NSNumber)?.intValue ?? -1

            // Tab IDs are trusted only for the same Chrome process.
            let trackedID: Int
            if let currentPID, storedPID == currentPID, storedID > 0 {
                trackedID = storedID
            } else {
                trackedID = -1
                defaults.removeObject(forKey: storageKey)
            }

            let safeURL = self.appleScriptString(targetURL.absoluteString)

            let source = """
            tell application "Google Chrome"
                activate

                if \(trackedID) > 0 then
                    repeat with w in windows
                        set windowID to id of w
                        set tabCount to count of tabs of w
                        repeat with tabIndex from tabCount to 1 by -1
                            if ((id of tab tabIndex of w) as text) is "\(trackedID)" then
                                close tab tabIndex of window id windowID
                                return "closed"
                            end if
                        end repeat
                    end repeat
                end if

                -- No live tracked tab: open one during this activation.
                if (count of windows) is 0 then
                    make new window
                    set targetWindowID to id of front window
                    set targetIndex to active tab index of front window
                    set URL of tab targetIndex of window id targetWindowID to \(safeURL)
                else
                    set targetWindowID to id of front window
                    tell window id targetWindowID
                        make new tab at end of tabs with properties {URL:\(safeURL)}
                        set targetIndex to count of tabs
                        set active tab index to targetIndex
                    end tell
                end if

                -- Read the actual created tab, not a temporary creation reference.
                repeat 40 times
                    try
                        set createdID to id of tab targetIndex of window id targetWindowID
                        if createdID > 0 then
                            return "opened:" & (createdID as text)
                        end if
                    end try
                    delay 0.05
                end repeat

                return "untracked"
            end tell
            """

            guard let script = NSAppleScript(source: source) else {
                self.finish("Could not prepare the Chrome command.", completion)
                return
            }

            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)

            if let error {
                let detail = error["NSAppleScriptErrorMessage"] as? String
                    ?? "Check MIRA's Automation permission for Google Chrome."

                self.finish("Chrome failed: \(detail)", completion)
                return
            }

            let output = result.stringValue ?? ""

            if output == "closed" {
                defaults.removeObject(forKey: storageKey)
                self.finish("\(label) tab closed.", completion)
                return
            }

            if output.hasPrefix("opened:"),
               let tabID = Int(output.dropFirst(7)),
               tabID > 0,
               let chrome = NSRunningApplication.runningApplications(
                    withBundleIdentifier: self.chromeBundleID
               ).first {
                defaults.set(
                    [
                        "tabID": tabID,
                        "pid": Int(chrome.processIdentifier)
                    ],
                    forKey: storageKey
                )

                self.finish(
                    "\(label) tab opened. Repeat the gesture to close it.",
                    completion
                )
                return
            }

            defaults.removeObject(forKey: storageKey)

            if output == "untracked" {
                self.finish(
                    "Chrome opened a tab, but MIRA could not track it. Close that tab manually before retrying.",
                    completion
                )
            } else {
                self.finish(
                    "Chrome failed: unexpected response \(output).",
                    completion
                )
            }
        }
    }

    private func appleScriptString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"" + escaped + "\""
    }

    private func finish(
        _ message: String,
        _ completion: @escaping (String) -> Void
    ) {
        DispatchQueue.main.async {
            completion(message)
        }
    }
}
