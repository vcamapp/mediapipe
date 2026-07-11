#import <MediaPipeTasksVision/MPPFaceLandmarker.h>
#import <MediaPipeTasksVision/MPPHandLandmarker.h>
#import <MediaPipeTasksVision/MPPHolisticLandmarker.h>
#import <MediaPipeTasksVision/MPPPoseLandmarker.h>

void MPPForceLinkMediaPipeTasksVision(void) {
    (void)[MPPFaceLandmarker class];
    (void)[MPPHandLandmarker class];
    (void)[MPPHolisticLandmarker class];
    (void)[MPPPoseLandmarker class];
}
