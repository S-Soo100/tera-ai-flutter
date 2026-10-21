#import <WebRTC/WebRTC.h>
#import "FlutterRTCMediaRecorder.h"
#import "FlutterRTCAudioSink.h"
#import "FlutterRTCFrameCapturer.h"

@import AVFoundation;

@implementation FlutterRTCMediaRecorder {
    int framesCount;
    bool isInitialized;
    CGSize _renderSize;
    FlutterRTCAudioSink* _audioSink;
    AVAssetWriterInput* _audioWriter;
    int64_t _startTime;
}

- (instancetype)initWithVideoTrack:(RTCVideoTrack *)video audioTrack:(RTCAudioTrack *)audio outputFile:(NSURL *)out {
    self = [super init];
    isInitialized = false;
    self.videoTrack = video;
    self.output = out;
    [video addRenderer:self];
    framesCount = 0;
    if (audio != nil)
        _audioSink = [[FlutterRTCAudioSink alloc] initWithAudioTrack:audio];
    else
        NSLog(@"Audio track is nil");
    _startTime = -1;
    return self;
}

- (void)initialize:(CGSize)size {
    _renderSize = size;
    NSDictionary *videoSettings = @{
        // vivanaut patch: 6Mbps→1.5Mbps + 키프레임 최대 5초(Android IFRAME_INTERVAL과 같게).
        // AVVideoExpectedSourceFrameRateKey·AllowFrameReordering을 넣으면 시뮬레이터에서
        // 기록이 -11800/-12419로 실패해 뺐다(2026-10-21). packages/README.md
        // ⚠️ 미검증: 시뮬레이터는 1.5Mbps를 무시하고 약 2.9Mbps로 기록한다. 실제
        // iPhone 측정 전 iOS 배포 금지(사용자 결정 2026-10-21, live_recording.dart).
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(1500000),
            AVVideoMaxKeyFrameIntervalDurationKey: @(5),
        },
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoHeightKey: @(size.height),
        AVVideoWidthKey: @(size.width),
    };
    self.writerInput = [[AVAssetWriterInput alloc]
            initWithMediaType:AVMediaTypeVideo
               outputSettings:videoSettings];
    self.writerInput.expectsMediaDataInRealTime = true;
    self.writerInput.mediaTimeScale = 30;

    if (_audioSink != nil) {
        AudioChannelLayout acl;
        bzero(&acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
        NSDictionary* audioSettings = @{
            AVFormatIDKey: [NSNumber numberWithInt: kAudioFormatMPEG4AAC],
            AVNumberOfChannelsKey: @1,
            AVSampleRateKey: @44100.0,
            AVChannelLayoutKey: [NSData dataWithBytes:&acl length:sizeof(AudioChannelLayout)],
            AVEncoderBitRateKey: @64000,
        };
        _audioWriter = [[AVAssetWriterInput alloc]
                        initWithMediaType:AVMediaTypeAudio
                        outputSettings:audioSettings
                        sourceFormatHint:_audioSink.format];
        _audioWriter.expectsMediaDataInRealTime = true;
    }
    
    NSError *error;
    self.assetWriter = [[AVAssetWriter alloc]
            initWithURL:self.output
               fileType:AVFileTypeMPEG4
                  error:&error];
    if (error != nil)
        NSLog(@"%@",[error localizedDescription]);
    self.assetWriter.shouldOptimizeForNetworkUse = true;
    [self.assetWriter addInput:self.writerInput];
    if (_audioWriter != nil) {
        [self.assetWriter addInput:_audioWriter];
        _audioSink.bufferCallback = ^(CMSampleBufferRef buffer){
            if (self->_audioWriter.readyForMoreMediaData) {
                if ([self->_audioWriter appendSampleBuffer:buffer])
                    NSLog(@"Audio frame appended");
                else
                    NSLog(@"Audioframe not appended %@", self.assetWriter.error);
            }
        };
    }
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    isInitialized = true;
}

- (void)setSize:(CGSize)size {
}

- (void)renderFrame:(nullable RTCVideoFrame *)frame {
    // vivanaut patch: WebRTC가 프레임을 여러 스레드에서 넘겨 appendSampleBuffer·
    // initialize가 동시에 돌았다 → AVAssetWriter -11800/-12419로 녹화 실패
    // (2026-10-21 시뮬레이터 로그, 실패 프레임 스레드가 둘). 한 번에 하나씩.
    @synchronized (self) {
        [self renderFrameLocked:frame];
    }
}

- (void)renderFrameLocked:(nullable RTCVideoFrame *)frame {
    if (frame == nil) {
        return;
    }
    if (!isInitialized) {
        [self initialize:CGSizeMake((CGFloat) frame.width, (CGFloat) frame.height)];
    }
    // 멈춘 뒤(markAsFinished)·실패 뒤 들어온 프레임은 버린다(vivanaut patch).
    // ⚠️ 미해결(2026-10-21): 직렬화 뒤에도 시뮬레이터에서 녹화 도중 -11800/-12419가
    // 간헐적으로 한 번 나면 writer가 실패 상태가 되어 그 녹화 전체를 잃는다.
    // iOS 배포 전 실기기 확인 필요 — 계획서 2026-10-21-live-recording-figma.md §12.
    if (self.assetWriter.status != AVAssetWriterStatusWriting) {
        return;
    }
    if (!self.writerInput.readyForMoreMediaData) {
        NSLog(@"Drop frame, not ready");
        return;
    }
    id <RTCVideoFrameBuffer> buffer = frame.buffer;
    CVPixelBufferRef pixelBufferRef;
    BOOL shouldRelease = false;
    if ([buffer isKindOfClass:[RTCCVPixelBuffer class]]) {
        pixelBufferRef = ((RTCCVPixelBuffer *) buffer).pixelBuffer;
    } else {
        pixelBufferRef = [FlutterRTCFrameCapturer convertToCVPixelBuffer:frame];
        shouldRelease = true;
    }
    CMVideoFormatDescriptionRef formatDescription = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBufferRef, &formatDescription);
    
    if (status != noErr || formatDescription == NULL) {
        NSLog(@"Failed to create format description: %d", (int)status);
        if (shouldRelease) {
            CVPixelBufferRelease(pixelBufferRef);
        }
        return;
    }

    CMSampleTimingInfo timingInfo;
    
    timingInfo.decodeTimeStamp = kCMTimeInvalid;
    if (_startTime == -1) {
        _startTime = frame.timeStampNs / 1000;
    }
    int64_t frameTime = (frame.timeStampNs / 1000) - _startTime;
    timingInfo.presentationTimeStamp = CMTimeMake(frameTime, 1000000);
    framesCount++;

    CMSampleBufferRef outBuffer = NULL;

    status = CMSampleBufferCreateReadyWithImageBuffer(
        kCFAllocatorDefault,
        pixelBufferRef,
        formatDescription,
        &timingInfo,
        &outBuffer
    );

    if (status == noErr && outBuffer != NULL) {
        if (![self.writerInput appendSampleBuffer:outBuffer]) {
            NSLog(@"Frame not appended %@", self.assetWriter.error);
        }
    } else {
        NSLog(@"Failed to create sample buffer: %d", (int)status);
    }
    
    // Release Core Foundation objects to prevent memory leaks
    if (outBuffer != NULL) {
        CFRelease(outBuffer);
    }
    if (formatDescription != NULL) {
        CFRelease(formatDescription);
    }
    if (shouldRelease) {
        CVPixelBufferRelease(pixelBufferRef);
    }
}

- (void)stop:(FlutterResult _Nonnull) result {
    // 녹화 중인 프레임 처리가 끝난 뒤 멈춘다(위 renderFrame 잠금과 같은 객체).
    @synchronized (self) {
        [self.videoTrack removeRenderer:self];
    }
    if (_audioSink != nil) {
        _audioSink.bufferCallback = nil;
        [_audioSink close];
    }
    [self.videoTrack removeRenderer:self];
    [self.writerInput markAsFinished];
    [_audioWriter markAsFinished];
    dispatch_async(dispatch_get_main_queue(), ^{
       [self.assetWriter finishWritingWithCompletionHandler:^{
           NSError* error = self.assetWriter.error;
           if (error == nil) {
               result(nil);
           } else {
               result([FlutterError errorWithCode:@"Failed to save recording"
                                          message:[error localizedDescription]
                                          details:nil]);
           }
       }];
    });
}

@end
