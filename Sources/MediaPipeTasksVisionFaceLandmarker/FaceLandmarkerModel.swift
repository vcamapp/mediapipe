import Foundation
import MediaPipeTasksVision

public enum FaceLandmarkerModelError: Error {
    case modelNotFound
    case metadataNotFound
}

public enum FaceLandmarkerModel {
    public static var url: URL {
        get throws {
            guard let url = Bundle.module.url(
                forResource: "face_landmarker",
                withExtension: "task",
                subdirectory: "Models"
            ) else {
                throw FaceLandmarkerModelError.modelNotFound
            }
            return url
        }
    }

    public static var metadataURL: URL {
        get throws {
            guard let url = Bundle.module.url(
                forResource: "face_landmarker.metadata",
                withExtension: "json",
                subdirectory: "Models"
            ) else {
                throw FaceLandmarkerModelError.metadataNotFound
            }
            return url
        }
    }

    public static func makeOptions(
        runningMode: RunningMode,
        numberOfFaces: Int = 1,
        minimumDetectionConfidence: Float = 0.5,
        minimumPresenceConfidence: Float = 0.5,
        minimumTrackingConfidence: Float = 0.5,
        outputsBlendShapes: Bool = true,
        outputsTransform: Bool = false
    ) throws -> FaceLandmarkerOptions {
        let options = FaceLandmarkerOptions()
        options.baseOptions.modelAssetPath = try url.path
        options.runningMode = runningMode
        options.numFaces = numberOfFaces
        options.minFaceDetectionConfidence = minimumDetectionConfidence
        options.minFacePresenceConfidence = minimumPresenceConfidence
        options.minTrackingConfidence = minimumTrackingConfidence
        options.outputFaceBlendshapes = outputsBlendShapes
        options.outputFacialTransformationMatrixes = outputsTransform
        return options
    }

    public static func metadata() throws -> FaceLandmarkerModelMetadata {
        try JSONDecoder().decode(
            FaceLandmarkerModelMetadata.self,
            from: Data(contentsOf: metadataURL)
        )
    }
}

public struct FaceLandmarkerModelMetadata: Decodable, Sendable {
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
