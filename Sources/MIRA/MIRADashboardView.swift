import AppKit
import ApplicationServices
import MIRACore
import SwiftUI

struct MIRADashboardView: View {
    let onRecalibrate: () -> Void

    @StateObject private var camera = HandCameraModel()
    @StateObject private var pointer = PointerController()
    @State private var actionStatus = "Ready when you are"
    @State private var showingPersonalization = false
    @State private var showingCursorCalibration = false
    @AppStorage("mira.actionsEnabled") private var actionsEnabled = false
    private var feedbackEnabled: Bool {
        actionsEnabled || pointer.isEnabled
    }
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
            if showingPersonalization {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Make MIRA yours.")
                                .font(.system(size: 30, weight: .regular, design: .serif))
                                .foregroundStyle(ink)
                            Text("Choose your action bindings here. Cursor Control has its own fixed gestures.")
                                .font(.system(size: 13))
                                .foregroundStyle(muted)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("HOVER INDICATION")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(muted)
                            Text("Show a small floating notice when MIRA recognizes a gesture or completes an action, even while another app is in front.")
                                .font(.system(size: 12))
                                .foregroundStyle(ink)
                            Text("Automatic: on while Actions or Cursor Control is on.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(accent)
                            Text("Notices last three seconds. Turn both modes off to hide them.")
                                .font(.system(size: 10))
                                .foregroundStyle(muted)
                        }
                        .padding(20)
                        .background(surface, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(border, lineWidth: 1)
                        )

                        controlsColumn
                    }
                    .frame(maxWidth: 700, alignment: .leading)
                    .padding(30)
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(pointer.isEnabled ? "CURSOR CONTROL" : "CAMERA WORKSPACE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent)

                            Text(pointer.isEnabled
                                ? "Open Palm → move · Fist → click · Index + Middle → scroll"
                                : "Enable Actions for your shortcuts, or Cursor Control for movement and clicking.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(ink)
                        }
                        Spacer()
                        Text(pointer.isEnabled ? "ASSIGNED ACTIONS PAUSED" : "PERSONALIZE IN SETTINGS")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(muted)
                    }

                    cameraPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    HStack {
                        Text(pointer.isEnabled ? pointer.status : actionStatus)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(ink)
                            .lineLimit(2)
                        Spacer()
                        if pointer.isEnabled {
                            Text("Primary display · Open hand again before another click")
                                .font(.system(size: 10))
                                .foregroundStyle(muted)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            footer
        }
        .background(paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear {
            UserDefaults.standard.set(
                pointer.isEnabled,
                forKey: "mira.cursor.feedbackActive"
            )
            UserDefaults.standard.set(
                feedbackEnabled,
                forKey: "mira.feedbackEnabled"
            )
            FeedbackCenter.dismissWhenModesOff()
            TargetAppTracker.shared.start()
            migrateActionBindings()
        }
        .onChange(of: actionsEnabled) { _, enabled in
            if enabled { pointer.stop() }
            UserDefaults.standard.set(
                feedbackEnabled,
                forKey: "mira.feedbackEnabled"
            )
            if !feedbackEnabled {
                FeedbackCenter.dismissWhenModesOff()
            }
        }
        .onChange(of: pointer.isEnabled) { _, enabled in
            if enabled { actionsEnabled = false }
            UserDefaults.standard.set(
                feedbackEnabled,
                forKey: "mira.feedbackEnabled"
            )
            if !feedbackEnabled {
                FeedbackCenter.dismissWhenModesOff()
            }
        }
        // mira.spotifyAndRecognition.v1
        .onChange(of: camera.prediction?.gesture) { _, gesture in
            guard feedbackEnabled, let gesture else { return }
            FeedbackCenter.show(
                "MIRA sees: \(gesture.rawValue)",
                kind: .success
            )
        }
        .onChange(of: camera.triggerID) { _, _ in
            runBoundAction()
        }
        .onChange(of: pointer.status) { _, status in
            guard feedbackEnabled else { return }

            if status.hasPrefix("Scrolling") {
                FeedbackCenter.show(
                    "MIRA: Index + Middle → Scroll mode",
                    kind: .success
                )
            } else if status.hasPrefix("Click sent") {
                FeedbackCenter.show(status, kind: .success)
            } else if status.localizedCaseInsensitiveContains("paused") {
                FeedbackCenter.show(status, kind: .warning)
            }
        }
        .onAppear {
            pointer.connect(to: camera)
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

            Button(showingPersonalization ? "Camera" : "Personalize") {
                pointer.stop()
                actionsEnabled = false
                showingPersonalization.toggle()
            }
            .buttonStyle(.bordered)
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
                .disabled(!camera.isRunning || showingPersonalization)
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
        GeometryReader { geometry in
            ZStack {
                CameraPreview(session: camera.session)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )

                HandSkeleton(
                    landmarks: camera.landmarks,
                    imageSize: camera.imageSize
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(camera.isRunning ? accent : muted)
                            .frame(width: 8, height: 8)
                        Text(camera.cameraStatus.uppercased())
                            .font(.system(
                                size: 11,
                                weight: .semibold,
                                design: .monospaced
                            ))
                        Spacer()
                        Text(
                            "\(camera.framesPerSecond) FPS"
                            + " · \(camera.landmarks.count) POINTS"
                            + " · ACCESS: \(AXIsProcessTrusted() ? "YES" : "NO")"
                        )
                        .font(.system(
                            size: 10,
                            weight: .medium,
                            design: .monospaced
                        ))
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.65))

                    Spacer()

                    VStack(alignment: .leading, spacing: 5) {
                        Text(pointer.isEnabled
                            ? "OPEN PALM → MOVE   ·   FIST → CLICK"
                            : "SHOW YOUR HAND CLEARLY IN THE CAMERA")
                            .font(.system(
                                size: 12,
                                weight: .semibold,
                                design: .monospaced
                            ))

                        Text(pointer.status)
                            .font(.system(size: 12))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.black.opacity(0.65))
                }

                if !camera.isRunning || camera.landmarks.isEmpty {
                    VStack(spacing: 10) {
                        Text(camera.isRunning
                            ? "Keep your whole hand in view"
                            : "Start the camera")
                            .font(.system(
                                size: 22,
                                weight: .medium,
                                design: .serif
                            ))

                        Text(camera.cameraStatus)
                            .font(.system(size: 12))

                        if camera.cameraStatus.contains("Settings")
                            || camera.cameraStatus.contains("denied") {
                            Button("Open Camera Settings") {
                                camera.openCameraSettings()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(22)
                    .background(
                        .black.opacity(0.65),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(border, lineWidth: 1)
            )
        }
        .frame(minHeight: 420)
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
            case "previousTrack", "nextTrack", "spotifyPlayPause":
                let replacement: MIRAAction
                switch value.wrappedValue {
                case "previousTrack":
                    replacement = .cursorControl
                case "nextTrack":
                    replacement = .stockMarket
                default:
                    replacement = .playPauseMusic
                }

                let alreadyAssigned = HandGesture.allCases.contains {
                    $0 != gesture &&
                    binding(for: $0).wrappedValue == replacement.rawValue
                }

                value.wrappedValue = alreadyAssigned
                    ? MIRAAction.disabled.rawValue
                    : replacement.rawValue

            case "openMessenger":
                value.wrappedValue = MIRAAction.openInstagram.rawValue
            case "volumeControl":
                value.wrappedValue = MIRAAction.volumeUp.rawValue
            case "openGoogleDocs":
                value.wrappedValue = MIRAAction.stockMarket.rawValue
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

    private func validatedBinding(for gesture: HandGesture) -> Binding<String> {
        Binding<String>(
            get: { binding(for: gesture).wrappedValue },
            set: { newValue in
                let disabled = MIRAAction.disabled.rawValue

                if newValue == MIRAAction.cursorControl.rawValue,
                   gesture == .openPalm || gesture == .fist || gesture == .peace {
                    actionStatus = "Choose another gesture for Cursor Control: Open Palm, Fist, and Peace are used inside cursor mode."
                    FeedbackCenter.show(actionStatus, kind: .warning)
                    return
                }

                guard newValue != disabled else {
                    binding(for: gesture).wrappedValue = newValue
                    actionStatus = "\(gesture.rawValue) is disabled"
                    return
                }

                if let conflict = HandGesture.allCases.first(where: {
                    $0 != gesture && binding(for: $0).wrappedValue == newValue
                }) {
                    let title = MIRAAction(rawValue: newValue)?.title ?? newValue
                    actionStatus = "\(conflict.rawValue) already uses \(title). Choose a different action."
                    FeedbackCenter.show(actionStatus, kind: .warning)
                    return
                }

                binding(for: gesture).wrappedValue = newValue
                let title = MIRAAction(rawValue: newValue)?.title ?? newValue
                actionStatus = "\(gesture.rawValue) assigned to \(title)"
                FeedbackCenter.show(
                    "MIRA: \(gesture.rawValue) → \(title)",
                    kind: .success
                )
            }
        )
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
            Picker(gesture.rawValue, selection: validatedBinding(for: gesture)) {
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

    // mira.assignableCursor.twoFinger.v2
    private func runBoundAction() {
        guard let gesture = camera.lastTriggeredGesture,
              let action = MIRAAction(
                rawValue: binding(for: gesture).wrappedValue
              ) else { return }

        // Cursor-mode gestures must not also trigger shortcuts.
        // Keep the assigned toggle on a different gesture.
        if pointer.isEnabled {
            if gesture == .openPalm || gesture == .fist || gesture == .peace {
                return
            }
            guard action == .cursorControl else { return }
            execute(action, prefix: "")
            return
        }

        // Mode switches remain reachable while ordinary actions are paused.
        if action == .cursorControl || action == .toggleActions {
            execute(action, prefix: "")
            return
        }

        guard actionsEnabled else {
            actionStatus = "\(gesture.rawValue) recognized · actions paused"
            return
        }

        execute(
            action,
            prefix: "",
            volumeDirection:
                gesture == .thumbsDown || gesture == .pointDown ? -10 : 10
        )
    }

    private func testBoundAction(for gesture: HandGesture) {
        guard let action = MIRAAction(
            rawValue: binding(for: gesture).wrappedValue
        ) else { return }
        guard !pointer.isEnabled || action == .cursorControl else {
            actionStatus = "Turn Cursor Control off before testing other actions"
            return
        }
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
            let enabling = !pointer.isEnabled
            pointer.setEnabled(enabling)
            if enabling { actionsEnabled = false }
            actionStatus = prefix + (enabling
                ? "Cursor Control on"
                : "Cursor Control off")
            if feedbackEnabled {
                FeedbackCenter.show(actionStatus, kind: .success)
            }
            return
        }
        if action == .toggleActions {
            actionsEnabled.toggle()
            if !actionsEnabled { pointer.stop() }
            actionStatus = actionsEnabled ? "Gesture actions resumed" : "Gesture actions paused"
            return
        }
        ActionExecutor.execute(action, volumeDirection: volumeDirection) {
            result in
            actionStatus = prefix + result
            guard feedbackEnabled else { return }

            let cleanResult = result
                .replacingOccurrences(of: prefix, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let failure = cleanResult.lowercased().contains("fail")
                || cleanResult.lowercased().contains("denied")
                || cleanResult.lowercased().contains("unavailable")
                || cleanResult.lowercased().contains("could not")

            let message: String
            if cleanResult.isEmpty {
                message = "MIRA understood: \(camera.lastTriggeredGesture?.rawValue ?? "gesture")"
            } else {
                message = "MIRA understood: \(camera.lastTriggeredGesture?.rawValue ?? "gesture") and \(cleanResult.prefix(1).lowercased())\(cleanResult.dropFirst())"
            }

            FeedbackCenter.show(
                message,
                kind: failure ? .warning : .success
            )
        }
    }
}
