import XCTest
@testable import MIRACore

final class GestureRecognitionTests: XCTestCase {
    private let classifier = GestureClassifier()

    func testRecognizesDistinctCoreShapes() {
        XCTAssertEqual(classifier.classify(features(extended: []))?.gesture, .fist)
        XCTAssertEqual(classifier.classify(features(extended: [.index, .middle, .ring, .little]))?.gesture, .openPalm)
        XCTAssertEqual(classifier.classify(features(extended: [.index, .middle]))?.gesture, .peace)
        XCTAssertEqual(classifier.classify(features(extended: [.index], indexLift: 0.3))?.gesture, .pointUp)
        XCTAssertEqual(classifier.classify(features(extended: [], thumbExtension: 0.95))?.gesture, .thumbsUp)
        XCTAssertEqual(classifier.classify(features(extended: [], thumbExtension: 0.95, thumbLift: -0.5))?.gesture, .thumbsDown)
        XCTAssertEqual(classifier.classify(features(extended: [.index], indexLift: -0.3))?.gesture, .pointDown)
        XCTAssertEqual(classifier.classify(features(extended: [.index], indexSide: -0.3))?.gesture, .pointLeft)
        XCTAssertEqual(classifier.classify(features(extended: [.index], indexSide: 0.3))?.gesture, .pointRight)
        XCTAssertEqual(classifier.classify(features(extended: [.middle, .ring, .little], thumbIndexGap: 0.1))?.gesture, .ok)
        XCTAssertEqual(classifier.classify(features(extended: [.index, .little]))?.gesture, .rock)
        XCTAssertEqual(classifier.classify(features(extended: [.little], thumbExtension: 0.95))?.gesture, .shaka)
    }

    func testPersonalTemplatesRecognizeEachCapturedPose() {
        let templates: [HandGesture: GestureFeatures] = [
            .fist: features(extended: []),
            .openPalm: features(extended: [.index, .middle, .ring, .little]),
            .thumbsUp: features(extended: [], thumbExtension: 0.95),
            .thumbsDown: features(extended: [], thumbExtension: 0.95, thumbLift: -0.5),
            .peace: features(extended: [.index, .middle]),
            .pointUp: features(extended: [.index], indexLift: 0.3),
            .pointDown: features(extended: [.index], indexLift: -0.3),
            .pointLeft: features(extended: [.index], indexSide: -0.3),
            .pointRight: features(extended: [.index], indexSide: 0.3),
            .ok: features(extended: [.middle, .ring, .little], thumbIndexGap: 0.1),
            .rock: features(extended: [.index, .little]),
            .shaka: features(extended: [.little], thumbExtension: 0.95)
        ]

        for (gesture, sample) in templates {
            XCTAssertEqual(classifier.classify(sample, templates: templates)?.gesture, gesture)
        }
    }

    func testRejectsLowConfidenceAndAmbiguousInput() {
        XCTAssertNil(classifier.classify(features(extended: [], trackingConfidence: 0.1)))

        let ambiguous = GestureFeatures(
            extensionRatios: Dictionary(uniqueKeysWithValues: Finger.allCases.map { ($0, 0.25) }),
            thumbLift: 0.1,
            indexLift: 0.1,
            trackingConfidence: 0.9
        )
        XCTAssertNil(classifier.classify(ambiguous))
    }

    func testRequiresStableFramesAndReleaseBeforeRetriggering() {
        var stabilizer = TemporalStabilizer()
        for frame in 0..<4 {
            XCTAssertNil(stabilizer.observe(.peace, at: Double(frame) * 0.05))
        }
        XCTAssertEqual(stabilizer.observe(.peace, at: 0.2), .peace)
        XCTAssertNil(stabilizer.observe(.peace, at: 1.0))

        XCTAssertNil(stabilizer.observe(nil, at: 1.1))
        XCTAssertNil(stabilizer.observe(nil, at: 1.3))
        XCTAssertNil(stabilizer.observe(nil, at: 1.4))
        XCTAssertNil(stabilizer.observe(.peace, at: 1.45))
        XCTAssertNil(stabilizer.observe(.peace, at: 1.5))
        XCTAssertNil(stabilizer.observe(.peace, at: 1.55))
        XCTAssertNil(stabilizer.observe(.peace, at: 1.6))
        XCTAssertEqual(stabilizer.observe(.peace, at: 1.65), .peace)
    }

    private func features(
        extended: Set<Finger>,
        thumbExtension: Double = 0.32,
        thumbLift: Double = 0,
        thumbIndexGap: Double = 1,
        indexLift: Double = 0,
        indexSide: Double = 0,
        trackingConfidence: Double = 0.95
    ) -> GestureFeatures {
        let ratios = Dictionary(uniqueKeysWithValues: Finger.allCases.map { finger in
            (finger, extended.contains(finger) ? 0.55 : -0.1)
        })
        return GestureFeatures(
            extensionRatios: ratios,
            thumbExtension: thumbExtension,
            thumbLift: thumbLift,
            thumbIndexGap: thumbIndexGap,
            indexLift: indexLift,
            indexSide: indexSide,
            trackingConfidence: trackingConfidence
        )
    }
}