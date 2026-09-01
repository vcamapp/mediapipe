import CoreVideo
import simd

/// Face landmark detection on a stream of video frames, independent of the
/// underlying MediaPipe types so that consumers never link against them.
public protocol FaceLandmarkTracking: AnyObject, Sendable {
    /// Detects faces in a `kCVPixelFormatType_32BGRA` frame.
    ///
    /// Timestamps must be monotonically increasing across calls.
    func detect(
        in pixelBuffer: CVPixelBuffer,
        timestampInMilliseconds: Int
    ) throws -> FaceLandmarkResult
}

/// Where the landmark models run. `.gpu` uses the Metal delegate and
/// requires a GPU-enabled framework build; creation throws when the
/// backend cannot be initialized, so callers can fall back to `.cpu`.
public enum FaceInferenceBackend: Sendable {
    case cpu
    case gpu
}

public struct FaceLandmarkTrackingConfiguration: Sendable {
    public var numberOfFaces: Int
    public var minimumDetectionConfidence: Float
    public var minimumPresenceConfidence: Float
    public var minimumTrackingConfidence: Float
    /// Whether `DetectedFace.blendShapes` is filled in. The scores come from a
    /// second model in the bundle, so turning this off makes detection cheaper.
    public var outputsBlendShapes: Bool
    /// Whether `DetectedFace.transform` is filled in.
    public var outputsTransform: Bool
    public var inferenceBackend: FaceInferenceBackend

    public init(
        numberOfFaces: Int = 1,
        minimumDetectionConfidence: Float = 0.5,
        minimumPresenceConfidence: Float = 0.5,
        minimumTrackingConfidence: Float = 0.5,
        outputsBlendShapes: Bool = true,
        outputsTransform: Bool = false,
        inferenceBackend: FaceInferenceBackend = .cpu
    ) {
        self.numberOfFaces = numberOfFaces
        self.minimumDetectionConfidence = minimumDetectionConfidence
        self.minimumPresenceConfidence = minimumPresenceConfidence
        self.minimumTrackingConfidence = minimumTrackingConfidence
        self.outputsBlendShapes = outputsBlendShapes
        self.outputsTransform = outputsTransform
        self.inferenceBackend = inferenceBackend
    }
}

public struct FaceLandmarkResult: Sendable {
    public let faces: [DetectedFace]

    public init(faces: [DetectedFace]) {
        self.faces = faces
    }
}

public struct DetectedFace: Sendable {
    /// 478 landmarks normalized to the image size — the 468 face mesh points
    /// followed by 10 iris points; `z` is depth relative to the head center,
    /// with roughly the same scale as `x`.
    public let landmarks: [SIMD3<Float>]
    /// How strongly each expression is present, from 0 to 1. Empty unless
    /// `outputsBlendShapes` is set; shapes the model does not report are absent.
    public let blendShapes: [FaceBlendShape: Float]
    /// Transforms the canonical face model into the detected face, in a
    /// right-handed metric space with the origin at the camera. `nil` unless
    /// `outputsTransform` is set.
    public let transform: simd_float4x4?

    public init(
        landmarks: [SIMD3<Float>],
        blendShapes: [FaceBlendShape: Float],
        transform: simd_float4x4?
    ) {
        self.landmarks = landmarks
        self.blendShapes = blendShapes
        self.transform = transform
    }
}

/// The 52 expression channels the model scores, in the order it reports them.
///
/// The names, and all but `neutral` the semantics, are the ARKit blend shape
/// locations.
public enum FaceBlendShape: String, CaseIterable, Sendable {
    /// How little expression the face shows; not an ARKit blend shape.
    case neutral = "_neutral"
    case browDownLeft
    case browDownRight
    case browInnerUp
    case browOuterUpLeft
    case browOuterUpRight
    case cheekPuff
    case cheekSquintLeft
    case cheekSquintRight
    case eyeBlinkLeft
    case eyeBlinkRight
    case eyeLookDownLeft
    case eyeLookDownRight
    case eyeLookInLeft
    case eyeLookInRight
    case eyeLookOutLeft
    case eyeLookOutRight
    case eyeLookUpLeft
    case eyeLookUpRight
    case eyeSquintLeft
    case eyeSquintRight
    case eyeWideLeft
    case eyeWideRight
    case jawForward
    case jawLeft
    case jawOpen
    case jawRight
    case mouthClose
    case mouthDimpleLeft
    case mouthDimpleRight
    case mouthFrownLeft
    case mouthFrownRight
    case mouthFunnel
    case mouthLeft
    case mouthLowerDownLeft
    case mouthLowerDownRight
    case mouthPressLeft
    case mouthPressRight
    case mouthPucker
    case mouthRight
    case mouthRollLower
    case mouthRollUpper
    case mouthShrugLower
    case mouthShrugUpper
    case mouthSmileLeft
    case mouthSmileRight
    case mouthStretchLeft
    case mouthStretchRight
    case mouthUpperUpLeft
    case mouthUpperUpRight
    case noseSneerLeft
    case noseSneerRight
}
