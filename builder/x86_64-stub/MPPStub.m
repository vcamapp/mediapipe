// Link-time stub for the x86_64 slice of MediaPipeTasksVision.framework.
//
// MediaPipe itself is built for arm64 only; this slice exists so that
// universal (arm64 + x86_64) apps can link the framework and launch on
// Intel Macs or under Rosetta. It contains no inference implementation:
// task initializers report an NSError, everything else raises. Callers are
// expected to check availability up front (running natively on Apple
// Silicon) instead of ever reaching this code.

#import "MPPStub.h"

double MediaPipeTasksVisionVersionNumber = 0;
const unsigned char MediaPipeTasksVisionVersionString[] = "MediaPipeTasksVision x86_64 stub";

NSString *const MPPStubErrorDomain = @"com.vcamapp.mediapipe.tasks.vision.stub";

static NSString *MPPStubMessage(NSString *className) {
    return [NSString stringWithFormat:
        @"%@ is unavailable: this process is running as x86_64 and the x86_64 "
        @"slice of MediaPipeTasksVision is a link-only stub. MediaPipe requires "
        @"native arm64 execution on Apple Silicon.", className];
}

void MPPStubRaise(NSString *className) {
    [NSException raise:@"MPPUnsupportedArchitectureException"
                format:@"%@", MPPStubMessage(className)];
    __builtin_unreachable();
}

NSError *MPPStubError(NSString *className) {
    return [NSError errorWithDomain:MPPStubErrorDomain
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey : MPPStubMessage(className)}];
}
