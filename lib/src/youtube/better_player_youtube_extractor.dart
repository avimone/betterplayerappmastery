import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../configuration/better_player_data_source.dart';
import '../configuration/better_player_data_source_type.dart';
import '../configuration/better_player_cache_configuration.dart';
import '../configuration/better_player_notification_configuration.dart';
import 'better_player_youtube_types.dart';

class BetterPlayerYouTubeExtractor {
  static final yt.YoutubeExplode _youtubeExplode = yt.YoutubeExplode();
  static final Map<String, _CachedVideoInfo> _cache = {};

  /// Extract direct video URL from YouTube URL
  /// Supports various YouTube URL formats:
  /// - https://www.youtube.com/watch?v=VIDEO_ID
  /// - https://youtu.be/VIDEO_ID
  /// - https://m.youtube.com/watch?v=VIDEO_ID
  static Future<BetterPlayerDataSource> extractYouTubeDataSource(
    String youtubeUrl, {
    BetterPlayerYouTubeQuality quality = BetterPlayerYouTubeQuality.medium,
    bool useCache = true,
    Duration cacheDuration = const Duration(hours: 1),
  }) async {
    try {
      final videoId = _extractVideoId(youtubeUrl);
      if (videoId == null) {
        throw ArgumentError('Invalid YouTube URL: $youtubeUrl');
      }

      // Check cache first
      if (useCache && _cache.containsKey(videoId)) {
        final cached = _cache[videoId]!;
        if (DateTime.now().difference(cached.timestamp) < cacheDuration) {
          return cached.dataSource;
        }
        // Remove expired cache
        _cache.remove(videoId);
      }

      // Get video information
      final video = await _youtubeExplode.videos.get(videoId);
      final manifest =
          await _youtubeExplode.videos.streamsClient.getManifest(videoId);

      // Get the best video stream based on quality preference
      final videoStream = _selectBestVideoStream(manifest, quality);
      if (videoStream == null) {
        throw Exception('No suitable video stream found for quality: $quality');
      }

      // Create data source
      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        videoStream.url.toString(),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://www.youtube.com/',
        },
        // Add video metadata
        notificationConfiguration: BetterPlayerNotificationConfiguration(
          showNotification: true,
          title: video.title,
          author: video.author,
          imageUrl: video.thumbnails.highResUrl,
        ),
        overriddenDuration: video.duration,
        cacheConfiguration: BetterPlayerCacheConfiguration(
          useCache: true,
          maxCacheSize: 100 * 1024 * 1024, // 100MB
          maxCacheFileSize: 50 * 1024 * 1024, // 50MB per file
          key: 'youtube_$videoId',
        ),
      );

      // Cache the result
      if (useCache) {
        _cache[videoId] = _CachedVideoInfo(
          dataSource: dataSource,
          timestamp: DateTime.now(),
        );
      }

      return dataSource;
    } catch (e) {
      throw Exception('Failed to extract YouTube video: $e');
    }
  }

  /// Extract video ID from various YouTube URL formats
  static String? _extractVideoId(String url) {
    final regexPatterns = [
      RegExp(
          r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)'),
      RegExp(r'youtube\.com\/watch\?.*v=([^&\n?#]+)'),
    ];

    for (final regex in regexPatterns) {
      final match = regex.firstMatch(url);
      if (match != null && match.group(1) != null) {
        return match.group(1);
      }
    }
    return null;
  }

  /// Select the best video stream based on quality preference
  static yt.VideoStreamInfo? _selectBestVideoStream(
    yt.StreamManifest manifest,
    BetterPlayerYouTubeQuality quality,
  ) {
    final videoStreams = manifest.videoOnly.toList()
      ..sort((a, b) => b.videoQuality.index.compareTo(a.videoQuality.index));

    switch (quality) {
      case BetterPlayerYouTubeQuality.low:
        return videoStreams.lastWhere(
          (stream) => stream.videoQuality.index <= 2, // 240p, 360p
          orElse: () => videoStreams.last,
        );
      case BetterPlayerYouTubeQuality.medium:
        return videoStreams.firstWhere(
          (stream) =>
              stream.videoQuality.index >= 3 &&
              stream.videoQuality.index <= 5, // 480p, 720p
          orElse: () => videoStreams.first,
        );
      case BetterPlayerYouTubeQuality.high:
        return videoStreams.firstWhere(
          (stream) => stream.videoQuality.index >= 6, // 1080p+
          orElse: () => videoStreams.first,
        );
      case BetterPlayerYouTubeQuality.auto:
        // Return highest available quality
        return videoStreams.first;
    }
  }

  /// Get available qualities for a YouTube video
  static Future<List<BetterPlayerYouTubeQualityInfo>> getAvailableQualities(
      String youtubeUrl) async {
    try {
      final videoId = _extractVideoId(youtubeUrl);
      if (videoId == null) {
        throw ArgumentError('Invalid YouTube URL: $youtubeUrl');
      }

      final manifest =
          await _youtubeExplode.videos.streamsClient.getManifest(videoId);

      return manifest.videoOnly
          .map((stream) => BetterPlayerYouTubeQualityInfo(
                quality: _mapToVideoQuality(stream.videoQuality),
                resolution:
                    '${stream.videoResolution.width}x${stream.videoResolution.height}',
                size: stream.size.totalBytes,
              ))
          .toSet() // Remove duplicates
          .toList()
        ..sort((a, b) => b.quality.index.compareTo(a.quality.index));
    } catch (e) {
      throw Exception('Failed to get video qualities: $e');
    }
  }

  static BetterPlayerYouTubeQuality _mapToVideoQuality(
      yt.VideoQuality quality) {
    // Map based on quality name/index for better compatibility
    final qualityName = quality.toString().toLowerCase();

    if (qualityName.contains('144') || qualityName.contains('240')) {
      return BetterPlayerYouTubeQuality.low;
    } else if (qualityName.contains('360') || qualityName.contains('480')) {
      return BetterPlayerYouTubeQuality.medium;
    } else {
      // 720p and above
      return BetterPlayerYouTubeQuality.high;
    }
  }

  /// Clear the cache
  static void clearCache() {
    _cache.clear();
  }

  /// Close the YouTube explode client
  static void dispose() {
    _youtubeExplode.close();
    clearCache();
  }
}

class _CachedVideoInfo {
  final BetterPlayerDataSource dataSource;
  final DateTime timestamp;

  _CachedVideoInfo({
    required this.dataSource,
    required this.timestamp,
  });
}
