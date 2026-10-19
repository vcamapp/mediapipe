// Copyright 2023 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#endif

#if __has_include(<UIKit/UIKit.h>)
/**
 * The display orientation of an image. On platforms with UIKit this is an alias of
 * `UIImage.Orientation` so that the public API is source and binary compatible with the
 * official iOS distribution. On platforms without UIKit (macOS) an equivalent enum with
 * identical raw values is provided.
 */
typedef UIImageOrientation MPPImageOrientation;

static const MPPImageOrientation MPPImageOrientationUp = UIImageOrientationUp;
static const MPPImageOrientation MPPImageOrientationDown = UIImageOrientationDown;
static const MPPImageOrientation MPPImageOrientationLeft = UIImageOrientationLeft;
static const MPPImageOrientation MPPImageOrientationRight = UIImageOrientationRight;
static const MPPImageOrientation MPPImageOrientationUpMirrored = UIImageOrientationUpMirrored;
static const MPPImageOrientation MPPImageOrientationDownMirrored = UIImageOrientationDownMirrored;
static const MPPImageOrientation MPPImageOrientationLeftMirrored = UIImageOrientationLeftMirrored;
static const MPPImageOrientation MPPImageOrientationRightMirrored =
    UIImageOrientationRightMirrored;
#else
#import <CoreGraphics/CoreGraphics.h>

/**
 * The display orientation of an image. Mirrors the cases and raw values of
 * `UIImage.Orientation` on platforms where UIKit is unavailable (macOS).
 */
typedef NS_ENUM(NSInteger, MPPImageOrientation) {
  MPPImageOrientationUp,
  MPPImageOrientationDown,
  MPPImageOrientationLeft,
  MPPImageOrientationRight,
  MPPImageOrientationUpMirrored,
  MPPImageOrientationDownMirrored,
  MPPImageOrientationLeftMirrored,
  MPPImageOrientationRightMirrored,
} NS_SWIFT_NAME(MPImageOrientation);
#endif  // __has_include(<UIKit/UIKit.h>)

NS_ASSUME_NONNULL_BEGIN

/** Types of image sources. */
typedef NSInteger MPPImageSourceType NS_TYPED_ENUM NS_SWIFT_NAME(MPImageSourceType);
/** Image source is a `UIImage`. */
static const MPPImageSourceType MPPImageSourceTypeImage = 0;
/** Image source is a `CVPixelBuffer`. */
static const MPPImageSourceType MPPImageSourceTypePixelBuffer = 1;
/** Image source is a `CMSampleBuffer`. */
static const MPPImageSourceType MPPImageSourceTypeSampleBuffer = 2;

/** An image used in on-device machine learning using MediaPipe Task library. */
NS_SWIFT_NAME(MPImage)
@interface MPPImage : NSObject

/** Width of the image in pixels. */
@property(nonatomic, readonly) CGFloat width;

/** Height of the image in pixels. */
@property(nonatomic, readonly) CGFloat height;

/**
 * The display orientation of the image. If `imageSourceType` is `.image`, the
 * default value is `image.imageOrientation`; otherwise the default value is
 * `UIImage.Orientation.up`. If the `MPImage` is being used as input for any MediaPipe vision tasks
 * and is set to any orientation other than `UIImage.Orientation.up`, inference will be performed on
 * a rotated copy of the image according to the orientation.
 */
@property(nonatomic, readonly) MPPImageOrientation orientation;

/** The type of the image source. */
@property(nonatomic, readonly) MPPImageSourceType imageSourceType;

#if __has_include(<UIKit/UIKit.h>)
/** The source image. `nil` if `imageSourceType` is not `.image`. */
@property(nonatomic, readonly, nullable) UIImage *image;
#endif  // __has_include(<UIKit/UIKit.h>)

/** The source pixel buffer. `nil` if ``imageSourceType`` is not `.pixelBuffer`. */
@property(nonatomic, readonly, nullable) CVPixelBufferRef pixelBuffer;

/** The source sample buffer. `nil` if ``imageSourceType`` is not `.sampleBuffer`. */
@property(nonatomic, readonly, nullable) CMSampleBufferRef sampleBuffer;

#if __has_include(<UIKit/UIKit.h>)
/**
 * Initializes an `MPImage` object with the given `UIImage`.
 *
 * The orientation of the newly created `MPImage` will be equal to the `imageOrientation` of
 * `UIImage` and when sent to the vision tasks for inference, rotation will be applied accordingly.
 * To create an `MPImage` with an orientation different from its `imageOrientation`, please use
 * `MPImage(uiImage:orientation:)s`.
 *
 * @param image The image to use as the source. Its `CGImage` property must not be `NULL`.
 * @param error An optional error parameter populated when there is an error in initializing the
 * `MPImage`.
 *
 * @return A new `MPImage` instance with the given image as the source. `nil` if the given
 * `image` is `nil` or invalid.
 */
- (nullable instancetype)initWithUIImage:(UIImage *)image error:(NSError **)error;

/**
 * Initializes an `MPImage` object with the given `UIImage` and orientation.
 *
 * The given orientation will be used to calculate the rotation to be applied to the `UIImage`
 * before inference is performed on it by the vision tasks. The `imageOrientation` stored in the
 * `UIImage` is ignored when `MPImage` objects created by this method are sent to the vision tasks
 * for inference. Use `MPImage(uiImage:)` to initialize images with the `imageOrientation` of
 * `UIImage`.
 *
 * If the newly created `MPImage` is used as input for any MediaPipe vision tasks, inference
 * will be performed on a copy of the image rotated according to the orientation.
 *
 * @param image The image to use as the source. Its `CGImage` property must not be `NULL`.
 * @param orientation The display orientation of the image. This will be stored in the property
 *     `orientation` `MPImage` and will override the `imageOrientation` of the passed in `UIImage`.
 * @param error An optional error parameter populated when there is an error in initializing the
 *     `MPImage`.
 *
 * @return A new `MPImage` instance with the given image as the source. `nil` if the given
 *     `image` is `nil` or invalid.
 */
- (nullable instancetype)initWithUIImage:(UIImage *)image
                             orientation:(MPPImageOrientation)orientation
                                   error:(NSError **)error NS_DESIGNATED_INITIALIZER;
#endif  // __has_include(<UIKit/UIKit.h>)

/**
 * Initializes an `MPImage` object with the given pixel buffer.
 *
 * The orientation of the newly created `MPImage` will be `UIImageOrientationUp`.
 * Hence, if this image is used as input for any MediaPipe vision tasks, inference will be
 * performed on the it without any rotation. To create an `MPImage` with a different
 * orientation, please use `MPImage(pixelBuffer:orientation:)`.
 *
 * @param pixelBuffer The pixel buffer to use as the source. It will be retained by the new
 *     `MPImage` instance for the duration of its lifecycle.
 * @param error An optional error parameter populated when there is an error in initializing the
 *     `MPImage`.
 *
 * @return A new `MPImage` instance with the given pixel buffer as the source. `nil` if the
 * given pixel buffer is `nil` or invalid.
 */
- (nullable instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError **)error;

/**
 * Initializes an `MPImage` object with the given pixel buffer and orientation.
 *
 * If the newly created `MPImage` is used as input for any MediaPipe vision tasks, inference
 * will be performed on a copy of the image rotated according to the orientation.
 *
 * @param pixelBuffer The pixel buffer to use as the source. It will be retained by the new
 *     `MPImage` instance for the duration of its lifecycle.
 * @param orientation The display orientation of the image.
 * @param error An optional error parameter populated when there is an error in initializing the
 *     `MPImage`.
 *
 * @return A new `MPImage` instance with the given orientation and pixel buffer as the source.
 * `nil` if the given pixel buffer is `nil` or invalid.
 */
- (nullable instancetype)initWithPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                 orientation:(MPPImageOrientation)orientation
                                       error:(NSError **)error NS_DESIGNATED_INITIALIZER;

/**
 * Initializes an `MPImage` object with the given sample buffer.
 *
 * The orientation of the newly created `MPImage` will be `UIImageOrientationUp`.
 * Hence, if this image is used as input for any MediaPipe vision tasks, inference will be
 * performed on the it without any rotation. To create an `MPImage` with a different orientation,
 * please use `MPImage(sampleBuffer:orientation:)`.
 *
 * @param sampleBuffer The sample buffer to use as the source. It will be retained by the new
 *     `MPImage` instance for the duration of its lifecycle. The sample buffer must be based on
 *     a pixel buffer (not compressed data). In practice, it should be the video output of the
 *     camera on an iOS device, not other arbitrary types of `CMSampleBuffer`s.
 * @return A new `MPImage` instance with the given sample buffer as the source. `nil` if the
 *     given sample buffer is `nil` or invalid.
 */
- (nullable instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                        error:(NSError **)error;

/**
 * Initializes an `MPImage` object with the given sample buffer and orientation.
 *
 * If the newly created `MPImage` is used as input for any MediaPipe vision tasks, inference
 * will be performed on a copy of the image rotated according to the orientation.
 *
 * @param sampleBuffer The sample buffer to use as the source. It will be retained by the new
 *     `MPImage` instance for the duration of its lifecycle. The sample buffer must be based on
 *     a pixel buffer (not compressed data). In practice, it should be the video output of the
 *     camera on an iOS device, not other arbitrary types of `CMSampleBuffer`s.
 * @param orientation The display orientation of the image.
 * @return A new `MPImage` instance with the given orientation and sample buffer as the source.
 *     `nil` if the given sample buffer is `nil` or invalid.
 */
- (nullable instancetype)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                  orientation:(MPPImageOrientation)orientation
                                        error:(NSError **)error NS_DESIGNATED_INITIALIZER;

/** Unavailable. */
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
