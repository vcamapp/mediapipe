// Runs as an x86_64 process (Rosetta) to verify the link-only stub slice:
// the binary must link, dyld must load the framework, and the public classes
// must exist even though inference is unavailable.
import Foundation
import MediaPipeTasksVision

// Static references make the linker resolve each class against the stub.
let staticallyLinkedClasses: [AnyClass] = [
    FaceLandmarker.self, FaceLandmarkerOptions.self, FaceLandmarkerResult.self,
    GestureRecognizer.self, GestureRecognizerOptions.self, GestureRecognizerResult.self,
    HandLandmarker.self, HandLandmarkerOptions.self, HandLandmarkerResult.self,
    HolisticLandmarker.self, HolisticLandmarkerOptions.self, HolisticLandmarkerResult.self,
    PoseLandmarker.self, PoseLandmarkerOptions.self, PoseLandmarkerResult.self,
    BaseOptions.self, MPImage.self, NormalizedLandmark.self, Landmark.self,
    ResultCategory.self, Connection.self,
]

for anyClass in staticallyLinkedClasses {
    let name = NSStringFromClass(anyClass)
    precondition(NSClassFromString(name) != nil, "\(name) is missing from the stub")
}
print("x86_64 stub loaded (\(staticallyLinkedClasses.count) classes)")
