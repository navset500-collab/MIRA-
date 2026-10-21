import AppKit
import CoreGraphics
import Foundation
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

enum ScreenshotController {
    private static var busy = false

    static func capture(completion: @escaping (String) -> Void) {
        DispatchQueue.main.async {
            guard !busy else {
                completion("Screenshot unavailable: another capture is in progress.")
                return
            }

            guard CGPreflightScreenCaptureAccess() else {
                _ = CGRequestScreenCaptureAccess()
                completion(
                    "Screenshot requires Screen Recording permission. Enable MIRA in System Settings > Privacy & Security > Screen Recording, then quit and reopen MIRA."
                )
                return
            }

            busy = true

            Task.detached(priority: .userInitiated) {
                func finish(_ message: String) {
                    DispatchQueue.main.async {
                        busy = false
                        completion(message)
                    }
                }

                do {
                    let content = try await SCShareableContent
                        .excludingDesktopWindows(
                            false,
                            onScreenWindowsOnly: true
                        )

                    guard let display = content.displays.first(where: {
                        $0.displayID == CGMainDisplayID()
                    }) ?? content.displays.first else {
                        finish("Screenshot failed: no capturable display was found.")
                        return
                    }

                    let filter = SCContentFilter(
                        display: display,
                        excludingWindows: []
                    )
                    let configuration = SCStreamConfiguration()
                    configuration.width = display.width
                    configuration.height = display.height
                    configuration.showsCursor = false

                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: filter,
                        configuration: configuration
                    )

                    let data = NSMutableData()
                    guard let destination = CGImageDestinationCreateWithData(
                        data,
                        UTType.png.identifier as CFString,
                        1,
                        nil
                    ) else {
                        finish("Screenshot failed: PNG encoder unavailable.")
                        return
                    }

                    CGImageDestinationAddImage(destination, image, nil)
                    guard CGImageDestinationFinalize(destination) else {
                        finish("Screenshot failed: PNG encoding did not finish.")
                        return
                    }

                    let desktop = try FileManager.default.url(
                        for: .desktopDirectory,
                        in: .userDomainMask,
                        appropriateFor: nil,
                        create: true
                    )

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                    let suffix = String(UUID().uuidString.prefix(6))
                    let filename =
                        "MIRA-\(formatter.string(from: Date()))-\(suffix).png"
                    let file = desktop.appendingPathComponent(filename)

                    try (data as Data).write(to: file, options: .atomic)

                    let attributes = try FileManager.default.attributesOfItem(
                        atPath: file.path
                    )
                    let bytes = (attributes[.size] as? NSNumber)?.intValue ?? 0

                    guard bytes > 0 else {
                        finish("Screenshot failed: the saved file was empty.")
                        return
                    }

                    finish("Saved screenshot to Desktop: \(filename)")
                } catch {
                    finish(
                        "Screenshot failed: \(error.localizedDescription). Check Screen Recording permission and Desktop access."
                    )
                }
            }
        }
    }
}
