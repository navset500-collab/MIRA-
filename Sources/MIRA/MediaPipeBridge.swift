import AVFoundation
import Foundation

/// Bridges MIRA's existing camera frames to a MediaPipe helper process.
/// The helper returns normalized Vision-style landmarks; it does not control input.
final class MediaPipeBridge {
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var ready = false
    private var landmarkHandler: (([HandLandmark]) -> Void)?

    var isReady: Bool { ready }

    func start(
        executable: URL,
        model: URL,
        handler: @escaping ([HandLandmark]) -> Void
    ) {
        stop()

        let process = Process()
        process.executableURL = executable
        process.arguments = [model.path]

        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return
        }

        self.process = process
        self.input = input.fileHandleForWriting
        self.output = output.fileHandleForReading
        self.landmarkHandler = handler

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else {
                handle.readabilityHandler = nil
                return
            }
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                DispatchQueue.main.async { self.ready = false }
                return
            }

            self.buffer.append(data)

            while let newline = self.buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = self.buffer.subdata(in: self.buffer.startIndex..<newline)
                self.buffer.removeSubrange(self.buffer.startIndex...newline)

                guard let payload = try? JSONDecoder().decode(
                    TrackerPayload.self, from: line
                ) else { continue }

                let landmarks = payload.landmarks.map {
                    HandLandmark(
                        id: $0.id,
                        x: CGFloat($0.x),
                        y: CGFloat($0.y),
                        confidence: Float($0.confidence)
                    )
                }

                DispatchQueue.main.async {
                    self.ready = true
                    self.landmarkHandler?(landmarks)
                }
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.ready = false
                self?.process = nil
                self?.input = nil
                self?.output = nil
            }
        }
    }

    func send(pixelBuffer: CVPixelBuffer, width: Int, height: Int) {
        guard ready, let input,
              let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let expected = bytesPerRow * height
        let data = Data(bytes: base, count: expected)

        var header = [UInt32]()
        header.append(UInt32(width))
        header.append(UInt32(height))
        header.append(UInt32(expected))

        var prefix = Data()
        for value in header {
            withUnsafeBytes(of: value.littleEndian) { prefix.append(contentsOf: $0) }
        }

        input.write(prefix)
        input.write(data)
    }

    func stop() {
        output?.readabilityHandler = nil
        input?.closeFile()
        process?.terminate()
        process?.waitUntilExit()
        process = nil
        input = nil
        output = nil
        ready = false
        buffer.removeAll()
    }
}

private struct TrackerPayload: Decodable {
    struct Landmark: Decodable {
        let id: String
        let x: Double
        let y: Double
        let confidence: Double
    }

    let ok: Bool
    let landmarks: [Landmark]
}
