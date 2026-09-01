import CoreVideo
import XCTest
import MediaPipeTasksVisionFaceLandmarker

final class MediaPipeFaceTrackingTests: XCTestCase {
    func testAvailabilityMatchesExecutionArchitecture() {
#if arch(arm64)
        XCTAssertTrue(MediaPipeFaceTrackingSupport.isAvailable)
#else
        XCTAssertFalse(MediaPipeFaceTrackingSupport.isAvailable)
#endif
    }

    func testFactoryMakesTrackerOnlyWhenAvailable() throws {
        if MediaPipeFaceTrackingSupport.isAvailable {
            XCTAssertNoThrow(try MediaPipeFaceTrackingFactory.makeTracker())
        } else {
            XCTAssertThrowsError(try MediaPipeFaceTrackingFactory.makeTracker()) { error in
                XCTAssertEqual(
                    error as? MediaPipeFaceTrackingError,
                    .unsupportedArchitecture
                )
            }
        }
    }

    func testDetectFindsNoFacesInBlankFrame() throws {
        try XCTSkipUnless(MediaPipeFaceTrackingSupport.isAvailable)
        let tracker = try MediaPipeFaceTrackingFactory.makeTracker()
        let result = try tracker.detect(
            in: try Self.makeBlankPixelBuffer(width: 256, height: 256),
            timestampInMilliseconds: 0
        )
        XCTAssertTrue(result.faces.isEmpty)
    }

    func testBlendShapesCoverEveryChannelTheModelScores() {
        XCTAssertEqual(FaceBlendShape.allCases.count, 52)
    }

    func testBundledModelMetadataDescribesTheBundledModel() throws {
        let metadata = try FaceLandmarkerModel.metadata()
        XCTAssertEqual(metadata.license, "Apache-2.0")
        XCTAssertEqual(metadata.variant, "float16")
    }

    private static func makeBlankPixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
            [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw XCTSkip("Could not create a pixel buffer: \(status)")
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            memset(baseAddress, 0, CVPixelBufferGetDataSize(buffer))
        }
        return buffer
    }
}
