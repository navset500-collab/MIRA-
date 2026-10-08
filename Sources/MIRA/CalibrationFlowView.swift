import MIRACore
import SwiftUI

struct CalibrationFlowView: View {
    let onFinish: () -> Void

    @StateObject private var camera = HandCameraModel()
    @State private var isCalibrating = false
    @State private var gestureIndex = 0

    private let paper = Color(red: 0.96, green: 0.965, blue: 0.95)
    private let ink = Color(red: 0.13, green: 0.16, blue: 0.15)
    private let muted = Color(red: 0.42, green: 0.47, blue: 0.44)
    private let accent = Color(red: 0.76, green: 0.31, blue: 0.22)
    private let border = Color(red: 0.86, green: 0.88, blue: 0.85)
    private let sea = Color(red: 0.15, green: 0.48, blue: 0.48)
    private let blue = Color(red: 0.31, green: 0.43, blue: 0.73)
    private let coral = Color(red: 0.84, green: 0.38, blue: 0.28)
    private let welcomeGestureColumns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    private let gestures = HandGesture.allCases

    var body: some View {
        VStack(spacing: 0) {
            header
            if isCalibrating {
                calibrationBody
            } else {
                welcomeBody
            }
            footer
        }
        .background(paper.ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear {
            gestureIndex = 0
        }
          .onChange(of: camera.sessionCalibratedGestures) { _, completed in
            guard isCalibrating, gestureIndex < gestures.count - 1,
                completed.contains(gestures[gestureIndex])
            else { return }
            gestureIndex += 1
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text("MIRA")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundStyle(ink)
                Text("Motion Interface for Real-Time Access")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(muted)
            }
            Spacer()
            Text(isCalibrating ? "HAND SETUP" : "WELCOME")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1)
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 34)
        .padding(.vertical, 18)
        .overlay(alignment: .bottom) { Rectangle().fill(border).frame(height: 1) }
    }

    private var welcomeBody: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 22)
                Text("Your gestures.\nYour commands.\nYour computer.")
                    .font(.system(size: 43, weight: .regular, design: .serif))
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("A personal, touch-free way to reach the controls you use every day.")
                    .font(.system(size: 13))
                    .foregroundStyle(muted)
                    .lineSpacing(4)
                    .padding(.top, 13)
                    .frame(maxWidth: 430, alignment: .leading)

                HStack(alignment: .top, spacing: 0) {
                    welcomeStep("01", title: "Learn", detail: "Show your hand.", color: sea)
                    welcomeStep("02", title: "Personalize", detail: "Build your profile.", color: blue)
                    welcomeStep("03", title: "Control", detail: "Choose commands.", color: coral)
                }
                .padding(.top, 30)

                Button {
                    seedBindings()
                    camera.resetCalibrationSession()
                    camera.start()
                    isCalibrating = true
                } label: {
                    HStack(spacing: 10) {
                        Text("Set up my hand")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 19)
                    .padding(.vertical, 12)
                    .background(accent, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.top, 27)

                HStack(spacing: 8) {
                    Image(systemName: "lock.shield").foregroundStyle(sea)
                    Text("On-device recognition · no video saved")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(muted)
                }
                .padding(.top, 16)
                Spacer(minLength: 22)
            }
            .padding(.leading, 52)
            .padding(.trailing, 36)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(sea)
                        .frame(width: 7, height: 7)
                    Text("A MORE NATURAL CONNECTION")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(muted)
                }

                ZStack {
                    Circle()
                        .fill(paper)
                        .frame(width: 170, height: 170)
                    Circle()
                        .stroke(border, lineWidth: 1)
                        .frame(width: 205, height: 205)
                    Image(systemName: "hand.raised")
                        .font(.system(size: 76, weight: .ultraLight))
                        .foregroundStyle(accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Less clicking.\nMore doing.")
                        .font(.system(size: 31, weight: .regular, design: .serif))
                        .foregroundStyle(ink)
                    Text("Turn a familiar hand gesture into a shortcut for your everyday tasks.")
                        .font(.system(size: 13))
                        .foregroundStyle(muted)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    welcomeFeature(
                        "hand.raised",
                        title: "Show a gesture",
                        detail: "Keep your hand clearly in view.",
                        color: sea
                    )
                    Rectangle().fill(border).frame(height: 1)
                    welcomeFeature(
                        "slider.horizontal.3",
                        title: "Make it yours",
                        detail: "Choose what each gesture does.",
                        color: blue
                    )
                    Rectangle().fill(border).frame(height: 1)
                    welcomeFeature(
                        "pause.circle",
                        title: "Stay in control",
                        detail: "Pause actions whenever you need.",
                        color: coral
                    )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 30)
            .frame(width: 370)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white)
            .overlay(alignment: .leading) {
                Rectangle().fill(border).frame(width: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var calibrationBody: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(spacing: 0) {
                ZStack {
                    CameraPreview(session: camera.session)
                    HandSkeleton(landmarks: camera.landmarks, imageSize: camera.imageSize)
                    if camera.landmarks.isEmpty {
                        VStack(spacing: 7) {
                            Text(camera.cameraStatus)
                            if camera.cameraStatus.contains("Settings") || camera.cameraStatus.contains("denied") {
                                Button("Open Camera Settings") { camera.openCameraSettings() }
                                    .buttonStyle(.link)
                            }
                        }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 385)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                HStack(spacing: 7) {
                    Circle().fill(camera.landmarks.isEmpty ? muted.opacity(0.35) : accent).frame(width: 7, height: 7)
                    Text(camera.landmarks.isEmpty ? "WAITING FOR A HAND" : "HAND TRACKED")
                    Spacer()
                    Text("LIVE HAND TRACKING")
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(muted)
                .padding(.top, 12)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%02d / %02d", gestureIndex + 1, gestures.count))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)
                Text("Let’s learn your hand.")
                    .font(.system(size: 27, weight: .regular, design: .serif))
                    .foregroundStyle(ink)
                    .padding(.top, 9)
                Text("Show each of the 13 gestures once using the same hand. Hold each pose steady while MIRA collects your hand measurements.")
                    .font(.system(size: 12))
                    .foregroundStyle(muted)
                    .lineSpacing(4)
                    .padding(.top, 9)
                HStack(spacing: 7) {
                    Circle().fill(camera.prediction == nil ? border : sea).frame(width: 7, height: 7)
                    Text(camera.prediction.map { "LIVE READ: \($0.gesture.rawValue.uppercased()) · \(Int($0.confidence * 100))%" } ?? "LIVE READ: WAITING FOR CLEAR POSE")
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(muted)
                }
                .padding(.top, 12)

                if camera.sessionCalibratedGestures.count < gestures.count {
                    let gesture = gestures[gestureIndex]
                    let completedRounds = camera.calibrationRoundsComplete[gesture] ?? 0
                    let activeRound = camera.calibrationTarget == gesture ? camera.calibrationRound : completedRounds + 1
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Text(symbol(for: gesture)).font(.system(size: 28))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(gesture.rawValue.uppercased())
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ink)
                                Text(instruction(for: gesture))
                                    .font(.system(size: 11))
                                    .foregroundStyle(muted)
                                Text(roundDescription(activeRound))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(sea)
                                    .padding(.top, 2)
                            }
                        }
                    }
                    .padding(15)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(border, lineWidth: 1))
                    .padding(.top, 23)

                    Text(camera.calibrationMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)

                    ProgressView(value: camera.calibrationTarget == gesture ? camera.calibrationProgress : 0)
                        .tint(accent)
                        .padding(.top, 16)
                          Text(camera.calibrationTarget == gesture
                                 ? "CAPTURING · \(Int(camera.calibrationProgress * 100))%"
                                 : completedRounds > 0
                                    ? "CAPTURE COMPLETE"
                                    : "ONE CAPTURE · HOLD YOUR POSE STEADY")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(muted)
                        .padding(.top, 8)

                    Button {
                        camera.collectCalibrationSample(for: gesture)
                    } label: {
                        Text(camera.calibrationTarget == gesture ? "Reading your hand…" : "Capture gesture")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(accent, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(camera.calibrationTarget != nil || !camera.hasValidPoseFeatures)
                    .opacity(camera.calibrationTarget != nil || !camera.hasValidPoseFeatures ? 0.55 : 1)
                    .padding(.top, 12)
                } else {
                    Text("Your hand profile is ready.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ink)
                        .padding(.top, 26)
                    Button("Open MIRA") {
                camera.stop()
                onFinish()
            }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(accent, in: RoundedRectangle(cornerRadius: 6))
                        .buttonStyle(.plain)
                        .padding(.top, 12)
                }

                Spacer(minLength: 12)
                Button("Back to introduction") {
                    camera.stop()
                    isCalibrating = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(muted)
            }
            .frame(width: 330, alignment: .leading)
            .padding(.top, 7)
        }
        .padding(28)
        .frame(maxWidth: 1080, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Text("MIRA  /  PRIVATE BY DESIGN")
            Spacer()
            Text(isCalibrating ? "LOCAL CAMERA · NO VIDEO SAVED" : "ON-DEVICE HAND RECOGNITION")
        }
        .font(.system(size: 8, weight: .medium, design: .monospaced))
        .tracking(0.6)
        .foregroundStyle(muted)
        .padding(.horizontal, 34)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { Rectangle().fill(border).frame(height: 1) }
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

    private func instruction(for gesture: HandGesture) -> String {
        switch gesture {
        case .fist: "Close your hand comfortably."
        case .openPalm: "Open your fingers toward the camera."
        case .thumbsUp: "Raise your thumb; curl the other fingers."
        case .thumbsDown: "Point your thumb down; curl the other fingers."
        case .three: "Raise your index, middle, and ring fingers; curl your little finger."
        case .peace: "Raise your index and middle fingers."
        case .pointUp: "Raise only your index finger upward."
        case .pointDown: "Extend only your index finger downward."
        case .pointLeft: "Extend only your index finger to the left."
        case .pointRight: "Extend only your index finger to the right."
        case .ok: "Touch thumb and index fingertips; extend the other fingers."
        case .rock: "Extend your index and little fingers."
        case .shaka: "Extend your thumb and little finger."
        }
    }

    private func roundDescription(_ round: Int) -> String {
        switch round {
        case 1: "Face your palm toward the camera at a comfortable distance."
        case 2: "Keep the pose and move your hand a little farther away."
        default: "Keep the pose and tilt your hand slightly to one side."
        }
    }

    private func welcomeStep(_ number: String, title: String, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(color).frame(width: 34, height: 3)
            Text(number)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(ink)
            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 16)
    }

    private func welcomeGesture(_ gesture: HandGesture, color: Color) -> some View {
        HStack(spacing: 7) {
            Text(symbol(for: gesture))
                .font(.system(size: 15))
                .frame(width: 20)
            Text(gesture.rawValue)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(.white.opacity(0.9))
            Spacer(minLength: 0)
            Circle().fill(color).frame(width: 4, height: 4)
        }
        .frame(maxWidth: .infinity, minHeight: 31, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.09)).frame(height: 1) }
    }

    private func welcomeAccent(_ index: Int) -> Color {
        switch index % 3 {
        case 0: sea
        case 1: blue
        default: coral
        }
    }


    private func welcomeFeature(
        _ icon: String,
        title: String,
        detail: String,
        color: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }

    private func seedBindings() {
        guard !UserDefaults.standard.bool(forKey: "mira.bindingsSeeded") else { return }
        let bindings: [String: MIRAAction] = [
            "binding.fist": .screenshot,
            "binding.openPalm": .playPauseMusic,
            "binding.thumbsUp": .openNotes,
            "binding.thumbsDown": .playPauseMusic,
            "binding.peace": .openSafari,
            "binding.pointUp": .openCalendar,
            "binding.pointDown": .openCalendar,
            "binding.pointLeft": .openNotes,
            "binding.pointRight": .openSafari,
            "binding.ok": .screenshot,
            "binding.rock": .openSafari,
            "binding.shaka": .playPauseMusic
        ]
        for (key, action) in bindings { UserDefaults.standard.set(action.rawValue, forKey: key) }
        UserDefaults.standard.set(true, forKey: "mira.bindingsSeeded")
    }
}