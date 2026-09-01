// MediaPipe types must stay out of x86_64 binaries, whose framework slice is
// a link-only stub; everything referencing them is compiled for arm64 only.
#if arch(arm64)
import CoreVideo
import Foundation
import MediaPipeTasksVision
import MediaPipeTasksVisionSupport

final class MediaPipePoseLandmarkTracker: PoseLandmarkTracking, @unchecked Sendable {
    private let landmarker: PoseLandmarker
    // PoseLandmarker's video mode is not thread-safe and requires
    // monotonically increasing timestamps, so calls are serialized.
    private let lock = NSLock()

    init(configuration: PoseLandmarkTrackingConfiguration) throws {
        let options = try PoseLandmarkerModel.makeOptions(
            runningMode: .video,
            numberOfPoses: configuration.numberOfPoses,
            minimumDetectionConfidence: configuration.minimumDetectionConfidence,
            minimumPresenceConfidence: configuration.minimumPresenceConfidence,
            minimumTrackingConfidence: configuration.minimumTrackingConfidence
        )
        options.baseOptions.delegate = configuration.inferenceBackend == .gpu ? .GPU : .CPU
        // Segmentation masks stay off: the graph then skips its mask branch,
        // whose calculators cannot run on the macOS OpenGL context.
        options.shouldOutputSegmentationMasks = false
        // The pose detector finds nothing at all when the CPU delegate runs in
        // FP16, so this task keeps full precision.
        landmarker = try XNNPackInference.makeTask(forcingFP16: false) {
            try PoseLandmarker(options: options)
        }
    }

    func detect(
        in pixelBuffer: CVPixelBuffer,
        timestampInMilliseconds: Int
    ) throws -> PoseLandmarkResult {
        let image = try MPImage(pixelBuffer: pixelBuffer)
        lock.lock()
        defer { lock.unlock() }
        let result = try landmarker.detect(
            videoFrame: image,
            timestampInMilliseconds: timestampInMilliseconds
        )
        return PoseLandmarkResult(result)
    }
}

private extension PoseLandmarkResult {
    init(_ result: PoseLandmarkerResult) {
        self.init(poses: result.landmarks.indices.map { index in
            DetectedPose(
                landmarks: result.landmarks[index].map { SIMD3($0.x, $0.y, $0.z) },
                worldLandmarks: result.worldLandmarks.indices.contains(index)
                    ? result.worldLandmarks[index].map { SIMD3($0.x, $0.y, $0.z) }
                    : [],
                visibilities: result.landmarks[index].map { $0.visibility?.floatValue ?? 0 }
            )
        })
    }
}
#endif
