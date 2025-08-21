/// Video quality options for YouTube videos
enum BetterPlayerYouTubeQuality {
  /// Low quality (144p, 240p)
  low,

  /// Medium quality (360p, 480p)
  medium,

  /// High quality (720p, 1080p+)
  high,

  /// Automatic quality selection (highest available)
  auto,
}

/// Information about available video quality
class BetterPlayerYouTubeQualityInfo {
  /// The quality level
  final BetterPlayerYouTubeQuality quality;

  /// Resolution string (e.g., "1920x1080")
  final String resolution;

  /// File size in bytes
  final int size;

  /// Constructor
  const BetterPlayerYouTubeQualityInfo({
    required this.quality,
    required this.resolution,
    required this.size,
  });

  /// Get formatted file size
  String get formattedSize {
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// Get quality display name
  String get displayName {
    switch (quality) {
      case BetterPlayerYouTubeQuality.low:
        return 'Low Quality';
      case BetterPlayerYouTubeQuality.medium:
        return 'Medium Quality';
      case BetterPlayerYouTubeQuality.high:
        return 'High Quality';
      case BetterPlayerYouTubeQuality.auto:
        return 'Auto Quality';
    }
  }

  @override
  String toString() => '$displayName ($resolution) - $formattedSize';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BetterPlayerYouTubeQualityInfo &&
          runtimeType == other.runtimeType &&
          quality == other.quality &&
          resolution == other.resolution;

  @override
  int get hashCode => quality.hashCode ^ resolution.hashCode;
}

/// YouTube video information
class BetterPlayerYouTubeVideoInfo {
  /// Video ID
  final String id;

  /// Video title
  final String title;

  /// Video author/channel name
  final String author;

  /// Video duration
  final Duration? duration;

  /// Thumbnail URL
  final String? thumbnailUrl;

  /// Video description
  final String? description;

  /// View count
  final int? viewCount;

  /// Upload date
  final DateTime? uploadDate;

  /// Constructor
  const BetterPlayerYouTubeVideoInfo({
    required this.id,
    required this.title,
    required this.author,
    this.duration,
    this.thumbnailUrl,
    this.description,
    this.viewCount,
    this.uploadDate,
  });

  /// Get formatted duration
  String get formattedDuration {
    if (duration == null) return 'Unknown';

    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    final seconds = duration!.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  /// Get formatted view count
  String get formattedViewCount {
    if (viewCount == null) return 'Unknown views';

    if (viewCount! < 1000) {
      return '$viewCount views';
    } else if (viewCount! < 1000000) {
      return '${(viewCount! / 1000).toStringAsFixed(1)}K views';
    } else if (viewCount! < 1000000000) {
      return '${(viewCount! / 1000000).toStringAsFixed(1)}M views';
    } else {
      return '${(viewCount! / 1000000000).toStringAsFixed(1)}B views';
    }
  }

  @override
  String toString() =>
      'YouTubeVideoInfo(id: $id, title: $title, author: $author)';
}

/// Configuration for YouTube extraction
class BetterPlayerYouTubeConfiguration {
  /// Default video quality to use
  final BetterPlayerYouTubeQuality defaultQuality;

  /// Whether to use caching
  final bool useCache;

  /// Cache duration
  final Duration cacheDuration;

  /// Maximum cache size in bytes
  final int maxCacheSize;

  /// User agent to use for requests
  final String userAgent;

  /// Whether to prefer audio-only streams when available
  final bool preferAudioOnly;

  /// Timeout for extraction operations
  final Duration extractionTimeout;

  /// Constructor
  const BetterPlayerYouTubeConfiguration({
    this.defaultQuality = BetterPlayerYouTubeQuality.medium,
    this.useCache = true,
    this.cacheDuration = const Duration(hours: 1),
    this.maxCacheSize = 100 * 1024 * 1024, // 100MB
    this.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    this.preferAudioOnly = false,
    this.extractionTimeout = const Duration(seconds: 30),
  });

  /// Create a copy with updated values
  BetterPlayerYouTubeConfiguration copyWith({
    BetterPlayerYouTubeQuality? defaultQuality,
    bool? useCache,
    Duration? cacheDuration,
    int? maxCacheSize,
    String? userAgent,
    bool? preferAudioOnly,
    Duration? extractionTimeout,
  }) {
    return BetterPlayerYouTubeConfiguration(
      defaultQuality: defaultQuality ?? this.defaultQuality,
      useCache: useCache ?? this.useCache,
      cacheDuration: cacheDuration ?? this.cacheDuration,
      maxCacheSize: maxCacheSize ?? this.maxCacheSize,
      userAgent: userAgent ?? this.userAgent,
      preferAudioOnly: preferAudioOnly ?? this.preferAudioOnly,
      extractionTimeout: extractionTimeout ?? this.extractionTimeout,
    );
  }
}

/// YouTube extraction result
class BetterPlayerYouTubeExtractionResult {
  /// Direct stream URL
  final String streamUrl;

  /// Video information
  final BetterPlayerYouTubeVideoInfo videoInfo;

  /// Selected quality
  final BetterPlayerYouTubeQuality selectedQuality;

  /// Available qualities
  final List<BetterPlayerYouTubeQualityInfo> availableQualities;

  /// Extraction timestamp
  final DateTime extractedAt;

  /// Whether result was from cache
  final bool fromCache;

  /// Constructor
  const BetterPlayerYouTubeExtractionResult({
    required this.streamUrl,
    required this.videoInfo,
    required this.selectedQuality,
    required this.availableQualities,
    required this.extractedAt,
    this.fromCache = false,
  });

  /// Check if extraction result is still valid
  bool isValid(Duration cacheDuration) {
    return DateTime.now().difference(extractedAt) < cacheDuration;
  }

  @override
  String toString() =>
      'YouTubeExtractionResult(videoId: ${videoInfo.id}, quality: $selectedQuality, fromCache: $fromCache)';
}
