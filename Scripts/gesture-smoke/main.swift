import Foundation

func sample(
    _ extended: Set<Finger>,
    thumbExtension: Double = 0.32,
    thumbLift: Double = 0,
    thumbIndexGap: Double = 1,
    indexLift: Double = 0,
    indexSide: Double = 0,
    confidence: Double = 0.95
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
        trackingConfidence: confidence
    )
}

let classifier = GestureClassifier()
let cases: [(HandGesture, GestureFeatures)] = [
    (.fist, sample([])),
    (.openPalm, sample([.index, .middle, .ring, .little])),
    (.thumbsUp, sample([], thumbExtension: 0.95, thumbLift: 0.5)),
    (.thumbsDown, sample([], thumbExtension: 0.95, thumbLift: -0.5)),
    (.peace, sample([.index, .middle])),
    (.pointUp, sample([.index], indexLift: 0.3)),
    (.pointDown, sample([.index], indexLift: -0.3)),
    (.pointLeft, sample([.index], indexSide: -0.3)),
    (.pointRight, sample([.index], indexSide: 0.3)),
    (.ok, sample([.middle, .ring, .little], thumbIndexGap: 0.1)),
    (.rock, sample([.index, .little])),
    (.shaka, sample([.little], thumbExtension: 0.95))
]

for (gesture, features) in cases {
    guard classifier.classify(features)?.gesture == gesture else {
        fatalError("Geometric classifier failed for \(gesture.rawValue)")
    }
}

let templates = Dictionary(uniqueKeysWithValues: cases)
for (gesture, features) in cases {
    guard classifier.classify(features, templates: templates)?.gesture == gesture else {
        fatalError("Personal-template classifier failed for \(gesture.rawValue)")
    }
}

guard classifier.classify(sample([], confidence: 0.1))?.gesture == nil else {
    fatalError("Low-confidence pose should be unknown")
}

var stabilizer = TemporalStabilizer()
var fired: HandGesture?
for frame in 0..<5 {
    fired = stabilizer.observe(.peace, at: Double(frame) * 0.05) ?? fired
}
guard fired == .peace, stabilizer.observe(.peace, at: 1) == nil else {
    fatalError("Stable gesture should fire once")
}

print("Passed: 12 geometric classes, 12 personal templates, low-confidence rejection, and one-shot stabilization.")