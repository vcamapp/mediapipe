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

private func testImageURL(_ name: String) throws -> URL {
    let bundle = Bundle(for: SmokeTestBundleMarker.self)
    return try #require(bundle.url(forResource: name, withExtension: "jpg"))
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
    let pixelBuffer = try makeBGRAPixelBuffer(contentsOf: testImageURL("hand"))
    let image = try MPImage(pixelBuffer: pixelBuffer)
    let result = try makeHandLandmarker().detect(image: image)
    assertValidHandResult(result)
}

#if canImport(UIKit)
@Test func handLandmarkerDetectsFixedUIImage() throws {
    let uiImage = try #require(UIImage(contentsOfFile: testImageURL("hand").path))
    let image = try MPImage(uiImage: uiImage)
    let result = try makeHandLandmarker().detect(image: image)
    assertValidHandResult(result)
}
#endif

private func assertValidPoseResult(_ result: PoseLandmarkerResult) {
    #expect(result.landmarks.count == 1)
    #expect(result.landmarks.allSatisfy { $0.count == 33 })
    #expect(result.worldLandmarks.count == result.landmarks.count)
}

private func makePoseLandmarker(delegate: Delegate) throws -> PoseLandmarker {
    let bundle = Bundle(for: SmokeTestBundleMarker.self)
    let modelURL = try #require(bundle.url(forResource: "pose_landmarker_lite", withExtension: "task"))
    let options = PoseLandmarkerOptions()
    options.baseOptions.modelAssetPath = modelURL.path
    options.baseOptions.delegate = delegate
    options.numPoses = 1
    return try PoseLandmarker(options: options)
}

// The CPU delegate must stay in full precision: the pose detector returns no
// detection at all when XNNPACK runs the model in FP16.
@Test func poseLandmarkerDetectsFixedImageOnCPU() throws {
    let pixelBuffer = try makeBGRAPixelBuffer(contentsOf: testImageURL("pose"))
    let result = try makePoseLandmarker(delegate: .CPU).detect(image: try MPImage(pixelBuffer: pixelBuffer))
    assertValidPoseResult(result)
}

#if os(macOS)
// Segmentation masks are not requested, so the graph must not build its mask
// branch: those calculators need shaders the macOS OpenGL context rejects.
@Test func poseLandmarkerDetectsFixedImageOnGPU() throws {
    let pixelBuffer = try makeBGRAPixelBuffer(contentsOf: testImageURL("pose"))
    let result = try makePoseLandmarker(delegate: .GPU).detect(image: try MPImage(pixelBuffer: pixelBuffer))
    assertValidPoseResult(result)
}
#endif

private func assertValidFaceResult(_ result: FaceLandmarkerResult) {
    #expect(result.faceLandmarks.count == 1)
    #expect(result.faceLandmarks.allSatisfy { $0.count == 478 })
    // The bundle's second model scores the 52 expression channels; it is the
    // only output that tells whether it ran at all.
    #expect(result.faceBlendshapes.count == result.faceLandmarks.count)
    #expect(result.faceBlendshapes.allSatisfy { $0.categories.count == 52 })
    // The scores are consumed by index, so the order is part of the contract.
    #expect(result.faceBlendshapes.first?.categories.first?.categoryName == "_neutral")
    #expect(result.faceBlendshapes.first?.categories.last?.categoryName == "noseSneerRight")
    #expect(result.facialTransformationMatrixes.allSatisfy { $0.rows == 4 && $0.columns == 4 })
}

private func makeFaceLandmarker(delegate: Delegate) throws -> FaceLandmarker {
    let bundle = Bundle(for: SmokeTestBundleMarker.self)
    let modelURL = try #require(bundle.url(forResource: "face_landmarker", withExtension: "task"))
    let options = FaceLandmarkerOptions()
    options.baseOptions.modelAssetPath = modelURL.path
    options.baseOptions.delegate = delegate
    options.numFaces = 1
    options.outputFaceBlendshapes = true
    options.outputFacialTransformationMatrixes = true
    return try FaceLandmarker(options: options)
}

@Test func faceLandmarkerDetectsFixedImageOnCPU() throws {
    let pixelBuffer = try makeBGRAPixelBuffer(contentsOf: testImageURL("face"))
    let result = try makeFaceLandmarker(delegate: .CPU).detect(image: try MPImage(pixelBuffer: pixelBuffer))
    assertValidFaceResult(result)
}

#if os(macOS)
@Test func faceLandmarkerDetectsFixedImageOnGPU() throws {
    let pixelBuffer = try makeBGRAPixelBuffer(contentsOf: testImageURL("face"))
    let result = try makeFaceLandmarker(delegate: .GPU).detect(image: try MPImage(pixelBuffer: pixelBuffer))
    assertValidFaceResult(result)
}
#endif

private final class SmokeTestBundleMarker {}
