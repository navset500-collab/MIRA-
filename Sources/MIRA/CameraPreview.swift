import AVFoundation
import SwiftUI

struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }
    }
}

final class PreviewView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func makeBackingLayer() -> CALayer {
        AVCaptureVideoPreviewLayer()
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

struct HandSkeleton: View {
    let landmarks: [HandLandmark]
    let imageSize: CGSize

    private let chains = [
        ["wrist", "thumbCMC", "thumbMP", "thumbIP", "thumbTip"],
        ["wrist", "indexMCP", "indexPIP", "indexDIP", "indexTip"],
        ["wrist", "middleMCP", "middlePIP", "middleDIP", "middleTip"],
        ["wrist", "ringMCP", "ringPIP", "ringDIP", "ringTip"],
        ["wrist", "littleMCP", "littlePIP", "littleDIP", "littleTip"],
        ["indexMCP", "middleMCP", "ringMCP", "littleMCP"]
    ]

    var body: some View {
        Canvas { context, size in
            let points = Dictionary(uniqueKeysWithValues: landmarks.map { ($0.id, $0) })
            for chain in chains {
                var previous: HandLandmark?
                for name in chain {
                    guard let landmark = points[name], landmark.confidence >= 0.08 else {
                        previous = nil
                        continue
                    }
                    if let previous {
                        var bone = Path()
                        bone.move(to: screenPoint(CGPoint(x: previous.x, y: previous.y), in: size))
                        bone.addLine(to: screenPoint(CGPoint(x: landmark.x, y: landmark.y), in: size))
                        let confidence = min(Double(previous.confidence), Double(landmark.confidence))
                        context.stroke(bone, with: .color(.black.opacity(0.7)), lineWidth: 4)
                        context.stroke(bone, with: .color(.white.opacity(0.38 + confidence * 0.52)), lineWidth: 1.6)
                    }
                    previous = landmark
                }
            }
            for landmark in landmarks {
                let point = screenPoint(CGPoint(x: landmark.x, y: landmark.y), in: size)
                let radius: CGFloat = landmark.isDerived ? 5 : 2.3
                let outer = CGRect(x: point.x - radius - 1.2, y: point.y - radius - 1.2,
                                   width: (radius + 1.2) * 2, height: (radius + 1.2) * 2)
                let inner = CGRect(x: point.x - radius, y: point.y - radius,
                                   width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: outer), with: .color(.black.opacity(0.72)))
                context.fill(
                    Path(ellipseIn: inner),
                    with: .color((landmark.isDerived ? Color(red: 1, green: 0.69, blue: 0.3) : .white)
                        .opacity(max(0.45, Double(landmark.confidence))))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func screenPoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        let scale = max(size.width / imageSize.width, size.height / imageSize.height)
        let renderedWidth = imageSize.width * scale
        let renderedHeight = imageSize.height * scale
        return CGPoint(
            x: point.x * renderedWidth + (size.width - renderedWidth) / 2,
            y: (1 - point.y) * renderedHeight + (size.height - renderedHeight) / 2
        )
    }
}