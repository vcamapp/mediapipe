import Foundation
import MediaPipeTasksVision

public enum PoseLandmarkerModelError: Error {
    case modelNotFound
    case metadataNotFound
}

public enum PoseLandmarkerModel {
    public static var url: URL {
        get throws {
            guard let url = Bundle.module.url(
                forResource: "pose_landmarker_lite",
                withExtension: "task",
                subdirectory: "Models"
            ) else {
                throw PoseLandmarkerModelError.modelNotFound
            }
            return url
        }
    }

    public static var metadataURL: URL {
        get throws {
            guard let url = Bundle.module.url(
                forResource: "pose_landmarker_lite.metadata",
                withExtension: "json",
                subdirectory: "Models"
            ) else {
                throw PoseLandmarkerModelError.metadataNotFound
            }
            return url
        }
    }

    public static func makeOptions(
        runningMode: RunningMode,
        numberOfPoses: Int = 1,
        minimumDetectionConfidence: Float = 0.5,
        minimumPresenceConfidence: Float = 0.5,
        minimumTrackingConfidence: Float = 0.5
    ) throws -> PoseLandmarkerOptions {
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = try url.path
        options.runningMode = runningMode
        options.numPoses = numberOfPoses
        options.minPoseDetectionConfidence = minimumDetectionConfidence
        options.minPosePresenceConfidence = minimumPresenceConfidence
        options.minTrackingConfidence = minimumTrackingConfidence
        return options
    }

    public static func metadata() throws -> PoseLandmarkerModelMetadata {
        try JSONDecoder().decode(
            PoseLandmarkerModelMetadata.self,
            from: Data(contentsOf: metadataURL)
        )
    }
}

public struct PoseLandmarkerModelMetadata: Decodable, Sendable {
    public let name: String
    public let variant: String
    public let modelVersion: String
    public let source: String
    public let sourceURL: URL
    public let modelCardURL: URL
    public let testedMediaPipeVersion: String
    public let sha256: String
    public let license: String
}
