// MediaPipe types must stay out of x86_64 binaries, whose framework slice is
// a link-only stub; everything referencing them is compiled for arm64 only.
#if arch(arm64)
import CoreVideo
import Foundation
import MediaPipeTasksVision
import MediaPipeTasksVisionSupport
import simd

final class MediaPipeFaceLandmarkTracker: FaceLandmarkTracking, @unchecked Sendable {
    private let landmarker: FaceLandmarker
    // FaceLandmarker's video mode is not thread-safe and requires
    // monotonically increasing timestamps, so calls are serialized.
    private let lock = NSLock()

    init(configuration: FaceLandmarkTrackingConfiguration) throws {
        let options = try FaceLandmarkerModel.makeOptions(
            runningMode: .video,
            numberOfFaces: configuration.numberOfFaces,
            minimumDetectionConfidence: configuration.minimumDetectionConfidence,
            minimumPresenceConfidence: configuration.minimumPresenceConfidence,
            minimumTrackingConfidence: configuration.minimumTrackingConfidence,
            outputsBlendShapes: configuration.outputsBlendShapes,
            outputsTransform: configuration.outputsTransform
        )
        options.baseOptions.delegate = configuration.inferenceBackend == .gpu ? .GPU : .CPU
        // FP16 changes neither these models' output nor their per-frame cost,
        // so the task keeps full precision rather than inheriting whatever
        // another task left in the environment.
        landmarker = try XNNPackInference.makeTask(forcingFP16: false) {
            try FaceLandmarker(options: options)
        }
    }

    func detect(
        in pixelBuffer: CVPixelBuffer,
        timestampInMilliseconds: Int
    ) throws -> FaceLandmarkResult {
        let image = try MPImage(pixelBuffer: pixelBuffer)
        lock.lock()
        defer { lock.unlock() }
        let result = try landmarker.detect(
            videoFrame: image,
            timestampInMilliseconds: timestampInMilliseconds
        )
        return FaceLandmarkResult(result)
    }
}

private extension FaceLandmarkResult {
    init(_ result: FaceLandmarkerResult) {
        self.init(faces: result.faceLandmarks.indices.map { index in
            DetectedFace(
                landmarks: result.faceLandmarks[index].map { SIMD3($0.x, $0.y, $0.z) },
                blendShapes: result.faceBlendshapes.indices.contains(index)
                    ? .init(result.faceBlendshapes[index])
                    : [:],
                transform: result.facialTransformationMatrixes.indices.contains(index)
                    ? simd_float4x4(result.facialTransformationMatrixes[index])
                    : nil
            )
        })
    }
}

private extension [FaceBlendShape: Float] {
    init(_ classifications: Classifications) {
        self = classifications.categories.reduce(into: [:]) { scores, category in
            guard let blendShape = category.categoryName.flatMap(FaceBlendShape.init(rawValue:)) else { return }
            scores[blendShape] = category.score
        }
    }
}

private extension simd_float4x4 {
    init?(_ matrix: TransformMatrix) {
        // `data` is an unbounded pointer, so the shape is checked before it is
        // read. MediaPipe packs the matrix column by column, which is also how
        // simd stores it; `TransformMatrix.valueAtRow(_:column:)` reads it as
        // if it were row-major and is therefore not used here.
        guard matrix.rows == 4, matrix.columns == 4 else { return nil }
        self.init(columns: (
            SIMD4(matrix.data[0], matrix.data[1], matrix.data[2], matrix.data[3]),
            SIMD4(matrix.data[4], matrix.data[5], matrix.data[6], matrix.data[7]),
            SIMD4(matrix.data[8], matrix.data[9], matrix.data[10], matrix.data[11]),
            SIMD4(matrix.data[12], matrix.data[13], matrix.data[14], matrix.data[15])
        ))
    }
}
#endif
