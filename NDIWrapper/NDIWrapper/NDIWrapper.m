#import "NDIWrapper.h"
#import "Processing.NDI.Lib.h"

@implementation NDIWrapper {
    NDIlib_send_instance_t my_ndi_send;
}

+ (void)initialize {
    NDIlib_initialize();
}

- (void)start:(NSString *)name {
    if (my_ndi_send) {
        my_ndi_send = nil;
    }
    NDIlib_send_create_t options;
    options.p_ndi_name = [name cStringUsingEncoding: NSUTF8StringEncoding];
    options.p_groups = NULL;
    options.clock_video = true;
    options.clock_audio = false;
    my_ndi_send = NDIlib_send_create(&options);
    if (!my_ndi_send) {
        NSLog(@"ERROR: Failed to create sender");
    } else {
        NSLog(@"Successfully created sender");
    }
}

- (void)tally {
    
}

- (void)stop {
    if (my_ndi_send) {
        NDIlib_send_destroy(my_ndi_send);
        my_ndi_send = nil;
    }
}

- (void)send:(CMSampleBufferRef)sampleBuffer {
    if (!my_ndi_send) {
        NSLog(@"ERROR: NDI instance is nil");
        return;
    }

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

    NDIlib_video_frame_v2_t video_frame;
    video_frame.frame_rate_N = 30000;
    video_frame.frame_rate_D = 1001;
    video_frame.FourCC = NDIlib_FourCC_type_BGRA;
    video_frame.frame_format_type = NDIlib_frame_format_type_progressive;
    video_frame.picture_aspect_ratio = 1.777777777777778;
    video_frame.p_metadata = NULL;

    // dynamic resolution based on buffersize
    video_frame.xres = (int)CVPixelBufferGetWidth(imageBuffer);
    video_frame.yres = (int)CVPixelBufferGetHeight(imageBuffer);
    video_frame.line_stride_in_bytes = video_frame.xres * 4;

    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    video_frame.p_data = CVPixelBufferGetBaseAddress(imageBuffer);
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    
    NDIlib_send_send_video_async_v2(my_ndi_send, &video_frame);
}

- (void)sendAudioBuffer:(AVAudioPCMBuffer *)audioSample {
  if (!my_ndi_send) {
    NSLog(@"ERROR: NDI instance is nil");
    return;
  }
  
  NDIlib_audio_frame_v2_t audio_frame;
  audio_frame.sample_rate = audioSample.format.sampleRate;
  audio_frame.no_channels = audioSample.format.channelCount;
  audio_frame.no_samples = audioSample.frameLength;
  audio_frame.channel_stride_in_bytes = (int)audioSample.stride;
  audio_frame.p_data = audioSample.floatChannelData[0];
  audio_frame.p_metadata = NULL;
  
  NDIlib_send_send_audio_v2(my_ndi_send, &audio_frame);
}

@end
