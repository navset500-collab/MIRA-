import SwiftUI
import MIRACore

final class MIRAAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct MIRAApp: App {
    @NSApplicationDelegateAdaptor(MIRAAppDelegate.self) private var appDelegate
    @State private var needsCalibration: Bool
    @AppStorage("mira.calibrationVersion") private var calibrationVersion = 0

    private let requiredCalibrationVersion = 2

    private var activity: NSObjectProtocol?

    init() {
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated],
            reason: "MIRA hand tracking"
        )

        let savedTemplates: [HandGesture: GestureFeatures]
        if let data = UserDefaults.standard.data(forKey: "mira.gestureTemplates"),
           let decoded = try? JSONDecoder().decode([HandGesture: GestureFeatures].self, from: data) {
            savedTemplates = decoded
        } else {
            savedTemplates = [:]
        }
        let hasCurrentProfile = savedTemplates.count == HandGesture.allCases.count
            && UserDefaults.standard.integer(forKey: "mira.calibrationVersion") >= 2
        _needsCalibration = State(initialValue: !hasCurrentProfile)
    }

    var body: some Scene {
        WindowGroup {
            if !needsCalibration {
                MIRADashboardView(onRecalibrate: { needsCalibration = true })
                    .frame(minWidth: 1160, minHeight: 760)
            } else {
                CalibrationFlowView(onFinish: {
                    calibrationVersion = requiredCalibrationVersion
                    needsCalibration = false
                })
                    .frame(minWidth: 1000, minHeight: 720)
            }
        }
        .windowResizability(.contentSize)
    }
}