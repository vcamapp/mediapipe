import Foundation

/// Creates MediaPipe tasks with a defined XNNPACK inference precision.
///
/// The macOS framework reads `MEDIAPIPE_XNNPACK_FORCE_FP16` while a task builds
/// its CPU delegate. FP16 is roughly 1.8x faster but not safe for every model —
/// the pose detector stops producing detections entirely — so each task opts in
/// for itself. The value is only stable during creation, so every task
/// initializer goes through here and creation is serialized process-wide.
package enum XNNPackInference {
    private static let lock = NSLock()
    private static let variableName = "MEDIAPIPE_XNNPACK_FORCE_FP16"

    package static func makeTask<T>(forcingFP16: Bool, _ create: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }

        let previousValue = getenv(variableName).map { String(cString: $0) }
        setenv(variableName, forcingFP16 ? "1" : "0", 1)
        defer {
            if let previousValue {
                setenv(variableName, previousValue, 1)
            } else {
                unsetenv(variableName)
            }
        }

        return try create()
    }
}
