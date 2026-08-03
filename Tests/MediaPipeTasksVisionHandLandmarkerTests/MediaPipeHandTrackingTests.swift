import CoreVideo
import XCTest
import MediaPipeTasksVisionHandLandmarker

final class MediaPipeHandTrackingTests: XCTestCase {
    func testAvailabilityMatchesExecutionArchitecture() {
#if arch(arm64)
        XCTAssertTrue(MediaPipeHandTrackingSupport.isAvailable)
#else
        XCTAssertFalse(MediaPipeHandTrackingSupport.isAvailable)
#endif
    }

    func testFactoryMakesTrackerOnlyWhenAvailable() throws {
        if MediaPipeHandTrackingSupport.isAvailable {
            XCTAssertNoThrow(try MediaPipeHandTrackingFactory.makeTracker())
        } else {
            XCTAssertThrowsError(try MediaPipeHandTrackingFactory.makeTracker()) { error in
                XCTAssertEqual(
                    error as? MediaPipeHandTrackingError,
                    .unsupportedArchitecture
                )
            }
        }
    }

    func testDetectFindsNoHandsInBlankFrame() throws {
        try XCTSkipUnless(MediaPipeHandTrackingSupport.isAvailable)
        let tracker = try MediaPipeHandTrackingFactory.makeTracker()
        let result = try tracker.detect(
            in: try Self.makeBlankPixelBuffer(width: 256, height: 256),
            timestampInMilliseconds: 0
        )
        XCTAssertTrue(result.hands.isEmpty)
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
