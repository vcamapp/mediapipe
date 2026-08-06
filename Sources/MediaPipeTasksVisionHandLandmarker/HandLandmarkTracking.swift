import CoreVideo

/// Hand landmark detection on a stream of video frames, independent of the
/// underlying MediaPipe types so that consumers never link against them.
public protocol HandLandmarkTracking: AnyObject, Sendable {
    /// Detects hands in a `kCVPixelFormatType_32BGRA` frame.
    ///
    /// Timestamps must be monotonically increasing across calls.
    func detect(
        in pixelBuffer: CVPixelBuffer,
        timestampInMilliseconds: Int
    ) throws -> HandLandmarkResult
}

/// Where the landmark models run. `.gpu` uses the Metal delegate and
/// requires a GPU-enabled framework build; creation throws when the
/// backend cannot be initialized, so callers can fall back to `.cpu`.
public enum HandInferenceBackend: Sendable {
    case cpu
    case gpu
}

public struct HandLandmarkTrackingConfiguration: Sendable {
    public var numberOfHands: Int
    public var minimumDetectionConfidence: Float
    public var minimumPresenceConfidence: Float
    public var minimumTrackingConfidence: Float
    public var inferenceBackend: HandInferenceBackend

    public init(
        numberOfHands: Int = 2,
        minimumDetectionConfidence: Float = 0.5,
        minimumPresenceConfidence: Float = 0.5,
        minimumTrackingConfidence: Float = 0.5,
        inferenceBackend: HandInferenceBackend = .cpu
    ) {
        self.numberOfHands = numberOfHands
        self.minimumDetectionConfidence = minimumDetectionConfidence
        self.minimumPresenceConfidence = minimumPresenceConfidence
        self.minimumTrackingConfidence = minimumTrackingConfidence
        self.inferenceBackend = inferenceBackend
    }
}

public struct HandLandmarkResult: Sendable {
    public let hands: [DetectedHand]

    public init(hands: [DetectedHand]) {
        self.hands = hands
    }
}

public struct DetectedHand: Sendable {
    /// 21 landmarks normalized to the image size; `z` is depth relative to
    /// the wrist, with the same scale as `x`.
    public let landmarks: [SIMD3<Float>]
    /// 21 landmarks in meters, with the origin at the hand's geometric center.
    public let worldLandmarks: [SIMD3<Float>]
    public let handedness: Handedness
    public let handednessConfidence: Float

    public init(
        landmarks: [SIMD3<Float>],
        worldLandmarks: [SIMD3<Float>],
        handedness: Handedness,
        handednessConfidence: Float
    ) {
        self.landmarks = landmarks
        self.worldLandmarks = worldLandmarks
        self.handedness = handedness
        self.handednessConfidence = handednessConfidence
    }
}

public enum Handedness: Sendable {
    case left
    case right
    case unknown
}
