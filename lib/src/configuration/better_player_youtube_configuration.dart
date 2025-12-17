/// Configuration class for YouTube playback in BetterPlayer.
///
/// This configuration enables a special playback flow for YouTube videos:
/// 1. Start with a muxed (low quality) stream for fast initial playback
/// 2. Prepare HD video-only + audio-only streams in background
/// 3. Seamlessly switch to HD once ready
///
/// Example usage:
/// ```dart
/// final youtubeConfig = BetterPlayerYouTubeConfiguration(
///   videoOnlyUrl: 'https://...', // HD video-only stream
///   audioOnlyUrl: 'https://...', // Audio-only stream
///   fallbackMuxedUrl: 'https://...', // 360p muxed stream for fast start
///   isHls: false,
///   isMuxed: false,
/// );
///
/// final dataSource = BetterPlayerDataSource(
///   BetterPlayerDataSourceType.network,
///   videoOnlyUrl, // Primary URL (video-only for HD)
///   youTubeConfiguration: youtubeConfig,
/// );
/// ```
class BetterPlayerYouTubeConfiguration {
  /// URL for the video-only stream (typically HD quality)
  /// This is used together with [audioOnlyUrl] to create a merged HD stream
  final String? videoOnlyUrl;

  /// URL for the audio-only stream
  /// This is merged with [videoOnlyUrl] to create the HD playback
  final String? audioOnlyUrl;

  /// Fallback muxed URL (typically lower quality like 360p)
  /// Used for immediate playback while HD streams are being prepared
  final String? fallbackMuxedUrl;

  /// Whether the stream is HLS format
  /// If true, the stream will be played directly without merging
  final bool isHls;

  /// Whether the stream is already muxed (video + audio combined)
  /// If true, the stream will be played directly without merging
  final bool isMuxed;

  /// Whether to enable the fast-start strategy
  /// When true and [fallbackMuxedUrl] is available:
  /// 1. Start playback immediately with fallback muxed stream
  /// 2. Prepare HD merged stream in background
  /// 3. Switch to HD once ready
  /// Default: true
  final bool enableFastStart;

  /// Custom User-Agent header for YouTube requests
  /// Different YouTube clients may require different User-Agent values
  final String? customUserAgent;

  /// Additional headers for YouTube requests
  final Map<String, String>? headers;

  const BetterPlayerYouTubeConfiguration({
    this.videoOnlyUrl,
    this.audioOnlyUrl,
    this.fallbackMuxedUrl,
    this.isHls = false,
    this.isMuxed = false,
    this.enableFastStart = true,
    this.customUserAgent,
    this.headers,
  });

  /// Check if this configuration is valid for YouTube playback
  bool get isValid {
    // Valid if HLS or muxed (single stream)
    if (isHls || isMuxed) return true;

    // Valid if both video-only and audio-only are provided
    if (videoOnlyUrl != null &&
        videoOnlyUrl!.isNotEmpty &&
        audioOnlyUrl != null &&
        audioOnlyUrl!.isNotEmpty) {
      return true;
    }

    // Valid if fallback muxed is available
    if (fallbackMuxedUrl != null && fallbackMuxedUrl!.isNotEmpty) {
      return true;
    }

    return false;
  }

  /// Check if separate video and audio streams are available
  bool get hasSeparateStreams {
    return videoOnlyUrl != null &&
        videoOnlyUrl!.isNotEmpty &&
        audioOnlyUrl != null &&
        audioOnlyUrl!.isNotEmpty;
  }

  /// Check if fallback muxed stream is available
  bool get hasFallbackMuxed {
    return fallbackMuxedUrl != null && fallbackMuxedUrl!.isNotEmpty;
  }

  /// Check if fast-start strategy should be used
  bool get shouldUseFastStart {
    return enableFastStart && hasSeparateStreams && hasFallbackMuxed;
  }

  /// Detect YouTube client type from URL parameters
  String detectYouTubeClient(String url) {
    if (url.contains('c=ANDROID_VR')) return 'ANDROID_VR';
    if (url.contains('c=TVHTML5')) return 'TV';
    if (url.contains('c=ANDROID')) return 'ANDROID';
    return 'UNKNOWN';
  }

  /// Get appropriate User-Agent for detected YouTube client
  String getUserAgentForClient(String client) {
    if (customUserAgent != null && customUserAgent!.isNotEmpty) {
      return customUserAgent!;
    }

    switch (client) {
      case 'ANDROID_VR':
        return 'com.google.android.apps.youtube.vr.oculus/1.56.21 (Linux; U; Android 12; Quest 3) gzip';
      case 'TV':
        return 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version,gzip(gfe)';
      default:
        return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.18 Safari/537.36';
    }
  }

  /// Create a copy with modified parameters
  BetterPlayerYouTubeConfiguration copyWith({
    String? videoOnlyUrl,
    String? audioOnlyUrl,
    String? fallbackMuxedUrl,
    bool? isHls,
    bool? isMuxed,
    bool? enableFastStart,
    String? customUserAgent,
    Map<String, String>? headers,
  }) {
    return BetterPlayerYouTubeConfiguration(
      videoOnlyUrl: videoOnlyUrl ?? this.videoOnlyUrl,
      audioOnlyUrl: audioOnlyUrl ?? this.audioOnlyUrl,
      fallbackMuxedUrl: fallbackMuxedUrl ?? this.fallbackMuxedUrl,
      isHls: isHls ?? this.isHls,
      isMuxed: isMuxed ?? this.isMuxed,
      enableFastStart: enableFastStart ?? this.enableFastStart,
      customUserAgent: customUserAgent ?? this.customUserAgent,
      headers: headers ?? this.headers,
    );
  }

  @override
  String toString() {
    return 'BetterPlayerYouTubeConfiguration('
        'videoOnlyUrl: $videoOnlyUrl, '
        'audioOnlyUrl: $audioOnlyUrl, '
        'fallbackMuxedUrl: $fallbackMuxedUrl, '
        'isHls: $isHls, '
        'isMuxed: $isMuxed, '
        'enableFastStart: $enableFastStart)';
  }
}
