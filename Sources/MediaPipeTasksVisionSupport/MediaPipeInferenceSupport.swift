public enum MediaPipeInferenceSupport {
    /// Whether MediaPipe inference is available in the current process.
    ///
    /// The decision is based on the executing binary slice: the x86_64 slice
    /// of `MediaPipeTasksVision` is a link-only stub, so this is `false` on
    /// Intel Macs and also on Apple Silicon Macs when running under Rosetta.
    public static var isAvailable: Bool {
#if arch(arm64)
        true
#else
        false
#endif
    }
}
