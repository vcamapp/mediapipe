public enum MediaPipeFaceTrackingError: Error, Equatable {
    case unsupportedArchitecture
}

public enum MediaPipeFaceTrackingFactory {
    /// Creates a MediaPipe-backed face landmark tracker.
    ///
    /// Throws `MediaPipeFaceTrackingError.unsupportedArchitecture` when the
    /// process is not running natively on Apple Silicon; check
    /// `MediaPipeFaceTrackingSupport.isAvailable` to fall back without
    /// triggering the error path.
    public static func makeTracker(
        configuration: FaceLandmarkTrackingConfiguration = FaceLandmarkTrackingConfiguration()
    ) throws -> any FaceLandmarkTracking {
#if arch(arm64)
        try MediaPipeFaceLandmarkTracker(configuration: configuration)
#else
        throw MediaPipeFaceTrackingError.unsupportedArchitecture
#endif
    }
}
