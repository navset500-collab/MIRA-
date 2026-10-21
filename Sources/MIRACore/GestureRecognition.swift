import Foundation

public enum Finger: String, CaseIterable, Hashable, Codable, Sendable {
    case index
    case middle
    case ring
    case little
}

public enum HandGesture: String, CaseIterable, Identifiable, Codable, Sendable {
    case fist = "Fist"
    case openPalm = "Open Palm"
    case thumbsUp = "Thumbs Up"
    case thumbsDown = "Thumbs Down"
    case peace = "Peace"
    case three = "Three Fingers"
    case pointUp = "Point Up"
    case pointDown = "Point Down"
    case pointLeft = "Point Left"
    case pointRight = "Point Right"
    case ok = "OK"
    case rock = "Rock"
    case shaka = "Shaka"

    public var id: String { rawValue }
}

public enum MIRAAction: String, CaseIterable, Identifiable, Sendable {
    // mira.stockMarket.separateVolume.v1
    case stockMarket

    case screenshot
    case playPauseMusic
    case nextTrack
    case previousTrack
    case volumeControl
    case openNotes
    case openCalendar
    case openGmail
    case openYouTube
    case openChatGPT
    case cursorControl
    case maximizeWindow
    case openInstagram
    case chromeTabToggle
    case openSpotify
    case spotifyPlayPause
    case minimizeWindow
    case toggleActions
    case disabled

    // Legacy values retained only for migration/source compatibility.
    case volumeUp, volumeDown, mute, openSafari
    case newBrowserTab, closeBrowserTab
    case openGoogleDocs, openGoogleDrive, openGoogleCalendar, openGitHub
    case copy, paste, undo, selectAll, nextTab, previousTab, hideApplication

    public static var allCases: [MIRAAction] {
        [
            .cursorControl,
            .maximizeWindow,
            .minimizeWindow,
            .screenshot,
            .stockMarket,
            .openNotes,
            .openCalendar,
            .openGmail,
            .openYouTube,
            .openChatGPT,
            .openInstagram,
            .chromeTabToggle,
            .openSpotify,
            .playPauseMusic,
            .volumeUp,
            .volumeDown,
            .toggleActions,
            .disabled,
        ]
    }

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cursorControl: return "Cursor Control On/Off"
        case .maximizeWindow: return "Maximize / Restore Window"
        case .minimizeWindow: return "Minimize Window"
        case .screenshot: return "Take Screenshot"
        case .stockMarket: return "Open/Close Stock Market in Chrome"
        case .openNotes: return "Open/Close Notes"
        case .openCalendar: return "Open/Close Calendar"
        case .openGmail: return "Open/Close Gmail"
        case .openYouTube: return "Open/Close YouTube"
        case .openChatGPT: return "Open/Close ChatGPT"
        case .openInstagram: return "Open/Close Instagram"
        case .chromeTabToggle: return "Open/Close Chrome Tab"
        case .openSpotify: return "Open/Close Spotify"
        case .playPauseMusic: return "Play/Pause Spotify"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .toggleActions: return "Actions On/Off"
        case .disabled: return "Disabled"
        default: return rawValue
        }
    }
}

public struct GestureFeatures: Codable, Equatable, Sendable {
    public let extensionRatios: [Finger: Double]
    public let thumbExtension: Double
    public let thumbLift: Double
    public let thumbIndexGap: Double
    public let indexLift: Double
    public let indexSide: Double
    public let trackingConfidence: Double

    public init(
        extensionRatios: [Finger: Double],
        thumbExtension: Double = 0,
        thumbLift: Double,
        thumbIndexGap: Double = 1,
        indexLift: Double,
        indexSide: Double = 0,
        trackingConfidence: Double
    ) {
        self.extensionRatios = extensionRatios
        self.thumbExtension = thumbExtension
        self.thumbLift = thumbLift
        self.thumbIndexGap = thumbIndexGap
        self.indexLift = indexLift
        self.indexSide = indexSide
        self.trackingConfidence = trackingConfidence
    }

    public static func average(_ samples: [GestureFeatures]) -> GestureFeatures? {
        guard !samples.isEmpty else { return nil }
        let ratios = Dictionary(uniqueKeysWithValues: Finger.allCases.map { finger in
            let mean = samples.reduce(0.0) { $0 + ($1.extensionRatios[finger] ?? 0) } / Double(samples.count)
            return (finger, mean)
        })
        func mean(_ value: (GestureFeatures) -> Double) -> Double {
            samples.reduce(0.0) { $0 + value($1) } / Double(samples.count)
        }
        return GestureFeatures(
            extensionRatios: ratios,
            thumbExtension: mean(\.thumbExtension),
            thumbLift: mean(\.thumbLift),
            thumbIndexGap: mean(\.thumbIndexGap),
            indexLift: mean(\.indexLift),
            indexSide: mean(\.indexSide),
            trackingConfidence: mean(\.trackingConfidence)
        )
    }
}

public struct GesturePrediction: Sendable {
    public let gesture: HandGesture
    public let confidence: Double
    public let runnerUpConfidence: Double
}

public struct GestureClassifier: Sendable {
    public init() {}

    public func classify(
        _ features: GestureFeatures,
        templates: [HandGesture: GestureFeatures] = [:]
    ) -> GesturePrediction? {
        guard features.trackingConfidence >= 0.2,
              Finger.allCases.allSatisfy({ features.extensionRatios[$0] != nil })
        else { return nil }

        let index = features.extensionRatios[.index]!
        let middle = features.extensionRatios[.middle]!
        let ring = features.extensionRatios[.ring]!
        let little = features.extensionRatios[.little]!
        let extendedMin = 0.35
        let foldedMax = 0.15
        let thumbExtendedMin = 0.9
        let thumbFoldedMax = 0.6
        let pinchMax = 0.45

        func extended(_ score: Double) -> Bool { score >= extendedMin }
        func folded(_ score: Double) -> Bool { score <= foldedMax }
        func result(_ gesture: HandGesture, _ margins: [Double]) -> GesturePrediction? {
            let average = margins.reduce(0, +) / Double(margins.count)
            let ruleConfidence = min(1, max(0, average / 0.25))
            let confidence: Double
            if let reference = templates[gesture] {
                let fingerError = Finger.allCases.reduce(0.0) { total, finger in
                    total + abs(features.extensionRatios[finger]! - reference.extensionRatios[finger]!)
                } / Double(Finger.allCases.count)
                let thumbError = abs(features.thumbExtension - reference.thumbExtension)
                let directionError = abs(features.thumbLift - reference.thumbLift)
                    + abs(features.indexLift - reference.indexLift)
                    + abs(features.indexSide - reference.indexSide)
                let contactError = abs(features.thumbIndexGap - reference.thumbIndexGap)
                let similarity = max(0, 1 - (fingerError + thumbError * 0.5 + directionError * 0.3 + contactError * 0.5) / 0.55)
                confidence = ruleConfidence * 0.65 + similarity * 0.35
            } else {
                confidence = ruleConfidence
            }
            guard confidence >= 0.2 else { return nil }
            return GesturePrediction(gesture: gesture, confidence: confidence, runnerUpConfidence: 0)
        }

        let allFolded = folded(index) && folded(middle) && folded(ring) && folded(little)
        let allExtended = extended(index) && extended(middle) && extended(ring) && extended(little)

        if features.thumbIndexGap <= pinchMax, extended(middle), extended(ring), extended(little) {
            return result(.ok, [(pinchMax - features.thumbIndexGap) * 2,
                                middle - extendedMin, ring - extendedMin, little - extendedMin])
        }
        if allFolded, features.thumbExtension >= thumbExtendedMin, features.thumbLift >= 0.45 {
            return result(.thumbsUp, [foldedMax - index, foldedMax - middle, foldedMax - ring,
                                      foldedMax - little, features.thumbExtension - thumbExtendedMin,
                                      features.thumbLift - 0.45])
        }
        if allFolded, features.thumbExtension >= thumbExtendedMin, -features.thumbLift >= 0.35 {
            return result(.thumbsDown, [foldedMax - index, foldedMax - middle, foldedMax - ring,
                                        foldedMax - little, features.thumbExtension - thumbExtendedMin,
                                        -features.thumbLift - 0.35])
        }
        if allFolded, features.thumbExtension <= thumbFoldedMax {
            return result(.fist, [foldedMax - index, foldedMax - middle, foldedMax - ring,
                                  foldedMax - little, thumbFoldedMax - features.thumbExtension])
        }
        if allExtended {
            return result(.openPalm, [index - extendedMin, middle - extendedMin,
                                      ring - extendedMin, little - extendedMin])
        }
        if extended(index), extended(middle), extended(ring), folded(little) {
            return result(.three, [
                index - extendedMin,
                middle - extendedMin,
                ring - extendedMin,
                foldedMax - little
            ])
        }
        if extended(index), extended(middle), folded(ring), folded(little) {
            return result(.peace, [index - extendedMin, middle - extendedMin,
                                   foldedMax - ring, foldedMax - little])
        }
        if extended(index), folded(middle), folded(ring), extended(little) {
            return result(.rock, [index - extendedMin, little - extendedMin,
                                  foldedMax - middle, foldedMax - ring])
        }
        if folded(index), folded(middle), folded(ring), extended(little),
           features.thumbExtension >= thumbExtendedMin {
            return result(.shaka, [little - extendedMin, features.thumbExtension - thumbExtendedMin,
                                   foldedMax - index, foldedMax - middle, foldedMax - ring])
        }
        if extended(index), folded(middle), folded(ring), folded(little) {
            let dx = features.indexSide
            let dy = features.indexLift
            let shape = [index - extendedMin, foldedMax - middle,
                         foldedMax - ring, foldedMax - little]
            if abs(dy) >= 1.4 * abs(dx), abs(dy) >= 0.2 {
                return result(dy > 0 ? .pointUp : .pointDown, shape + [abs(dy) - 0.2])
            }
            if abs(dx) >= 1.4 * abs(dy), abs(dx) >= 0.2 {
                return result(dx > 0 ? .pointRight : .pointLeft, shape + [abs(dx) - 0.2])
            }
        }
        return nil
    }

    private func templateScore(_ features: GestureFeatures, reference: GestureFeatures) -> Double {
        var weightedError = 0.0
        var totalWeight = 0.0
        for finger in Finger.allCases {
            weightedError += abs(features.extensionRatios[finger]! - reference.extensionRatios[finger]!)
            totalWeight += 1
        }
        weightedError += 2 * abs(features.thumbExtension - reference.thumbExtension)
        totalWeight += 2
        weightedError += 3 * abs(features.thumbLift - reference.thumbLift)
        weightedError += 3 * abs(features.indexLift - reference.indexLift)
        weightedError += 3 * abs(features.indexSide - reference.indexSide)
        weightedError += 2 * abs(features.thumbIndexGap - reference.thumbIndexGap)
        totalWeight += 12
        return max(0, 1 - weightedError / totalWeight / 0.42)
    }

    private func score(_ gesture: HandGesture, features: GestureFeatures) -> Double {
        let extended: Set<Finger>
        let thumbTarget: Double?
        let thumbDirection: Double?
        let indexDirection: CGPoint?
        let expectsThumbIndexTouch: Bool

        switch gesture {
        case .fist:
            extended = []
            thumbTarget = 0.32
            thumbDirection = nil
            indexDirection = nil
            expectsThumbIndexTouch = false
        case .thumbsUp:
            extended = []
            thumbTarget = 0.95
            thumbDirection = 1
            indexDirection = nil
            expectsThumbIndexTouch = false
        case .thumbsDown:
            extended = []
            thumbTarget = 0.95
            thumbDirection = -1
            indexDirection = nil
            expectsThumbIndexTouch = false
        case .openPalm:
            extended = Set(Finger.allCases)
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = nil
            expectsThumbIndexTouch = false
        case .three:
            extended = [.index, .middle, .ring]
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = nil
            expectsThumbIndexTouch = false
        case .peace:
            extended = [.index, .middle]
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = nil
            expectsThumbIndexTouch = false
        case .pointUp:
            extended = [.index]
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = CGPoint(x: 0, y: 1)
            expectsThumbIndexTouch = false
        case .pointDown:
            extended = [.index]
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = CGPoint(x: 0, y: -1)
            expectsThumbIndexTouch = false
        case .pointLeft:
            extended = [.index]
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = CGPoint(x: -1, y: 0)
            expectsThumbIndexTouch = false
        case .pointRight:
            extended = [.index]
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = CGPoint(x: 1, y: 0)
            expectsThumbIndexTouch = false
        case .ok:
            extended = [.middle, .ring, .little]
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = nil
            expectsThumbIndexTouch = true
        case .rock:
            extended = [.index, .little]
            thumbTarget = nil
            thumbDirection = nil
            indexDirection = nil
            expectsThumbIndexTouch = false
        case .shaka:
            extended = [.little]
            thumbTarget = 0.95
            thumbDirection = nil
            indexDirection = nil
            expectsThumbIndexTouch = false
        }

        let fingerScore = Finger.allCases.reduce(0.0) { partial, finger in
            let target = extended.contains(finger) ? 0.92 : 0.56
            let error = abs((features.extensionRatios[finger] ?? 0.56) - target)
            return partial + max(0, 1 - error / 0.42)
        } / Double(Finger.allCases.count)

        if expectsThumbIndexTouch {
            let contactScore = max(0, min(1, (0.48 - features.thumbIndexGap) / 0.32))
            return fingerScore * 0.7 + contactScore * 0.3
        }
        if let indexDirection {
            let component = indexDirection.x == 0
                ? features.indexLift * indexDirection.y
                : features.indexSide * indexDirection.x
            let directionScore = max(0, min(1, (component - 0.08) / 0.28))
            return fingerScore * 0.72 + directionScore * 0.28
        }
        guard let thumbTarget else { return fingerScore }
        let thumbScore = max(0, 1 - abs(features.thumbExtension - thumbTarget) / 0.65)
        guard let thumbDirection else { return fingerScore * 0.72 + thumbScore * 0.28 }
        let directionScore = max(0, min(1, (features.thumbLift * thumbDirection - 0.1) / 0.28))
        return fingerScore * 0.58 + thumbScore * 0.22 + directionScore * 0.2
    }
}

public struct TemporalStabilizer: Sendable {
    public let minimumFrames: Int
    public let minimumDuration: TimeInterval
    public let rearmDuration: TimeInterval

    private var candidate: HandGesture?
    private var candidateStart: TimeInterval?
    private var candidateFrames = 0
    private var neutralStart: TimeInterval?
    private var isArmed = true

    public init(
        minimumFrames: Int = 4,
        minimumDuration: TimeInterval = 0.2,
        rearmDuration: TimeInterval = 0.28
    ) {
        self.minimumFrames = minimumFrames
        self.minimumDuration = minimumDuration
        self.rearmDuration = rearmDuration
    }

    public func progress(at time: TimeInterval) -> Double {
        guard let candidateStart else { return 0 }
        let frameProgress = Double(candidateFrames) / Double(minimumFrames)
        let timeProgress = (time - candidateStart) / minimumDuration
        return min(1, min(frameProgress, timeProgress))
    }

    public mutating func observe(_ gesture: HandGesture?, at time: TimeInterval) -> HandGesture? {
        guard let gesture else {
            candidate = nil
            candidateStart = nil
            candidateFrames = 0
            if neutralStart == nil { neutralStart = time }
            if !isArmed, time - (neutralStart ?? time) >= rearmDuration {
                isArmed = true
            }
            return nil
        }

        neutralStart = nil
        guard isArmed else { return nil }

        if candidate == gesture {
            candidateFrames += 1
        } else {
            candidate = gesture
            candidateStart = time
            candidateFrames = 1
        }

        guard candidateFrames >= minimumFrames,
              time - (candidateStart ?? time) + 1e-9 >= minimumDuration
        else { return nil }

        isArmed = false
        candidate = nil
        candidateStart = nil
        candidateFrames = 0
        return gesture
    }
}