import AppKit
import Foundation

final class BrowserActionController {
    static let shared = BrowserActionController()
    private let queue = DispatchQueue(label: "mira.browser.actions")
    private var tabs: [String: Int] = [:]

    func toggle(
        key: String,
        url: String,
        label: String,
        completion: @escaping (String) -> Void
    ) {
        guard NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.google.Chrome"
        ) != nil else {
            completion("Install Google Chrome to use this control")
            return
        }

        queue.async {
            let trackedID = self.tabs[key] ?? -1

            let match: String
            switch key {
            case "openGmail":
                match = "(u starts with \"https://mail.google.com/\")"
            case "openYouTube":
                match = "(u starts with \"https://www.youtube.com/\") or (u starts with \"https://youtube.com/\")"
            case "openChatGPT":
                match = "(u starts with \"https://chatgpt.com/\") or (u starts with \"https://chat.openai.com/\")"
            case "openMessenger":
                match = "(u starts with \"https://www.messenger.com/\") or (u starts with \"https://messenger.com/\")"
            default:
                match = "false"
            }

            let source = """
            tell application "Google Chrome"
                activate
                repeat with w in windows
                    repeat with t in tabs of w
                        if (id of t) is \(trackedID) then
                            close t
                            return "closed"
                        end if
                    end repeat
                end repeat

                repeat with w in windows
                    repeat with t in tabs of w
                        set u to URL of t
                        if \(match) then
                            close t
                            return "closed"
                        end if
                    end repeat
                end repeat

                if \(trackedID) is not -1 and "\(key)" is "chromeTabToggle" then
                    return "missing"
                end if

                activate
                if (count of windows) is 0 then
                    make new window
                    set newTab to active tab of front window
                    set URL of newTab to "\(url)"
                else
                    tell front window
                        set newTab to make new tab at end of tabs with properties {URL:"\(url)"}
                        set active tab index to count of tabs
                    end tell
                end if
                return "opened:" & ((id of newTab) as text)
            end tell
            """

            guard let script = NSAppleScript(source: source) else {
                self.finish("Could not prepare Chrome command", completion)
                return
            }

            var error: NSDictionary?
            let result = script.executeAndReturnError(&error)
            if let error {
                let detail = error["NSAppleScriptErrorMessage"] as? String
                    ?? "Check Automation permission for MIRA > Google Chrome."
                self.finish("Chrome failed: \(detail)", completion)
                return
            }

            let output = result.stringValue ?? ""
            if output == "closed" {
                self.tabs.removeValue(forKey: key)
                self.finish("\(label) tab closed", completion)
            } else if output == "missing" {
                self.tabs.removeValue(forKey: key)
                self.finish("The tracked Chrome tab is gone. Repeat to open a new one.", completion)
            } else if output.hasPrefix("opened:"),
                      let id = Int(output.dropFirst(7)) {
                self.tabs[key] = id
                self.finish("\(label) opened. Repeat the gesture to close it.", completion)
            } else {
                self.finish("Chrome returned an unexpected result: \(output)", completion)
            }
        }
    }

    private func finish(_ message: String, _ completion: @escaping (String) -> Void) {
        DispatchQueue.main.async { completion(message) }
    }
}
