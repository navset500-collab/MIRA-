import AVFoundation
import AppKit
import Combine
import CoreGraphics
import Foundation
import MIRACore
import QuartzCore
import Vision

struct HandLandmark: Identifiable, Equatable {
    let id: String
    let x: CGFloat
    let y: CGFloat
    let confidence: Float
    var isDerived = false
}

final class HandCameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published private(set) var cameraStatus = "Camera off"
    @Published private(set) var isRunning = false
    @Published private(set) var isStarting = false
    @Published private(set) var landmarks: [HandLandmark] = []
    @Published private(set) var hasValidPoseFeatures = false
    @Published private(set) var imageSize = CGSize(width: 1280, height: 720)
    @Published private(set) var prediction: GesturePrediction?
    @Published private(set) var stabilityProgress = 0.0
    @Published private(set) var framesPerSecond = 0
    @Published private(set) var cursorFrameNumber: UInt64 = 0
    @Published private(set) var calibrationTarget: HandGesture?
    @Published private(set) var calibrationProgress = 0.0
    @Published private(set) var calibrationMessage = "Show the requested gesture, then capture."
    @Published private(set) var calibrationRound = 1
    @Published private(set) var completedCalibrationRounds = 0
    @Published private(set) var calibrationRoundsComplete: [HandGesture: Int] = [:]
    @Published private(set) var completedCalibration: Set<HandGesture> = []
    @Published private(set) var sessionCalibratedGestures: Set<HandGesture> = []
    @Published private(set) var triggerID = UUID()
    @Published private(set) var lastTriggeredGesture: HandGesture?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "mira.camera.session")
    private let visionQueue = DispatchQueue(label: "mira.vision.frames", qos: .userInitiated)
    private let classifier = GestureClassifier()
    private let mediaPipe = MediaPipeBridge()
    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        return request
    }()
    private var stabilizer = TemporalStabilizer()
    private var templates: [HandGesture: GestureFeatures] = [:]
    private var calibrationSamples: [GestureFeatures] = []
    private var activeCalibrationGesture: HandGesture?
    private var calibrationCaptureID = UUID()
    private var samplesByGesture: [HandGesture: [GestureFeatures]] = [:]
    private var roundsByGesture: [HandGesture: Int] = [:]
    private let calibrationSampleCount = 36
    private let calibrationRoundCount = 1
    private var isConfigured = false
    private var frameWindowStart = CACurrentMediaTime()
    private var framesInWindow = 0
    private var lastProcessedAt = 0.0
    private var lastUIUpdateAt = 0.0
    private let processingInterval = 1.0 / 18.0
    private let uiUpdateInterval = 1.0 / 12.0

    override init() {
        if let data = UserDefaults.standard.data(forKey: "mira.gestureTemplates"),
           let saved = try? JSONDecoder().decode([HandGesture: GestureFeatures].self, from: data) {
            templates = saved
            completedCalibration = Set(saved.keys)
        }
        super.init()
    }

    func collectCalibrationSample(for gesture: HandGesture) {
        visionQueue.async { [weak self] in
            guard let self,
                  self.activeCalibrationGesture == nil,
                  (self.roundsByGesture[gesture] ?? 0) < self.calibrationRoundCount
            else { return }

            let round = (self.roundsByGesture[gesture] ?? 0) + 1
            let captureID = UUID()
            self.calibrationCaptureID = captureID
            self.activeCalibrationGesture = gesture
            self.calibrationSamples = []

            DispatchQueue.main.async {
                self.calibrationTarget = gesture
                self.calibrationRound = round
                self.completedCalibrationRounds = round - 1
                self.calibrationProgress = 0
                self.calibrationMessage = "Hold \(gesture.rawValue) steady."
            }

            self.visionQueue.asyncAfter(deadline: .now() + 20) { [weak self] in
                guard let self,
                      self.calibrationCaptureID == captureID,
                      self.activeCalibrationGesture == gesture
                else { return }

                self.activeCalibrationGesture = nil
                self.calibrationCaptureID = UUID()
                self.calibrationSamples = []

                DispatchQueue.main.async {
                    self.calibrationTarget = nil
                    self.calibrationProgress = 0
                    self.calibrationMessage =
                        "Capture timed out. Check lighting and hand position, then try again."
                }
            }
        }
    }

    func resetCalibrationSession() {
        visionQueue.async { [weak self] in
            guard let self else { return }
            self.activeCalibrationGesture = nil
            self.calibrationCaptureID = UUID()
            self.calibrationSamples = []
            self.samplesByGesture = [:]
            self.roundsByGesture = [:]
            DispatchQueue.main.async {
                self.calibrationProgress = 0
                self.calibrationTarget = nil
                self.calibrationRound = 1
                self.completedCalibrationRounds = 0
                self.calibrationRoundsComplete = [:]
                self.sessionCalibratedGestures = []
                self.calibrationMessage = "Show the requested gesture, then capture."
            }
        }
    }

    func start() {
        DispatchQueue.main.async {
            self.cameraStatus = "Requesting camera access"
            self.isStarting = true
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                self.configureAndStart()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        self.sessionQueue.async { self.configureAndStart() }
                    } else {
                        self.publishStatus("Camera access denied")
                    }
                }
            case .denied, .restricted:
                self.publishStatus("Allow camera access in System Settings")
            @unknown default:
                self.publishStatus("Camera access unavailable")
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.isRunning = false
                self.isStarting = false
                self.cameraStatus = "Camera off"
                self.landmarks = []
                self.hasValidPoseFeatures = false
                self.prediction = nil
            }
        }
    }

    func openCameraSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    private func configureAndStart() {
        guard !isConfigured else {
            session.startRunning()
            publishRunning()
            return
        }

        session.beginConfiguration()
        session.sessionPreset = session.canSetSessionPreset(.hd1280x720) ? .hd1280x720 : .high
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            publishStatus("No camera found")
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: visionQueue)
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            publishStatus("Could not start camera feed")
            return
        }

        session.addInput(input)
        session.addOutput(output)
        if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        isConfigured = true
        session.commitConfiguration()
        session.startRunning()
        publishRunning()

        if let python = URL(string: "file:///Users/navrajsinghsethi/Documents/GitHub/MIRA/Prototypes/mira_next/.venv/bin/python"),
           let model = URL(string: "file:///Users/navrajsinghsethi/Documents/GitHub/MIRA/Prototypes/mira_next/hand_landmarker.task") {
            mediaPipe.start(executable: python, model: model) { [weak self] landmarks in
                self?.handleMediaPipeLandmarks(landmarks)
            }
        }
    }

    private func handleMediaPipeLandmarks(_ landmarks: [HandLandmark]) {
        guard !landmarks.isEmpty else {
            hasValidPoseFeatures = false
            if isRunning { cameraStatus = "Searching for a hand" }
            cursorFrameNumber &+= 1
            return
        }

        self.landmarks = landmarks
        hasValidPoseFeatures = landmarks.count >= 12
        imageSize = CGSize(width: 1280, height: 720)
        if isRunning { cameraStatus = "Hand tracked (MediaPipe)" }
        cursorFrameNumber &+= 1
    }

    private func publishStatus(_ status: String) {
        DispatchQueue.main.async {
            self.cameraStatus = status
            self.isRunning = false
            self.isStarting = false
        }
    }

    private func publishRunning() {
        DispatchQueue.main.async {
            self.cameraStatus = "Camera live"
            self.isRunning = true
            self.isStarting = false
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frameSize = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        let now = CACurrentMediaTime()
        guard now - lastProcessedAt >= processingInterval else { return }
        lastProcessedAt = now

        if mediaPipe.isReady {
            mediaPipe.send(
                pixelBuffer: pixelBuffer,
                width: Int(frameSize.width),
                height: Int(frameSize.height)
            )
            updateFPS()
            return
        }

        do {
            try VNImageRequestHandler(cvPixelBuffer: pixelBuffer).perform([handPoseRequest])
            let observations = handPoseRequest.results ?? []
            let rawCursorLandmarks = observations.first.map(makeCursorLandmarks) ?? []
            let results = observations.compactMap(makeHandResult)
            let result = results.max { $0.trackingConfidence < $1.trackingConfidence }
            let event = stabilizer.observe(result?.prediction?.gesture, at: now)
            let stableProgress = event == nil ? stabilizer.progress(at: now) : 1
            collectCalibrationFrame(result)
            updateFPS()
            guard now - lastUIUpdateAt >= uiUpdateInterval || event != nil else { return }
            lastUIUpdateAt = now
            DispatchQueue.main.async {
                self.landmarks = result?.landmarks ?? rawCursorLandmarks
                self.hasValidPoseFeatures = (result?.features?.trackingConfidence ?? 0) >= 0.45
                self.imageSize = frameSize
                self.prediction = result?.prediction
                self.stabilityProgress = stableProgress
                if let event {
                    self.lastTriggeredGesture = event
                    self.triggerID = UUID()
                }
                if self.isRunning {
                    self.cameraStatus = result == nil ? "Searching for a hand" : "Hand tracked"
                }
                self.cursorFrameNumber &+= 1
            }
        } catch {
            DispatchQueue.main.async {
                self.cameraStatus = "Vision tracking unavailable"
            }
        }
    }

    private func updateFPS() {
        framesInWindow += 1
        let now = CACurrentMediaTime()
        if now - frameWindowStart >= 1 {
            let measuredFPS = framesInWindow
            framesInWindow = 0
            frameWindowStart = now
            DispatchQueue.main.async { self.framesPerSecond = measuredFPS }
        }
    }

    private func makeCursorLandmarks(
        _ observation: VNHumanHandPoseObservation
    ) -> [HandLandmark] {
        let joints: [(VNHumanHandPoseObservation.JointName, String)] = [
            (.wrist, "wrist"),
            (.thumbCMC, "thumbCMC"),
            (.thumbMP, "thumbMP"),
            (.thumbIP, "thumbIP"),
            (.thumbTip, "thumbTip"),
            (.indexMCP, "indexMCP"),
            (.indexPIP, "indexPIP"),
            (.indexDIP, "indexDIP"),
            (.indexTip, "indexTip"),
            (.middleMCP, "middleMCP"),
            (.middlePIP, "middlePIP"),
            (.middleDIP, "middleDIP"),
            (.middleTip, "middleTip"),
            (.ringMCP, "ringMCP"),
            (.ringPIP, "ringPIP"),
            (.ringDIP, "ringDIP"),
            (.ringTip, "ringTip"),
            (.littleMCP, "littleMCP"),
            (.littlePIP, "littlePIP"),
            (.littleDIP, "littleDIP"),
            (.littleTip, "littleTip")
        ]

        return joints.compactMap { joint, name in
            guard let point = try? observation.recognizedPoint(joint),
                  point.confidence >= 0.10 else { return nil }
            return HandLandmark(
                id: name,
                x: point.location.x,
                y: point.location.y,
                confidence: point.confidence
            )
        }
    }

    private func makeHandResult(_ observation: VNHumanHandPoseObservation) -> HandResult? {
        let joints: [(VNHumanHandPoseObservation.JointName, String)] = [
            (.wrist, "wrist"),
            (.thumbCMC, "thumbCMC"), (.thumbMP, "thumbMP"), (.thumbIP, "thumbIP"), (.thumbTip, "thumbTip"),
            (.indexMCP, "indexMCP"), (.indexPIP, "indexPIP"), (.indexDIP, "indexDIP"), (.indexTip, "indexTip"),
            (.middleMCP, "middleMCP"), (.middlePIP, "middlePIP"), (.middleDIP, "middleDIP"), (.middleTip, "middleTip"),
            (.ringMCP, "ringMCP"), (.ringPIP, "ringPIP"), (.ringDIP, "ringDIP"), (.ringTip, "ringTip"),
            (.littleMCP, "littleMCP"), (.littlePIP, "littlePIP"), (.littleDIP, "littleDIP"), (.littleTip, "littleTip")
        ]

        var points: [String: VNRecognizedPoint] = [:]
        for (joint, name) in joints {
            if let point = try? observation.recognizedPoint(joint) {
                points[name] = point
            }
        }
        func point(_ name: String) -> CGPoint? { points[name]?.location }
        func confidence(_ name: String) -> Double { Double(points[name]?.confidence ?? 0) }
        guard let wrist = point("wrist"), let middleMCP = point("middleMCP"),
              confidence("wrist") >= 0.08, confidence("middleMCP") >= 0.08,
              points.values.filter({ $0.confidence >= 0.08 }).count >= 8 else {
            return nil
        }

        func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
            hypot(first.x - second.x, first.y - second.y)
        }

        let palmScale = distance(wrist, middleMCP)
        guard palmScale > 0.001 else { return nil }
        let anchorNames = ["wrist", "indexMCP", "middleMCP", "ringMCP", "littleMCP"]
            .filter { confidence($0) >= 0.08 }
        let visibleAnchors = anchorNames.compactMap(point)
        let palmCenter = CGPoint(
            x: visibleAnchors.reduce(0) { $0 + $1.x } / CGFloat(visibleAnchors.count),
            y: visibleAnchors.reduce(0) { $0 + $1.y } / CGFloat(visibleAnchors.count)
        )

        let landmarks = joints.compactMap { _, name -> HandLandmark? in
            guard let value = points[name] else { return nil }
            guard value.confidence >= 0.08 else { return nil }
            return HandLandmark(id: name, x: value.location.x, y: value.location.y, confidence: value.confidence)
        }
        var visibleLandmarks = landmarks
        visibleLandmarks.append(HandLandmark(id: "palm-center", x: palmCenter.x, y: palmCenter.y, confidence: 1, isDerived: true))

        let featureNames = [
            "indexTip", "indexPIP", "middleTip", "middlePIP", "ringTip", "ringPIP",
            "littleTip", "littlePIP", "thumbTip", "thumbMP", "indexMCP"
        ]
        let features: GestureFeatures? = {
            guard featureNames.allSatisfy({ points[$0] != nil && confidence($0) >= 0.08 }) else { return nil }
            func extensionScore(_ tip: String, _ pip: String) -> Double {
                Double((distance(wrist, point(tip)!) - distance(wrist, point(pip)!)) / palmScale)
            }
            let ratios: [Finger: Double] = [
                .index: extensionScore("indexTip", "indexPIP"),
                .middle: extensionScore("middleTip", "middlePIP"),
                .ring: extensionScore("ringTip", "ringPIP"),
                .little: extensionScore("littleTip", "littlePIP")
            ]
            let thumbLift = Double((point("thumbTip")!.y - point("thumbMP")!.y) / palmScale)
            let thumbSpread = Double(distance(point("thumbTip")!, point("indexMCP")!) / palmScale)
            let thumbIndexGap: Double
            if let indexTip = point("indexTip"), confidence("indexTip") >= 0.08 {
                thumbIndexGap = Double(distance(point("thumbTip")!, indexTip) / palmScale)
            } else {
                thumbIndexGap = 1
            }
            let indexLift = Double((point("indexTip")!.y - point("indexPIP")!.y) / palmScale)
            let indexSide = Double((point("indexTip")!.x - point("indexPIP")!.x) / palmScale)
            let featureConfidence = featureNames.reduce(0.0) { $0 + confidence($1) } / Double(featureNames.count)
            return GestureFeatures(
                extensionRatios: ratios,
                thumbExtension: thumbSpread,
                thumbLift: thumbLift,
                thumbIndexGap: thumbIndexGap,
                indexLift: indexLift,
                indexSide: indexSide,
                trackingConfidence: featureConfidence
            )
        }()
        return HandResult(
            landmarks: visibleLandmarks,
            prediction: features.flatMap { classifier.classify($0, templates: templates) },
            features: features,
            trackingConfidence: anchorNames.reduce(0.0) { $0 + confidence($1) } / Double(anchorNames.count)
        )
    }

    private func collectCalibrationFrame(_ result: HandResult?) {
        guard let calibrationTarget = activeCalibrationGesture else { return }

        guard let features = result?.features,
              features.trackingConfidence >= 0.45,
              let prediction = result?.prediction,
              prediction.gesture == calibrationTarget,
              prediction.confidence >= 0.35
        else {
            calibrationSamples.removeAll(keepingCapacity: true)
            let detected = result?.prediction?.gesture
            DispatchQueue.main.async {
                self.calibrationProgress = 0
                if let detected, detected != calibrationTarget {
                    self.calibrationMessage =
                        "Detected \(detected.rawValue). Please show \(calibrationTarget.rawValue)."
                } else {
                    self.calibrationMessage =
                        "Keep \(calibrationTarget.rawValue) clearly visible and steady."
                }
            }
            return
        }

        calibrationSamples.append(features)
        let progress = Double(calibrationSamples.count) / Double(calibrationSampleCount)
        guard calibrationSamples.count >= calibrationSampleCount,
              let average = GestureFeatures.average(calibrationSamples)
        else {
            DispatchQueue.main.async { self.calibrationProgress = progress }
            return
        }

        let gesture = calibrationTarget
        let completedRounds = (roundsByGesture[gesture] ?? 0) + 1
        roundsByGesture[gesture] = completedRounds
        samplesByGesture[gesture, default: []].append(average)
        if completedRounds >= calibrationRoundCount,
           let personalizedAverage = GestureFeatures.average(samplesByGesture[gesture] ?? []) {
            templates[gesture] = personalizedAverage
            completedCalibration.insert(gesture)
            if let data = try? JSONEncoder().encode(templates) {
                UserDefaults.standard.set(data, forKey: "mira.gestureTemplates")
            }
        }
        calibrationSamples = []
        activeCalibrationGesture = nil
        calibrationCaptureID = UUID()
        DispatchQueue.main.async {
            self.calibrationMessage = "\(gesture.rawValue) captured."
            self.calibrationProgress = 1
            self.calibrationTarget = nil
            self.calibrationRound = min(completedRounds + 1, self.calibrationRoundCount)
            self.completedCalibrationRounds = completedRounds
            self.calibrationRoundsComplete[gesture] = completedRounds
            if completedRounds >= self.calibrationRoundCount {
                self.completedCalibration = self.completedCalibration.union([gesture])
                self.sessionCalibratedGestures = self.sessionCalibratedGestures.union([gesture])
            }
        }
    }
}

private struct HandResult {
    let landmarks: [HandLandmark]
    let prediction: GesturePrediction?
    let features: GestureFeatures?
    let trackingConfidence: Double
}