// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "BetterPlayer.h"
#import <better_player/better_player-Swift.h>

static void* timeRangeContext = &timeRangeContext;
static void* statusContext = &statusContext;
static void* playbackLikelyToKeepUpContext = &playbackLikelyToKeepUpContext;
static void* playbackBufferEmptyContext = &playbackBufferEmptyContext;
static void* playbackBufferFullContext = &playbackBufferFullContext;
static void* presentationSizeContext = &presentationSizeContext;

#if TARGET_OS_IOS
void (^__strong _Nonnull _restoreUserInterfaceForPIPStopCompletionHandler)(BOOL);
API_AVAILABLE(ios(9.0))
AVPictureInPictureController *_pipController;
#endif

@implementation BetterPlayer

#pragma mark - ✅ NEW: Helper methods for YouTube merge (NO effect unless isYouTube == true)

- (AVURLAsset*)_bpUrlAssetWithURL:(NSURL*)url headers:(NSDictionary*)headers {
    if (headers == nil || headers == (id)[NSNull null]) {
        headers = @{};
    }
    return [AVURLAsset URLAssetWithURL:url options:@{@"AVURLAssetHTTPHeaderFieldsKey": headers}];
}

- (void)_bpBuildMergedItemWithVideoURL:(NSURL*)videoURL
                              audioURL:(NSURL*)audioURL
                               headers:(NSDictionary*)headers
                            completion:(void (^)(AVPlayerItem* item, NSError* error))completion {

    AVURLAsset* videoAsset = [self _bpUrlAssetWithURL:videoURL headers:headers];
    AVURLAsset* audioAsset = [self _bpUrlAssetWithURL:audioURL headers:headers];

    dispatch_group_t group = dispatch_group_create();
    __block NSError* vErr = nil;
    __block NSError* aErr = nil;

    dispatch_group_enter(group);
    [videoAsset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration"] completionHandler:^ {
        NSError* err = nil;
        AVKeyValueStatus s1 = [videoAsset statusOfValueForKey:@"tracks" error:&err];
        if (s1 != AVKeyValueStatusLoaded) {
            vErr = err ?: [NSError errorWithDomain:@"BetterPlayer"
                                              code:-100
                                          userInfo:@{NSLocalizedDescriptionKey:@"Video tracks not loaded"}];
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [audioAsset loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration"] completionHandler:^ {
        NSError* err = nil;
        AVKeyValueStatus s1 = [audioAsset statusOfValueForKey:@"tracks" error:&err];
        if (s1 != AVKeyValueStatusLoaded) {
            aErr = err ?: [NSError errorWithDomain:@"BetterPlayer"
                                              code:-101
                                          userInfo:@{NSLocalizedDescriptionKey:@"Audio tracks not loaded"}];
        }
        dispatch_group_leave(group);
    }];

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (self->_disposed) return;

        NSError* err = vErr ?: aErr;
        if (err) {
            completion(nil, err);
            return;
        }

        AVAssetTrack* vTrack = [[videoAsset tracksWithMediaType:AVMediaTypeVideo] firstObject];
        AVAssetTrack* aTrack = [[audioAsset tracksWithMediaType:AVMediaTypeAudio] firstObject];

        if (!vTrack || !aTrack) {
            completion(nil, [NSError errorWithDomain:@"BetterPlayer"
                                               code:-102
                                           userInfo:@{NSLocalizedDescriptionKey:@"Missing video or audio track"}]);
            return;
        }

        AVMutableComposition* mix = [AVMutableComposition composition];

        CMTime duration = videoAsset.duration;
        if (CMTIME_IS_INVALID(duration) || CMTIME_IS_INDEFINITE(duration)) {
            duration = audioAsset.duration;
        }
        if (CMTIME_IS_INVALID(duration) || CMTIME_IS_INDEFINITE(duration) ||
            CMTIME_COMPARE_INLINE(duration, ==, kCMTimeZero)) {
            duration = videoAsset.duration;
        }

        CMTimeRange fullRange = CMTimeRangeMake(kCMTimeZero, duration);

        // Video
        AVMutableCompositionTrack* compVideo =
        [mix addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];

        NSError* insErr = nil;
        [compVideo insertTimeRange:fullRange ofTrack:vTrack atTime:kCMTimeZero error:&insErr];
        if (insErr) {
            completion(nil, insErr);
            return;
        }
        compVideo.preferredTransform = vTrack.preferredTransform;

        // Audio
        AVMutableCompositionTrack* compAudio =
        [mix addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];

        insErr = nil;
        [compAudio insertTimeRange:fullRange ofTrack:aTrack atTime:kCMTimeZero error:&insErr];
        if (insErr) {
            completion(nil, insErr);
            return;
        }

        AVPlayerItem* mergedItem = [AVPlayerItem playerItemWithAsset:mix];
        completion(mergedItem, nil);
    });
}

#pragma mark - ✅ FIXED: Switch to merged item using BetterPlayer pipeline + re-init

- (void)_bpSwitchToMergedItemUsingBetterPlayerPipeline:(AVPlayerItem*)item
                                              withKey:(NSString*)key
                                               seekTo:(CMTime)time {
    if (_disposed) return;

    BOOL wasPlaying = _isPlaying;
    double rate = _playerRate;

    // ✅ Force re-init so onReadyToPlay runs again for the new item
    _isInitialized = false;

    // ✅ Use existing BetterPlayer setup (adds observers + applies videoComposition/transform)
    [self setDataSourcePlayerItem:item withKey:key];

    __weak BetterPlayer* weakSelf = self;
    [_player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        BetterPlayer* strongSelf = weakSelf;
        if (!strongSelf || strongSelf->_disposed) return;

        if (wasPlaying) {
            if (@available(iOS 10.0, *)) {
                [strongSelf->_player playImmediatelyAtRate:1.0];
                strongSelf->_player.rate = rate;
            } else {
                [strongSelf->_player play];
                strongSelf->_player.rate = rate;
            }
        } else {
            [strongSelf->_player pause];
        }
    }];
}

#pragma mark - Existing init/view/etc.

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super init];
    NSAssert(self, @"super init cannot be nil");
    _isInitialized = false;
    _isPlaying = false;
    _disposed = false;
    _player = [[AVPlayer alloc] init];
    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    ///Fix for loading large videos
    if (@available(iOS 10.0, *)) {
        _player.automaticallyWaitsToMinimizeStalling = false;
    }
    self._observersAdded = false;
    return self;
}

- (nonnull UIView *)view {
    BetterPlayerView *playerView = [[BetterPlayerView alloc] initWithFrame:CGRectZero];
    playerView.player = _player;
    return playerView;
}

- (void)addObservers:(AVPlayerItem*)item {
    if (!self._observersAdded){
        [_player addObserver:self forKeyPath:@"rate" options:0 context:nil];
        [item addObserver:self forKeyPath:@"loadedTimeRanges" options:0 context:timeRangeContext];
        [item addObserver:self forKeyPath:@"status" options:0 context:statusContext];
        [item addObserver:self forKeyPath:@"presentationSize" options:0 context:presentationSizeContext];
        [item addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:0 context:playbackLikelyToKeepUpContext];
        [item addObserver:self forKeyPath:@"playbackBufferEmpty" options:0 context:playbackBufferEmptyContext];
        [item addObserver:self forKeyPath:@"playbackBufferFull" options:0 context:playbackBufferFullContext];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(itemDidPlayToEndTime:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:item];
        self._observersAdded = true;
    }
}

- (void)clear {
    _isInitialized = false;
    _isPlaying = false;
    _disposed = false;
    _failedCount = 0;
    _key = nil;
    if (_player.currentItem == nil) {
        return;
    }

    if (_player.currentItem == nil) {
        return;
    }

    [self removeObservers];
    AVAsset* asset = [_player.currentItem asset];
    [asset cancelLoading];
}

- (void) removeObservers{
    if (self._observersAdded){
        [_player removeObserver:self forKeyPath:@"rate" context:nil];
        [[_player currentItem] removeObserver:self forKeyPath:@"status" context:statusContext];
        [[_player currentItem] removeObserver:self forKeyPath:@"presentationSize" context:presentationSizeContext];
        [[_player currentItem] removeObserver:self forKeyPath:@"loadedTimeRanges" context:timeRangeContext];
        [[_player currentItem] removeObserver:self forKeyPath:@"playbackLikelyToKeepUp" context:playbackLikelyToKeepUpContext];
        [[_player currentItem] removeObserver:self forKeyPath:@"playbackBufferEmpty" context:playbackBufferEmptyContext];
        [[_player currentItem] removeObserver:self forKeyPath:@"playbackBufferFull" context:playbackBufferFullContext];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        self._observersAdded = false;
    }
}

- (void)itemDidPlayToEndTime:(NSNotification*)notification {
    if (_isLooping) {
        AVPlayerItem* p = [notification object];
        [p seekToTime:kCMTimeZero completionHandler:nil];
    } else {
        if (_eventSink) {
            _eventSink(@{@"event" : @"completed", @"key" : _key});
            [ self removeObservers];
        }
    }
}

static inline CGFloat radiansToDegrees(CGFloat radians) {
    CGFloat degrees = GLKMathRadiansToDegrees((float)radians);
    if (degrees < 0) {
        return degrees + 360;
    }
    return degrees;
};

- (AVMutableVideoComposition*)getVideoCompositionWithTransform:(CGAffineTransform)transform
                                                     withAsset:(AVAsset*)asset
                                                withVideoTrack:(AVAssetTrack*)videoTrack {
    AVMutableVideoCompositionInstruction* instruction =
    [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [asset duration]);
    AVMutableVideoCompositionLayerInstruction* layerInstruction =
    [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
    [layerInstruction setTransform:_preferredTransform atTime:kCMTimeZero];

    AVMutableVideoComposition* videoComposition = [AVMutableVideoComposition videoComposition];
    instruction.layerInstructions = @[ layerInstruction ];
    videoComposition.instructions = @[ instruction ];

    CGFloat width = videoTrack.naturalSize.width;
    CGFloat height = videoTrack.naturalSize.height;
    NSInteger rotationDegrees =
    (NSInteger)round(radiansToDegrees(atan2(_preferredTransform.b, _preferredTransform.a)));
    if (rotationDegrees == 90 || rotationDegrees == 270) {
        width = videoTrack.naturalSize.height;
        height = videoTrack.naturalSize.width;
    }
    videoComposition.renderSize = CGSizeMake(width, height);

    float nominalFrameRate = videoTrack.nominalFrameRate;
    int fps = 30;
    if (nominalFrameRate > 0) {
        fps = (int) ceil(nominalFrameRate);
    }
    videoComposition.frameDuration = CMTimeMake(1, fps);

    return videoComposition;
}

- (CGAffineTransform)fixTransform:(AVAssetTrack*)videoTrack {
  CGAffineTransform transform = videoTrack.preferredTransform;
  NSInteger rotationDegrees = (NSInteger)round(radiansToDegrees(atan2(transform.b, transform.a)));
  if (rotationDegrees == 90) {
    transform.tx = videoTrack.naturalSize.height;
    transform.ty = 0;
  } else if (rotationDegrees == 180) {
    transform.tx = videoTrack.naturalSize.width;
    transform.ty = videoTrack.naturalSize.height;
  } else if (rotationDegrees == 270) {
    transform.tx = 0;
    transform.ty = videoTrack.naturalSize.width;
  }
  return transform;
}

- (void)setDataSourceAsset:(NSString*)asset withKey:(NSString*)key withCertificateUrl:(NSString*)certificateUrl withLicenseUrl:(NSString*)licenseUrl cacheKey:(NSString*)cacheKey cacheManager:(CacheManager*)cacheManager overriddenDuration:(int) overriddenDuration{
    NSString* path = [[NSBundle mainBundle] pathForResource:asset ofType:nil];
    return [self setDataSourceURL:[NSURL fileURLWithPath:path]
                          withKey:key
               withCertificateUrl:certificateUrl
                   withLicenseUrl:(NSString*)licenseUrl
                      withHeaders:@{}
                        withCache:false
                         cacheKey:cacheKey
                     cacheManager:cacheManager
              overriddenDuration:overriddenDuration
                 videoExtension:nil];
}

#pragma mark - ✅ Existing method remains, now forwards to new method with isYouTube:NO

- (void)setDataSourceURL:(NSURL*)url
                 withKey:(NSString*)key
      withCertificateUrl:(NSString*)certificateUrl
          withLicenseUrl:(NSString*)licenseUrl
             withHeaders:(NSDictionary*)headers
               withCache:(BOOL)useCache
                cacheKey:(NSString*)cacheKey
            cacheManager:(CacheManager*)cacheManager
     overriddenDuration:(int)overriddenDuration
        videoExtension:(NSString*)videoExtension {

    [self setDataSourceURL:url
                   withKey:key
        withCertificateUrl:certificateUrl
            withLicenseUrl:licenseUrl
               withHeaders:headers
                 withCache:useCache
                  cacheKey:cacheKey
              cacheManager:cacheManager
       overriddenDuration:overriddenDuration
          videoExtension:videoExtension
                 isYouTube:NO
            youTubeAudioUrl:nil
     youTubeFallbackMuxedUrl:nil
              youTubeIsHls:NO
             youTubeIsMuxed:NO];
}

#pragma mark - ✅ NEW: YouTube-aware setDataSourceURL (ONLY changes behavior when isYouTube == true)

- (void)setDataSourceURL:(NSURL*)url
                 withKey:(NSString*)key
      withCertificateUrl:(NSString*)certificateUrl
          withLicenseUrl:(NSString*)licenseUrl
             withHeaders:(NSDictionary*)headers
               withCache:(BOOL)useCache
                cacheKey:(NSString*)cacheKey
            cacheManager:(CacheManager*)cacheManager
     overriddenDuration:(int)overriddenDuration
        videoExtension:(NSString*)videoExtension
              isYouTube:(BOOL)isYouTube
         youTubeAudioUrl:(NSString*)youTubeAudioUrl
  youTubeFallbackMuxedUrl:(NSString*)youTubeFallbackMuxedUrl
           youTubeIsHls:(BOOL)youTubeIsHls
          youTubeIsMuxed:(BOOL)youTubeIsMuxed {

    _overriddenDuration = 0;
    if (headers == [NSNull null] || headers == NULL){
        headers = @{};
    }

    if (!isYouTube) {
        AVPlayerItem* item;
        if (useCache){
            if (cacheKey == [NSNull null]){
                cacheKey = nil;
            }
            if (videoExtension == [NSNull null]){
                videoExtension = nil;
            }

            item = [cacheManager getCachingPlayerItemForNormalPlayback:url cacheKey:cacheKey videoExtension: videoExtension headers:headers];
        } else {
            AVURLAsset* asset = [AVURLAsset URLAssetWithURL:url options:@{@"AVURLAssetHTTPHeaderFieldsKey" : headers}];
            if (certificateUrl && certificateUrl != [NSNull null] && [certificateUrl length] > 0) {
                NSURL * certificateNSURL = [[NSURL alloc] initWithString: certificateUrl];
                NSURL * licenseNSURL = [[NSURL alloc] initWithString: licenseUrl];
                _loaderDelegate = [[BetterPlayerEzDrmAssetsLoaderDelegate alloc] init:certificateNSURL withLicenseURL:licenseNSURL];
                dispatch_queue_attr_t qos = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, -1);
                dispatch_queue_t streamQueue = dispatch_queue_create("streamQueue", qos);
                [asset.resourceLoader setDelegate:_loaderDelegate queue:streamQueue];
            }
            item = [AVPlayerItem playerItemWithAsset:asset];
        }

        if (@available(iOS 10.0, *) && overriddenDuration > 0) {
            _overriddenDuration = overriddenDuration;
        }
        return [self setDataSourcePlayerItem:item withKey:key];
    }

    // -------------------- ✅ YouTube path starts here --------------------
    BOOL hasAudio = (youTubeAudioUrl != nil && youTubeAudioUrl != (id)[NSNull null] && youTubeAudioUrl.length > 0);
    BOOL hasFallback = (youTubeFallbackMuxedUrl != nil && youTubeFallbackMuxedUrl != (id)[NSNull null] && youTubeFallbackMuxedUrl.length > 0);

    // 1) HLS -> direct
    if (youTubeIsHls) {
        AVURLAsset* asset = [self _bpUrlAssetWithURL:url headers:headers];
        AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:asset];
        if (@available(iOS 10.0, *) && overriddenDuration > 0) _overriddenDuration = overriddenDuration;
        return [self setDataSourcePlayerItem:item withKey:key];
    }

    // 2) Muxed -> direct
    if (youTubeIsMuxed) {
        AVURLAsset* asset = [self _bpUrlAssetWithURL:url headers:headers];
        AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:asset];
        if (@available(iOS 10.0, *) && overriddenDuration > 0) _overriddenDuration = overriddenDuration;
        return [self setDataSourcePlayerItem:item withKey:key];
    }

    // 3) Separate A/V + fallback -> start fallback immediately then merge and switch
    if (hasAudio && hasFallback) {
        NSURL* fallbackURL = [NSURL URLWithString:youTubeFallbackMuxedUrl];
        AVURLAsset* fallbackAsset = [self _bpUrlAssetWithURL:fallbackURL headers:headers];
        AVPlayerItem* fallbackItem = [AVPlayerItem playerItemWithAsset:fallbackAsset];

        if (@available(iOS 10.0, *) && overriddenDuration > 0) {
            _overriddenDuration = overriddenDuration;
        }

        // Start fallback now
        [self setDataSourcePlayerItem:fallbackItem withKey:key];

        // Build merged (video + m4a audio) and then switch at same position
        NSURL* audioURL = [NSURL URLWithString:youTubeAudioUrl];
        __weak BetterPlayer* weakSelf = self;
        [self _bpBuildMergedItemWithVideoURL:url audioURL:audioURL headers:headers completion:^(AVPlayerItem *item, NSError *error) {
            BetterPlayer* strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_disposed) return;

            if (error || !item) {
                // Stay on fallback (do not break existing playback)
                return;
            }

            CMTime current = strongSelf->_player.currentTime;

            // ✅ FIX: switch using BetterPlayer pipeline + force re-init
            [strongSelf _bpSwitchToMergedItemUsingBetterPlayerPipeline:item withKey:key seekTo:current];

            if (strongSelf->_eventSink) {
                strongSelf->_eventSink(@{@"event" : @"youtubeHdReady", @"key" : strongSelf->_key ?: @""});
            }
        }];

        return;
    }

    // 4) Separate A/V without fallback -> merge directly
    if (hasAudio) {
        NSURL* audioURL = [NSURL URLWithString:youTubeAudioUrl];
        __weak BetterPlayer* weakSelf = self;
        [self _bpBuildMergedItemWithVideoURL:url audioURL:audioURL headers:headers completion:^(AVPlayerItem *item, NSError *error) {
            BetterPlayer* strongSelf = weakSelf;
            if (!strongSelf || strongSelf->_disposed) return;

            if (error || !item) {
                if (strongSelf->_eventSink != nil) {
                    strongSelf->_eventSink([FlutterError errorWithCode:@"VideoError"
                                                             message:[@"Failed to load YouTube merged A/V: "
                                                                      stringByAppendingString:(error.localizedDescription ?: @"unknown")]
                                                             details:nil]);
                }
                return;
            }

            if (@available(iOS 10.0, *) && overriddenDuration > 0) {
                strongSelf->_overriddenDuration = overriddenDuration;
            }
            [strongSelf setDataSourcePlayerItem:item withKey:key];
        }];
        return;
    }

    // 5) Fallback only
    if (hasFallback) {
        NSURL* fallbackURL = [NSURL URLWithString:youTubeFallbackMuxedUrl];
        AVURLAsset* asset = [self _bpUrlAssetWithURL:fallbackURL headers:headers];
        AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:asset];
        if (@available(iOS 10.0, *) && overriddenDuration > 0) _overriddenDuration = overriddenDuration;
        return [self setDataSourcePlayerItem:item withKey:key];
    }

    // Default YouTube: play main URL directly
    AVURLAsset* asset = [self _bpUrlAssetWithURL:url headers:headers];
    AVPlayerItem* item = [AVPlayerItem playerItemWithAsset:asset];
    if (@available(iOS 10.0, *) && overriddenDuration > 0) _overriddenDuration = overriddenDuration;
    return [self setDataSourcePlayerItem:item withKey:key];
}

#pragma mark - Existing setDataSourcePlayerItem (unchanged)

- (void)setDataSourcePlayerItem:(AVPlayerItem*)item withKey:(NSString*)key{
    _key = key;
    _stalledCount = 0;
    _isStalledCheckStarted = false;
    _playerRate = 1;
    [_player replaceCurrentItemWithPlayerItem:item];

    AVAsset* asset = [item asset];
    void (^assetCompletionHandler)(void) = ^{
        if ([asset statusOfValueForKey:@"tracks" error:nil] == AVKeyValueStatusLoaded) {
            NSArray* tracks = [asset tracksWithMediaType:AVMediaTypeVideo];
            if ([tracks count] > 0) {
                AVAssetTrack* videoTrack = tracks[0];
                void (^trackCompletionHandler)(void) = ^{
                    if (self->_disposed) return;
                    if ([videoTrack statusOfValueForKey:@"preferredTransform" error:nil] == AVKeyValueStatusLoaded) {
                        self->_preferredTransform = [self fixTransform:videoTrack];
                        AVMutableVideoComposition* videoComposition =
                        [self getVideoCompositionWithTransform:self->_preferredTransform
                                                     withAsset:asset
                                                withVideoTrack:videoTrack];
                        item.videoComposition = videoComposition;
                    }
                };
                [videoTrack loadValuesAsynchronouslyForKeys:@[ @"preferredTransform" ]
                                          completionHandler:trackCompletionHandler];
            }
        }
    };

    [asset loadValuesAsynchronouslyForKeys:@[ @"tracks" ] completionHandler:assetCompletionHandler];
    [self addObservers:item];
}


-(void)handleStalled {
    if (_isStalledCheckStarted){
        return;
    }
   _isStalledCheckStarted = true;
    [self startStalledCheck];
}

-(void)startStalledCheck{
    if (_player.currentItem.playbackLikelyToKeepUp ||
        [self availableDuration] - CMTimeGetSeconds(_player.currentItem.currentTime) > 10.0) {
        [self play];
    } else {
        _stalledCount++;
        if (_stalledCount > 60){
            if (_eventSink != nil) {
                _eventSink([FlutterError
                        errorWithCode:@"VideoError"
                        message:@"Failed to load video: playback stalled"
                        details:nil]);
            }
            return;
        }
        [self performSelector:@selector(startStalledCheck) withObject:nil afterDelay:1];
    }
}

- (NSTimeInterval) availableDuration
{
    NSArray *loadedTimeRanges = [[_player currentItem] loadedTimeRanges];
    if (loadedTimeRanges.count > 0){
        CMTimeRange timeRange = [[loadedTimeRanges objectAtIndex:0] CMTimeRangeValue];
        Float64 startSeconds = CMTimeGetSeconds(timeRange.start);
        Float64 durationSeconds = CMTimeGetSeconds(timeRange.duration);
        NSTimeInterval result = startSeconds + durationSeconds;
        return result;
    } else {
        return 0;
    }
}

- (void)observeValueForKeyPath:(NSString*)path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {

    if ([path isEqualToString:@"rate"]) {
        if (@available(iOS 10.0, *)) {
            if (_pipController.pictureInPictureActive == true){
                if (_lastAvPlayerTimeControlStatus != [NSNull null] && _lastAvPlayerTimeControlStatus == _player.timeControlStatus){
                    return;
                }

                if (_player.timeControlStatus == AVPlayerTimeControlStatusPaused){
                    _lastAvPlayerTimeControlStatus = _player.timeControlStatus;
                    if (_eventSink != nil) {
                      _eventSink(@{@"event" : @"pause"});
                    }
                    return;

                }
                if (_player.timeControlStatus == AVPlayerTimeControlStatusPlaying){
                    _lastAvPlayerTimeControlStatus = _player.timeControlStatus;
                    if (_eventSink != nil) {
                      _eventSink(@{@"event" : @"play"});
                    }
                }
            }
        }

        if (_player.rate == 0 &&
            CMTIME_COMPARE_INLINE(_player.currentItem.currentTime, >, kCMTimeZero) &&
            CMTIME_COMPARE_INLINE(_player.currentItem.currentTime, <, _player.currentItem.duration) &&
            _isPlaying) {
            [self handleStalled];
        }
    }

    if (context == timeRangeContext) {
        if (_eventSink != nil) {
            NSMutableArray<NSArray<NSNumber*>*>* values = [[NSMutableArray alloc] init];
            for (NSValue* rangeValue in [object loadedTimeRanges]) {
                CMTimeRange range = [rangeValue CMTimeRangeValue];
                int64_t start = [BetterPlayerTimeUtils FLTCMTimeToMillis:(range.start)];
                int64_t end = start + [BetterPlayerTimeUtils FLTCMTimeToMillis:(range.duration)];
                if (!CMTIME_IS_INVALID(_player.currentItem.forwardPlaybackEndTime)) {
                    int64_t endTime = [BetterPlayerTimeUtils FLTCMTimeToMillis:(_player.currentItem.forwardPlaybackEndTime)];
                    if (end > endTime){
                        end = endTime;
                    }
                }

                [values addObject:@[ @(start), @(end) ]];
            }
            _eventSink(@{@"event" : @"bufferingUpdate", @"values" : values, @"key" : _key});
        }
    }
    else if (context == presentationSizeContext){
        [self onReadyToPlay];
    }

    else if (context == statusContext) {
        AVPlayerItem* item = (AVPlayerItem*)object;
        switch (item.status) {
            case AVPlayerItemStatusFailed:
                NSLog(@"Failed to load video:");
                NSLog(item.error.debugDescription);

                if (_eventSink != nil) {
                    _eventSink([FlutterError
                                errorWithCode:@"VideoError"
                                message:[@"Failed to load video: "
                                         stringByAppendingString:[item.error localizedDescription]]
                                details:nil]);
                }
                break;
            case AVPlayerItemStatusUnknown:
                break;
            case AVPlayerItemStatusReadyToPlay:
                [self onReadyToPlay];
                break;
        }
    } else if (context == playbackLikelyToKeepUpContext) {
        if ([[_player currentItem] isPlaybackLikelyToKeepUp]) {
            [self updatePlayingState];
            if (_eventSink != nil) {
                _eventSink(@{@"event" : @"bufferingEnd", @"key" : _key});
            }
        }
    } else if (context == playbackBufferEmptyContext) {
        if (_eventSink != nil) {
            _eventSink(@{@"event" : @"bufferingStart", @"key" : _key});
        }
    } else if (context == playbackBufferFullContext) {
        if (_eventSink != nil) {
            _eventSink(@{@"event" : @"bufferingEnd", @"key" : _key});
        }
    }
}

- (void)updatePlayingState {
    if (!_isInitialized || !_key) {
        return;
    }
    if (!self._observersAdded){
        [self addObservers:[_player currentItem]];
    }

    if (_isPlaying) {
        if (@available(iOS 10.0, *)) {
            [_player playImmediatelyAtRate:1.0];
            _player.rate = _playerRate;
        } else {
            [_player play];
            _player.rate = _playerRate;
        }
    } else {
        [_player pause];
    }
}

- (void)onReadyToPlay {
    if (_eventSink && !_isInitialized && _key) {
        if (!_player.currentItem) {
            return;
        }
        if (_player.status != AVPlayerStatusReadyToPlay) {
            return;
        }

        CGSize size = [_player currentItem].presentationSize;
        CGFloat width = size.width;
        CGFloat height = size.height;

        AVAsset *asset = _player.currentItem.asset;
        bool onlyAudio =  [[asset tracksWithMediaType:AVMediaTypeVideo] count] == 0;

        if (!onlyAudio && height == CGSizeZero.height && width == CGSizeZero.width) {
            return;
        }
        const BOOL isLive = CMTIME_IS_INDEFINITE([_player currentItem].duration);
        if (isLive == false && [self duration] == 0) {
            return;
        }

        AVPlayerItemTrack *track = [self.player currentItem].tracks.firstObject;
        CGSize naturalSize = track.assetTrack.naturalSize;
        CGAffineTransform prefTrans = track.assetTrack.preferredTransform;
        CGSize realSize = CGSizeApplyAffineTransform(naturalSize, prefTrans);

        int64_t duration = [BetterPlayerTimeUtils FLTCMTimeToMillis:(_player.currentItem.asset.duration)];
        if (_overriddenDuration > 0 && duration > _overriddenDuration){
            _player.currentItem.forwardPlaybackEndTime = CMTimeMake(_overriddenDuration/1000, 1);
        }

        _isInitialized = true;
        [self updatePlayingState];
        _eventSink(@{
            @"event" : @"initialized",
            @"duration" : @([self duration]),
            @"width" : @(fabs(realSize.width) ? : width),
            @"height" : @(fabs(realSize.height) ? : height),
            @"key" : _key
        });
    }
}

- (void)play {
    _stalledCount = 0;
    _isStalledCheckStarted = false;
    _isPlaying = true;
    [self updatePlayingState];
}

- (void)pause {
    _isPlaying = false;
    [self updatePlayingState];
}

- (int64_t)position {
    return [BetterPlayerTimeUtils FLTCMTimeToMillis:([_player currentTime])];
}

- (int64_t)absolutePosition {
    return [BetterPlayerTimeUtils FLTNSTimeIntervalToMillis:([[[_player currentItem] currentDate] timeIntervalSince1970])];
}

- (int64_t)duration {
    CMTime time;
    if (@available(iOS 13, *)) {
        time =  [[_player currentItem] duration];
    } else {
        time =  [[[_player currentItem] asset] duration];
    }
    if (!CMTIME_IS_INVALID(_player.currentItem.forwardPlaybackEndTime)) {
        time = [[_player currentItem] forwardPlaybackEndTime];
    }

    return [BetterPlayerTimeUtils FLTCMTimeToMillis:(time)];
}

- (void)seekTo:(int)location {
    bool wasPlaying = _isPlaying;
    if (wasPlaying){
        [_player pause];
    }

    [_player seekToTime:CMTimeMake(location, 1000)
        toleranceBefore:kCMTimeZero
         toleranceAfter:kCMTimeZero
      completionHandler:^(BOOL finished){
        if (wasPlaying){
            _player.rate = _playerRate;
        }
    }];
}

- (void)setIsLooping:(bool)isLooping {
    _isLooping = isLooping;
}

- (void)setVolume:(double)volume {
    _player.volume = (float)((volume < 0.0) ? 0.0 : ((volume > 1.0) ? 1.0 : volume));
}

- (void)setSpeed:(double)speed result:(FlutterResult)result {
    if (speed == 1.0 || speed == 0.0) {
        _playerRate = 1;
        result(nil);
    } else if (speed < 0 || speed > 2.0) {
        result([FlutterError errorWithCode:@"unsupported_speed"
                                   message:@"Speed must be >= 0.0 and <= 2.0"
                                   details:nil]);
    } else if ((speed > 1.0 && _player.currentItem.canPlayFastForward) ||
               (speed < 1.0 && _player.currentItem.canPlaySlowForward)) {
        _playerRate = speed;
        result(nil);
    } else {
        if (speed > 1.0) {
            result([FlutterError errorWithCode:@"unsupported_fast_forward"
                                       message:@"This video cannot be played fast forward"
                                       details:nil]);
        } else {
            result([FlutterError errorWithCode:@"unsupported_slow_forward"
                                       message:@"This video cannot be played slow forward"
                                       details:nil]);
        }
    }

    if (_isPlaying){
        _player.rate = _playerRate;
    }
}

- (void)setTrackParameters:(int) width: (int) height: (int)bitrate {
    _player.currentItem.preferredPeakBitRate = bitrate;
    if (@available(iOS 11.0, *)) {
        if (width == 0 && height == 0){
            _player.currentItem.preferredMaximumResolution = CGSizeZero;
        } else {
            _player.currentItem.preferredMaximumResolution = CGSizeMake(width, height);
        }
    }
}

- (void)setPictureInPicture:(BOOL)pictureInPicture
{
    self._pictureInPicture = pictureInPicture;
    if (@available(iOS 9.0, *)) {
        if (_pipController && self._pictureInPicture && ![_pipController isPictureInPictureActive]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_pipController startPictureInPicture];
            });
        } else if (_pipController && !self._pictureInPicture && [_pipController isPictureInPictureActive]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_pipController stopPictureInPicture];
            });
        } else {
            // Fallback on earlier versions
        } }
}

#if TARGET_OS_IOS
- (void)setRestoreUserInterfaceForPIPStopCompletionHandler:(BOOL)restore
{
    if (_restoreUserInterfaceForPIPStopCompletionHandler != NULL) {
        _restoreUserInterfaceForPIPStopCompletionHandler(restore);
        _restoreUserInterfaceForPIPStopCompletionHandler = NULL;
    }
}

- (void)setupPipController {
    if (@available(iOS 9.0, *)) {
        @try {
            [[AVAudioSession sharedInstance] setActive: YES error: nil];
            [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];

            if (!_pipController && self._playerLayer &&
                [AVPictureInPictureController isPictureInPictureSupported]) {
                _pipController = [[AVPictureInPictureController alloc]
                                 initWithPlayerLayer:self._playerLayer];
                _pipController.delegate = self;

                if (@available(iOS 14.2, *)) {
                    _pipController.canStartPictureInPictureAutomaticallyFromInline = YES;
                }

                if (@available(iOS 14.0, *)) {
                    _pipController.requiresLinearPlayback = NO;
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"Error setting up PiP controller: %@", exception.reason);
        }
    }
}

- (void) enablePictureInPicture: (CGRect) frame {
    @try {
        [self disablePictureInPicture];

        BetterPlayerView* originalPlayerView = (BetterPlayerView*)self.view;
        originalPlayerView.playerLayer.hidden = YES;

        if (@available(iOS 9.0, *)) {
            [self usePlayerLayer:frame];
        }
    } @catch (NSException *exception) {
        NSLog(@"Error enabling PiP: %@", exception.reason);
        if (_eventSink != nil) {
            _eventSink(@{@"event" : @"pipError", @"error": exception.reason});
        }
    }
}

- (void)usePlayerLayer: (CGRect) frame {
    if (_player) {
        @try {
            self._playerLayer = [AVPlayerLayer playerLayerWithPlayer:_player];
            UIViewController* vc = [[[UIApplication sharedApplication] keyWindow] rootViewController];

            CGRect adjustedFrame = [self adjustFrameForCurrentOrientation:frame];
            self._playerLayer.frame = adjustedFrame;
            self._playerLayer.needsDisplayOnBoundsChange = YES;
            self._playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;

            [vc.view.layer addSublayer:self._playerLayer];
            vc.view.layer.needsDisplayOnBoundsChange = YES;

            self._playerLayer.opacity = 0.0;

            if (@available(iOS 9.0, *)) {
                _pipController = NULL;
            }
            [self setupPipController];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [self setPictureInPicture:true];
            });
        } @catch (NSException *exception) {
            NSLog(@"Error setting up player layer: %@", exception.reason);
        }
    }
}

- (CGRect)adjustFrameForCurrentOrientation:(CGRect)originalFrame {
    UIViewController* vc = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    CGRect bounds = vc.view.bounds;

    if (originalFrame.size.width >= bounds.size.width * 0.8 ||
        originalFrame.size.height >= bounds.size.height * 0.8) {
        return bounds;
    }

    return originalFrame;
}

- (void)disablePictureInPicture
{
    [self setPictureInPicture:false];
    if (self._playerLayer){
        [self._playerLayer removeFromSuperlayer];
        self._playerLayer = nil;
        if (_eventSink != nil) {
            _eventSink(@{@"event" : @"pipStop"});
        }
    }
}

#endif

#if TARGET_OS_IOS
- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(9.0)) {
    BetterPlayerView* originalPlayerView = (BetterPlayerView*)self.view;
    originalPlayerView.playerLayer.hidden = NO;

    [self disablePictureInPicture];
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController API_AVAILABLE(ios(9.0)) {
    BetterPlayerView* originalPlayerView = (BetterPlayerView*)self.view;
    originalPlayerView.playerLayer.hidden = YES;

    [[UIApplication sharedApplication] performSelector:@selector(suspend)];

    if (_eventSink != nil) {
        _eventSink(@{@"event" : @"pipStart"});
    }
}

- (void)pictureInPictureControllerWillStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController  API_AVAILABLE(ios(9.0)){

}

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController {

}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
           failedToStartPictureInPictureWithError:(NSError *)error API_AVAILABLE(ios(9.0)) {
    NSLog(@"PiP failed to start: %@", error.localizedDescription);
    if (_eventSink != nil) {
        _eventSink(@{@"event" : @"pipError", @"error": error.localizedDescription});
    }
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
restoreUserInterfaceForPictureInPictureStopWithCompletionHandler:(void (^)(BOOL))completionHandler API_AVAILABLE(ios(9.0)) {
    BetterPlayerView* originalPlayerView = (BetterPlayerView*)self.view;
    originalPlayerView.playerLayer.hidden = NO;

    [self setRestoreUserInterfaceForPIPStopCompletionHandler:YES];
    if (completionHandler) {
        completionHandler(YES);
    }
}

- (void) setAudioTrack:(NSString*) name index:(int) index{
    AVMediaSelectionGroup *audioSelectionGroup = [[[_player currentItem] asset] mediaSelectionGroupForMediaCharacteristic: AVMediaCharacteristicAudible];
    NSArray* options = audioSelectionGroup.options;

    for (int audioTrackIndex = 0; audioTrackIndex < [options count]; audioTrackIndex++) {
        AVMediaSelectionOption* option = [options objectAtIndex:audioTrackIndex];
        NSArray *metaDatas = [AVMetadataItem metadataItemsFromArray:option.commonMetadata withKey:@"title" keySpace:@"comn"];
        if (metaDatas.count > 0) {
            NSString *title = ((AVMetadataItem*)[metaDatas objectAtIndex:0]).stringValue;
            if ([name compare:title] == NSOrderedSame && audioTrackIndex == index ){
                [[_player currentItem] selectMediaOption:option inMediaSelectionGroup: audioSelectionGroup];
            }
        }
    }
}

- (void)setMixWithOthers:(bool)mixWithOthers {
  if (mixWithOthers) {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:nil];
  } else {
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
  }
}
#endif

- (FlutterError* _Nullable)onCancelWithArguments:(id _Nullable)arguments {
    _eventSink = nil;
    return nil;
}

- (FlutterError* _Nullable)onListenWithArguments:(id _Nullable)arguments
                                       eventSink:(nonnull FlutterEventSink)events {
    _eventSink = events;
    [self onReadyToPlay];
    return nil;
}

- (void)disposeSansEventChannel {
    @try{
        [self clear];
    }
    @catch(NSException *exception) {
        NSLog(exception.debugDescription);
    }
}

- (void)dispose {
    [self pause];
    [self disposeSansEventChannel];
    [_eventChannel setStreamHandler:nil];
    [self disablePictureInPicture];
    [self setPictureInPicture:false];
    _disposed = true;
}

@end
