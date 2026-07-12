import CoreGraphics
import CoreVideo
import ImageIO
import Testing
import MediaPipeTasksVision
#if canImport(UIKit)
import UIKit
#endif

private func assertValidHandResult(_ result: HandLandmarkerResult) {
    #expect(result.landmarks.count > 0)
    #expect(result.landmarks.allSatisfy { $0.count == 21 })
    #expect(result.handedness.count == result.landmarks.count)
    #expect(result.worldLandmarks.count == result.landmarks.count)
}

private func makeHandLandmarker() throws -> HandLandmarker {
    let bundle = Bundle(for: SmokeTestBundleMarker.self)
    let modelURL = try #require(bundle.url(forResource: "hand_landmarker", withExtension: "task"))
    let options = HandLandmarkerOptions()
    options.baseOptions.modelAssetPath = modelURL.path
    return try HandLandmarker(options: options)
}

private func testImageURL() throws -> URL {
    let bundle = Bundle(for: SmokeTestBundleMarker.self)
    return try #require(bundle.url(forResource: "hand", withExtension: "jpg"))
}

// CVPixelBuffer is the platform-independent input path (and the only one on
// macOS, which has no UIImage). This mirrors how camera frames are consumed.
private func makeBGRAPixelBuffer(contentsOf url: URL) throws -> CVPixelBuffer {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    let cgImage = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))

    var pixelBuffer: CVPixelBuffer?
    let attributes = [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault, cgImage.width, cgImage.height,
        kCVPixelFormatType_32BGRA, attributes, &pixelBuffer
    )
    #expect(status == kCVReturnSuccess)
    let buffer = try #require(pixelBuffer)

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    let context = try #require(CGContext(
        data: CVPixelBufferGetBaseAddress(buffer),
        width: cgImage.width, height: cgImage.height,
        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue
    ))
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return buffer
}

@Test func handLandmarkerDetectsFixedImageFromPixelBuffer() throws {
    let pixelBuffer = try makeBGRAPixelBuffer(contentsOf: testImageURL())
    let image = try MPImage(pixelBuffer: pixelBuffer)
    let result = try makeHandLandmarker().detect(image: image)
    assertValidHandResult(result)
}

#if canImport(UIKit)
@Test func handLandmarkerDetectsFixedUIImage() throws {
    let uiImage = try #require(UIImage(contentsOfFile: testImageURL().path))
    let image = try MPImage(uiImage: uiImage)
    let result = try makeHandLandmarker().detect(image: image)
    assertValidHandResult(result)
}
#endif

private final class SmokeTestBundleMarker {}
