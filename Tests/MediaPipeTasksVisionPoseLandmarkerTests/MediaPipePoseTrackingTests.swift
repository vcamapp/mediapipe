import CoreVideo
import XCTest
import MediaPipeTasksVisionPoseLandmarker

final class MediaPipePoseTrackingTests: XCTestCase {
    func testAvailabilityMatchesExecutionArchitecture() {
#if arch(arm64)
        XCTAssertTrue(MediaPipePoseTrackingSupport.isAvailable)
#else
        XCTAssertFalse(MediaPipePoseTrackingSupport.isAvailable)
#endif
    }

    func testFactoryMakesTrackerOnlyWhenAvailable() throws {
        if MediaPipePoseTrackingSupport.isAvailable {
            XCTAssertNoThrow(try MediaPipePoseTrackingFactory.makeTracker())
        } else {
            XCTAssertThrowsError(try MediaPipePoseTrackingFactory.makeTracker()) { error in
                XCTAssertEqual(
                    error as? MediaPipePoseTrackingError,
                    .unsupportedArchitecture
                )
            }
        }
    }

    func testDetectFindsNoPosesInBlankFrame() throws {
        try XCTSkipUnless(MediaPipePoseTrackingSupport.isAvailable)
        let tracker = try MediaPipePoseTrackingFactory.makeTracker()
        let result = try tracker.detect(
            in: try Self.makeBlankPixelBuffer(width: 256, height: 256),
            timestampInMilliseconds: 0
        )
        XCTAssertTrue(result.poses.isEmpty)
    }

    func testBundledModelMetadataDescribesTheBundledModel() throws {
        let metadata = try PoseLandmarkerModel.metadata()
        XCTAssertEqual(metadata.license, "Apache-2.0")
        XCTAssertEqual(metadata.variant, "lite-float16")
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
