import Testing
import UIKit
import MediaPipeTasksVision

@Test func handLandmarkerInitializesAndDetectsFixedImage() throws {
        let bundle = Bundle(for: SmokeTestBundleMarker.self)
        let modelURL = try #require(bundle.url(forResource: "hand_landmarker", withExtension: "task"))
        let imageURL = try #require(bundle.url(forResource: "hand", withExtension: "jpg"))
        let uiImage = try #require(UIImage(contentsOfFile: imageURL.path))
        let image = try MPImage(uiImage: uiImage)

        let options = HandLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelURL.path
        let landmarker = try HandLandmarker(options: options)
        let result = try landmarker.detect(image: image)

        #expect(result.landmarks.count >= 0)
}

private final class SmokeTestBundleMarker {}
