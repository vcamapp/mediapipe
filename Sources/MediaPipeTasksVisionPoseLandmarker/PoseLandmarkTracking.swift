import CoreVideo

/// Pose landmark detection on a stream of video frames, independent of the
/// underlying MediaPipe types so that consumers never link against them.
public protocol PoseLandmarkTracking: AnyObject, Sendable {
    /// Detects poses in a `kCVPixelFormatType_32BGRA` frame.
    ///
    /// Timestamps must be monotonically increasing across calls.
    func detect(
        in pixelBuffer: CVPixelBuffer,
        timestampInMilliseconds: Int
    ) throws -> PoseLandmarkResult
}

/// Where the landmark models run. `.gpu` uses the Metal delegate and
/// requires a GPU-enabled framework build; creation throws when the
/// backend cannot be initialized, so callers can fall back to `.cpu`.
public enum PoseInferenceBackend: Sendable {
    case cpu
    case gpu
}

public struct PoseLandmarkTrackingConfiguration: Sendable {
    public var numberOfPoses: Int
    public var minimumDetectionConfidence: Float
    public var minimumPresenceConfidence: Float
    public var minimumTrackingConfidence: Float
    public var inferenceBackend: PoseInferenceBackend

    public init(
        numberOfPoses: Int = 1,
        minimumDetectionConfidence: Float = 0.5,
        minimumPresenceConfidence: Float = 0.5,
        minimumTrackingConfidence: Float = 0.5,
        inferenceBackend: PoseInferenceBackend = .cpu
    ) {
        self.numberOfPoses = numberOfPoses
        self.minimumDetectionConfidence = minimumDetectionConfidence
        self.minimumPresenceConfidence = minimumPresenceConfidence
        self.minimumTrackingConfidence = minimumTrackingConfidence
        self.inferenceBackend = inferenceBackend
    }
}

public struct PoseLandmarkResult: Sendable {
    public let poses: [DetectedPose]

    public init(poses: [DetectedPose]) {
        self.poses = poses
    }
}

public struct DetectedPose: Sendable {
    /// 33 landmarks normalized to the image size; `z` is depth relative to
    /// the hips, with roughly the same scale as `x`.
    public let landmarks: [SIMD3<Float>]
    /// 33 landmarks in meters, with the origin at the midpoint of the hips.
    public let worldLandmarks: [SIMD3<Float>]
    /// How likely each landmark is visible rather than occluded, in the same
    /// order as `landmarks`; 0 when the model does not report it.
    public let visibilities: [Float]

    public init(
        landmarks: [SIMD3<Float>],
        worldLandmarks: [SIMD3<Float>],
        visibilities: [Float]
    ) {
        self.landmarks = landmarks
        self.worldLandmarks = worldLandmarks
        self.visibilities = visibilities
    }
}
