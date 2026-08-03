#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain used by the x86_64 link-only stub.
FOUNDATION_EXPORT NSString *const MPPStubErrorDomain;

/// Raises `MPPUnsupportedArchitectureException` explaining that MediaPipe is
/// unavailable in x86_64 processes.
FOUNDATION_EXPORT void MPPStubRaise(NSString *className) __attribute__((noreturn));

/// Returns an error explaining that MediaPipe is unavailable in x86_64
/// processes, for APIs whose signature can report failure.
FOUNDATION_EXPORT NSError *MPPStubError(NSString *className);

NS_ASSUME_NONNULL_END
