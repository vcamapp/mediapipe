// MediaPipe types must stay out of x86_64 binaries, whose framework slice is
// a link-only stub; everything referencing them is compiled for arm64 only.
#if arch(arm64)
import CoreVideo
import Foundation
import MediaPipeTasksVision

final class MediaPipeHandLandmarkTracker: HandLandmarkTracking, @unchecked Sendable {
    private let landmarker: HandLandmarker
    // HandLandmarker's video mode is not thread-safe and requires
    // monotonically increasing timestamps, so calls are serialized.
    private let lock = NSLock()

    init(configuration: HandLandmarkTrackingConfiguration) throws {
        let options = try HandLandmarkerModel.makeOptions(
            runningMode: .video,
            numberOfHands: configuration.numberOfHands,
            minimumDetectionConfidence: configuration.minimumDetectionConfidence,
            minimumPresenceConfidence: configuration.minimumPresenceConfidence,
            minimumTrackingConfidence: configuration.minimumTrackingConfidence
        )
        landmarker = try HandLandmarker(options: options)
    }

    func detect(
        in pixelBuffer: CVPixelBuffer,
        timestampInMilliseconds: Int
    ) throws -> HandLandmarkResult {
        let image = try MPImage(pixelBuffer: pixelBuffer)
        lock.lock()
        defer { lock.unlock() }
        let result = try landmarker.detect(
            videoFrame: image,
            timestampInMilliseconds: timestampInMilliseconds
        )
        return HandLandmarkResult(result)
    }
}

private extension HandLandmarkResult {
    init(_ result: HandLandmarkerResult) {
        self.init(hands: result.landmarks.indices.map { index in
            let handedness = result.handedness.indices.contains(index)
                ? result.handedness[index].first : nil
            return DetectedHand(
                landmarks: result.landmarks[index].map { SIMD3($0.x, $0.y, $0.z) },
                worldLandmarks: result.worldLandmarks.indices.contains(index)
                    ? result.worldLandmarks[index].map { SIMD3($0.x, $0.y, $0.z) }
                    : [],
                handedness: Handedness(categoryName: handedness?.categoryName),
                handednessConfidence: handedness?.score ?? 0
            )
        })
    }
}

private extension Handedness {
    init(categoryName: String?) {
        switch categoryName {
        case "Left": self = .left
        case "Right": self = .right
        default: self = .unknown
        }
    }
}
#endif
