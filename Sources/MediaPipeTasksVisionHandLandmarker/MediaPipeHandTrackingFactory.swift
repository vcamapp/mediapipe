public enum MediaPipeHandTrackingError: Error, Equatable {
    case unsupportedArchitecture
}

public enum MediaPipeHandTrackingFactory {
    /// Creates a MediaPipe-backed hand landmark tracker.
    ///
    /// Throws `MediaPipeHandTrackingError.unsupportedArchitecture` when the
    /// process is not running natively on Apple Silicon; check
    /// `MediaPipeHandTrackingSupport.isAvailable` to fall back without
    /// triggering the error path.
    public static func makeTracker(
        configuration: HandLandmarkTrackingConfiguration = HandLandmarkTrackingConfiguration()
    ) throws -> any HandLandmarkTracking {
#if arch(arm64)
        try MediaPipeHandLandmarkTracker(configuration: configuration)
#else
        throw MediaPipeHandTrackingError.unsupportedArchitecture
#endif
    }
}
