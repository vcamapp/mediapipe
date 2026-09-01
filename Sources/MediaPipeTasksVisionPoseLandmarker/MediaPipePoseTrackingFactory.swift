public enum MediaPipePoseTrackingError: Error, Equatable {
    case unsupportedArchitecture
}

public enum MediaPipePoseTrackingFactory {
    /// Creates a MediaPipe-backed pose landmark tracker.
    ///
    /// Throws `MediaPipePoseTrackingError.unsupportedArchitecture` when the
    /// process is not running natively on Apple Silicon; check
    /// `MediaPipePoseTrackingSupport.isAvailable` to fall back without
    /// triggering the error path.
    public static func makeTracker(
        configuration: PoseLandmarkTrackingConfiguration = PoseLandmarkTrackingConfiguration()
    ) throws -> any PoseLandmarkTracking {
#if arch(arm64)
        try MediaPipePoseLandmarkTracker(configuration: configuration)
#else
        throw MediaPipePoseTrackingError.unsupportedArchitecture
#endif
    }
}
