import Foundation
import MediaPipeTasksVision

public enum HandLandmarkerModelError: Error {
    case modelNotFound
    case metadataNotFound
}

public enum HandLandmarkerModel {
    public static var url: URL {
        get throws {
            guard let url = Bundle.module.url(
                forResource: "hand_landmarker",
                withExtension: "task",
                subdirectory: "Models"
            ) else {
                throw HandLandmarkerModelError.modelNotFound
            }
            return url
        }
    }

    public static var metadataURL: URL {
        get throws {
            guard let url = Bundle.module.url(
                forResource: "hand_landmarker.metadata",
                withExtension: "json",
                subdirectory: "Models"
            ) else {
                throw HandLandmarkerModelError.metadataNotFound
            }
            return url
        }
    }

    public static func makeOptions(
        runningMode: RunningMode,
        numberOfHands: Int = 2,
        minimumDetectionConfidence: Float = 0.5,
        minimumPresenceConfidence: Float = 0.5,
        minimumTrackingConfidence: Float = 0.5
    ) throws -> HandLandmarkerOptions {
        let options = HandLandmarkerOptions()
        options.baseOptions.modelAssetPath = try url.path
        options.runningMode = runningMode
        options.numHands = numberOfHands
        options.minHandDetectionConfidence = minimumDetectionConfidence
        options.minHandPresenceConfidence = minimumPresenceConfidence
        options.minTrackingConfidence = minimumTrackingConfidence
        return options
    }

    public static func metadata() throws -> HandLandmarkerModelMetadata {
        try JSONDecoder().decode(
            HandLandmarkerModelMetadata.self,
            from: Data(contentsOf: metadataURL)
        )
    }
}

public struct HandLandmarkerModelMetadata: Decodable, Sendable {
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
