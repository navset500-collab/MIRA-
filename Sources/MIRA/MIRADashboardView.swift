import AppKit
import MIRACore
import SwiftUI

struct MIRADashboardView: View {
    let onRecalibrate: () -> Void

    @StateObject private var camera = HandCameraModel()
    @StateObject private var pointer = PointerController()
    @State private var actionStatus = "Ready when you are"
    @AppStorage("mira.actionsEnabled") private var actionsEnabled = false
    @AppStorage("binding.fist") private var fistAction = MIRAAction.screenshot.rawValue
    @AppStorage("binding.openPalm") private var palmAction = MIRAAction.playPauseMusic.rawValue
    @AppStorage("binding.thumbsUp") private var thumbsAction = MIRAAction.openNotes.rawValue
    @AppStorage("binding.thumbsDown") private var thumbsDownAction = MIRAAction.disabled.rawValue
    @AppStorage("binding.three") private var threeAction = MIRAAction.disabled.rawValue
    @AppStorage("binding.peace") private var peaceAction = MIRAAction.chromeTabToggle.rawValue
    @AppStorage("binding.pointUp") private var pointAction = MIRAAction.openCalendar.rawValue
    @AppStorage("binding.pointDown") private var pointDownAction = MIRAAction.disabled.rawValue
    @AppStorage("binding.pointLeft") private var pointLeftAction = MIRAAction.disabled.rawValue
    @AppStorage("binding.pointRight") private var pointRightAction = MIRAAction.disabled.rawValue
    @AppStorage("binding.ok") private var okAction = MIRAAction.disabled.rawValue
    @AppStorage("binding.rock") private var rockAction = MIRAAction.disabled.rawValue
    @AppStorage("binding.shaka") private var shakaAction = MIRAAction.disabled.rawValue

    private let paper = Color(red: 0.96, green: 0.965, blue: 0.95)
    private let surface = Color.white
    private let ink = Color(red: 0.13, green: 0.16, blue: 0.15)
    private let muted = Color(red: 0.42, green: 0.47, blue: 0.44)
    private let accent = Color(red: 0.76, green: 0.31, blue: 0.22)
    private let border = Color(red: 0.86, green: 0.88, blue: 0.85)
    private let bindingColumns = [GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(alignment: .top, spacing: 28) {
                cameraPanel.frame(maxWidth: .infinity)
                ScrollView(.vertical) {
                    controlsColumn
                }
                .scrollIndicators(.hidden)
                .frame(width: 430)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 23)
            footer
        }
        .background(paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear {
            TargetAppTracker.shared.start()
            migrateActionBindings()
        }
        .onDisappear { pointer.stop() }
        .onChange(of: actionsEnabled) { _, enabled in
            if enabled { pointer.stop() }
        }
        .onChange(of: pointer.isEnabled) { _, enabled in
            if enabled { actionsEnabled = false }
        }
        .onChange(of: camera.triggerID) { _, _ in runBoundAction() }
        .onChange(of: camera.landmarks) { _, points in
            pointer.update(points, gesture: camera.prediction?.gesture)
        }
        .onChange(of: camera.isRunning) { _, running in
            if !running { pointer.stop() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 0) {
                Text("MIRA")
                    .font(.system(size: 29, weight: .medium, design: .serif))
                    .foregroundStyle(ink)
                Text("MOTION INTERFACE FOR REAL-TIME ACCESS")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(1.15)
                    .foregroundStyle(muted)
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(camera.isRunning ? accent : muted.opacity(0.35)).frame(width: 7, height: 7)
                Text(camera.isRunning ? "CAMERA LIVE" : "STANDBY")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(camera.isRunning ? accent : muted)
            }
            Menu("Permissions") {
                Button("Accessibility") { openPrivacySettings("Privacy_Accessibility") }
                Button("Screen Recording") { openPrivacySettings("Privacy_ScreenCapture") }
                Button("Camera") { openPrivacySettings("Privacy_Camera") }
                Button("Automation") { openPrivacySettings("Privacy_Automation") }
            }
            .controlSize(.small)

            Toggle("Cursor Control", isOn: Binding(
                get: { pointer.isEnabled },
                set: { enabled in
                    pointer.setEnabled(enabled)
                    if pointer.isEnabled {
                        actionsEnabled = false
                    }
                    actionStatus = pointer.status
                }
            ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(accent)
                .disabled(!camera.isRunning)
                .help("Open palm moves the cursor. Fist clicks once. Assigned actions are disabled in this mode.")

            Toggle("Actions", isOn: Binding(
                get: { actionsEnabled },
                set: { enabled in
                    if enabled { pointer.stop() }
                    actionsEnabled = enabled
                }
            ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(accent)
                .help("Enable gesture-triggered actions")
            Button {
                camera.isRunning ? camera.stop() : camera.start()
            } label: {
                Label(
                    camera.isStarting ? "Starting…" : camera.isRunning ? "Stop" : "Start camera",
                    systemImage: camera.isRunning ? "pause.fill" : "video.fill"
                )
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)
            .controlSize(.regular)
            .disabled(camera.isStarting)
            Button(action: onRecalibrate) {
                Label("Recalibrate", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(.bordered)
            .tint(ink)
            .controlSize(.regular)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 17)
        .background(surface)
        .overlay(alignment: .bottom) { Rectangle().fill(border).frame(height: 1) }
    }

    private var cameraPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("LIVE CAMERA")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(muted)
                Spacer()
                Text(camera.cameraStatus.uppercased())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            ZStack {
                CameraPreview(session: camera.session)
                HandSkeleton(landmarks: camera.landmarks, imageSize: camera.imageSize)
                if camera.landmarks.isEmpty {
                    VStack(spacing: 8) {
                        Text("Raise one hand into view")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                        Text(camera.cameraStatus == "Camera off" ? "Start the camera to begin" : camera.cameraStatus)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                        if camera.cameraStatus.contains("Settings") || camera.cameraStatus.contains("denied") {
                            Button("Open Camera Settings") { camera.openCameraSettings() }
                                .buttonStyle(.link)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(15)
                    .background(ink.opacity(0.72), in: RoundedRectangle(cornerRadius: 7))
                }
                VStack {
                    HStack {
                        Text("HAND TRACKING")
                        Spacer()
                        Text("LIVE HAND TRACKING")
                    }
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(12)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            .frame(height: 410)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            HStack(spacing: 0) {
                metric("GESTURE SCORE", value: camera.prediction.map { "\(Int($0.confidence * 100))%" } ?? "--")
                Rectangle().fill(border).frame(width: 1, height: 30)
                metric("MEASURED RATE", value: camera.isRunning ? "\(camera.framesPerSecond) FPS" : "--")
                Rectangle().fill(border).frame(width: 1, height: 30)
                metric("VIDEO SAVED", value: "NEVER")
            }
            .padding(.vertical, 12)
        }
        .padding(10)
        .background(surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(border, lineWidth: 1))
    }

    private var controlsColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WHAT MIRA SEES")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(muted)
            Text(camera.prediction?.gesture.rawValue ?? "Unknown")
                .font(.system(size: 29, weight: .regular, design: .serif))
                .foregroundStyle(ink)
                .padding(.top, 10)
            HStack(spacing: 4) {
                ForEach(0..<12) { index in
                    Capsule()
                        .fill(Double(index) < camera.stabilityProgress * 12 ? accent : border)
                        .frame(height: 4)
                }
            }
            .padding(.top, 14)
            HStack {
                Text(camera.stabilityProgress >= 1 ? "TRIGGERED" : camera.prediction == nil ? "WAITING FOR CLEAR POSE" : "HOLD STEADY")
                Spacer()
                if let prediction = camera.prediction {
                    Text("\(Int(prediction.confidence * 100))%")
                }
            }
            .font(.system(size: 8, weight: .semibold, design: .monospaced))
            .foregroundStyle(muted)
            .padding(.top, 8)

            Rectangle().fill(border).frame(height: 1).padding(.vertical, 22)
            HStack(alignment: .firstTextBaseline) {
                Text("YOUR CONTROLS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(muted)
                Spacer()
                Text("EDIT ANY TIME")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(muted.opacity(0.75))
            }
            .padding(.bottom, 7)
            LazyVGrid(columns: bindingColumns, alignment: .leading, spacing: 7) {
                ForEach(HandGesture.allCases) { gesture in
                    bindingCell(gesture)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("LAST ACTION")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(muted)
                Text(pointer.isEnabled ? pointer.status : actionStatus)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ink)
                    .lineLimit(2)
            }
            .padding(.top, 16)
        }
        .padding(.top, 4)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.shield").font(.system(size: 10))
            Text("LANDMARKS STAY ON THIS MAC. CAMERA FRAMES ARE DISCARDED.")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(0.3)
            Spacer()
            Text("MIRA  ·  PERSONAL HAND PROFILE")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundStyle(muted.opacity(0.8))
        }
        .foregroundStyle(muted)
        .padding(.horizontal, 30)
        .padding(.vertical, 12)
        .background(surface)
        .overlay(alignment: .top) { Rectangle().fill(border).frame(height: 1) }
    }

    private func metric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(muted)
            Text(value).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 9)
    }

    private func openPrivacySettings(_ pane: String) {
        if let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) {
            NSWorkspace.shared.open(url)
        }
    }

    private func migrateActionBindings() {
        let allowed = Set(MIRAAction.allCases.map { $0.rawValue })
        for gesture in HandGesture.allCases {
            let value = binding(for: gesture)
            switch value.wrappedValue {
            case "volumeUp", "volumeDown":
                value.wrappedValue = MIRAAction.volumeControl.rawValue
            case "openSafari", "newBrowserTab", "closeBrowserTab":
                value.wrappedValue = MIRAAction.chromeTabToggle.rawValue
            default:
                if !allowed.contains(value.wrappedValue) {
                    value.wrappedValue = MIRAAction.disabled.rawValue
                }
            }
        }
    }

    private func binding(for gesture: HandGesture) -> Binding<String> {
        switch gesture {
        case .fist: $fistAction
        case .openPalm: $palmAction
        case .thumbsUp: $thumbsAction
        case .thumbsDown: $thumbsDownAction
        case .three: $threeAction
        case .peace: $peaceAction
        case .pointUp: $pointAction
        case .pointDown: $pointDownAction
        case .pointLeft: $pointLeftAction
        case .pointRight: $pointRightAction
        case .ok: $okAction
        case .rock: $rockAction
        case .shaka: $shakaAction
        }
    }

    private func bindingCell(_ gesture: HandGesture) -> some View {
        HStack(spacing: 4) {
            Text(symbol(for: gesture))
                .font(.system(size: 14))
                .frame(width: 18)
            Text(gesture.rawValue)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 100, alignment: .leading)
            Picker(gesture.rawValue, selection: binding(for: gesture)) {
                ForEach(MIRAAction.allCases) { action in
                    Text(action.title).tag(action.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .trailing)
            Button {
                testBoundAction(for: gesture)
            } label: {
                Image(systemName: "play.circle")
                    .font(.system(size: 13))
                    .foregroundStyle(accent)
            }
            .buttonStyle(.plain)
            .help("Test this action")
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(border.opacity(0.7)).frame(height: 1) }
    }

    private func symbol(for gesture: HandGesture) -> String {
        switch gesture {
        case .fist: "✊"
        case .openPalm: "✋"
        case .thumbsUp: "👍"
        case .thumbsDown: "👎"
        case .three: "🖖"
        case .peace: "✌️"
        case .pointUp: "☝️"
        case .pointDown: "👇"
        case .pointLeft: "👈"
        case .pointRight: "👉"
        case .ok: "👌"
        case .rock: "🤘"
        case .shaka: "🤙"
        }
    }

    private func runBoundAction() {
        guard !pointer.isEnabled else { return }
        guard let gesture = camera.lastTriggeredGesture,
              let action = MIRAAction(rawValue: binding(for: gesture).wrappedValue)
        else { return }

        if action == .cursorControl {
            if pointer.isEnabled || actionsEnabled {
                execute(action, prefix: "")
            } else {
                actionStatus = "Enable Actions to enter cursor mode"
            }
            return
        }

        if action == .toggleActions {
            execute(action, prefix: "")
            return
        }

        guard !pointer.isEnabled else { return }
        guard actionsEnabled else {
            actionStatus = "\(gesture.rawValue) recognized · actions paused"
            return
        }
        execute(
            action,
            prefix: "",
            volumeDirection: gesture == .thumbsDown || gesture == .pointDown ? -10 : 10
        )
    }

    private func testBoundAction(for gesture: HandGesture) {
        guard !pointer.isEnabled else {
            actionStatus = "Turn Cursor Control off before testing actions"
            return
        }
        guard let action = MIRAAction(
            rawValue: binding(for: gesture).wrappedValue
        ) else { return }
        execute(
            action,
            prefix: "Test: ",
            volumeDirection: gesture == .thumbsDown || gesture == .pointDown ? -10 : 10
        )
    }

    private func execute(
        _ action: MIRAAction,
        prefix: String,
        volumeDirection: Int = 10
    ) {
        if action == .cursorControl {
            actionStatus = "Use the Cursor Control switch in the toolbar"
            return
        }
        if action == .toggleActions {
            actionsEnabled.toggle()
            if !actionsEnabled { pointer.stop() }
            actionStatus = actionsEnabled ? "Gesture actions resumed" : "Gesture actions paused"
            return
        }
        ActionExecutor.execute(action, volumeDirection: volumeDirection) {
            result in actionStatus = prefix + result
        }
    }
}
