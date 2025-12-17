import 'package:better_player/src/configuration/better_player_buffering_configuration.dart';
import 'package:better_player/src/configuration/better_player_data_source_type.dart';
import 'package:better_player/src/configuration/better_player_drm_configuration.dart';
import 'package:better_player/src/configuration/better_player_notification_configuration.dart';
import 'package:better_player/src/configuration/better_player_video_format.dart';
import 'package:better_player/src/configuration/better_player_youtube_configuration.dart';
import 'package:better_player/src/subtitles/better_player_subtitles_source.dart';
import 'package:flutter/widgets.dart';

import 'better_player_cache_configuration.dart';

/// Representation of data source which will be played in Better Player.
class BetterPlayerDataSource {
  /// Type of source of video
  final BetterPlayerDataSourceType type;

  /// Url of the video
  final String url;

  /// Subtitles configuration
  final List<BetterPlayerSubtitlesSource>? subtitles;

  /// Flag to determine if current data source is live stream
  final bool? liveStream;

  /// Custom headers for player
  final Map<String, String>? headers;

  /// Should player use hls / dash subtitles (ASMS - Adaptive Streaming Media Sources).
  final bool? useAsmsSubtitles;

  /// Should player use hls tracks
  final bool? useAsmsTracks;

  /// Should player use hls /das audio tracks
  final bool? useAsmsAudioTracks;

  /// List of strings that represents tracks names.
  /// If empty, then better player will choose name based on track parameters
  final List<String>? asmsTrackNames;

  /// Optional, alternative resolutions for non-hls/dash video.
  /// {"360p": "url", "540p": "url2" }
  final Map<String, String>? resolutions;

  /// Optional cache configuration, used only for network data sources
  final BetterPlayerCacheConfiguration? cacheConfiguration;

  /// List of bytes, used only in memory player
  final List<int>? bytes;

  /// Configuration of remote controls notification
  final BetterPlayerNotificationConfiguration? notificationConfiguration;

  /// Duration which will be returned instead of original duration
  final Duration? overriddenDuration;

  /// Video format hint when data source url has not valid extension.
  final BetterPlayerVideoFormat? videoFormat;

  /// Extension of video without dot.
  final String? videoExtension;

  /// Configuration of content protection
  final BetterPlayerDrmConfiguration? drmConfiguration;

  /// Placeholder widget shown until video load or play.
  final Widget? placeholder;

  /// Configuration of video buffering. Currently only supported in Android.
  final BetterPlayerBufferingConfiguration bufferingConfiguration;

  /// Configuration for YouTube playback
  final BetterPlayerYouTubeConfiguration? youTubeConfiguration;

  /// Flag indicating this is a YouTube stream
  final bool isYouTube;

  // ---------------------------------------------------------------------------
  // ✅ FIX: Expose YouTube fields directly (platform layer expects these)
  // ---------------------------------------------------------------------------

  /// Audio-only URL for YouTube separate streams.
  /// (Forwarded from youTubeConfiguration)
  String? get youTubeAudioUrl => youTubeConfiguration?.audioOnlyUrl;

  /// Fallback muxed URL (e.g., itag=18) for fast start.
  /// (Forwarded from youTubeConfiguration)
  String? get youTubeFallbackMuxedUrl => youTubeConfiguration?.fallbackMuxedUrl;

  /// True if stream is HLS.
  /// (Forwarded from youTubeConfiguration)
  bool get youTubeIsHls => youTubeConfiguration?.isHls ?? false;

  /// True if stream is already muxed (video+audio together).
  /// (Forwarded from youTubeConfiguration)
  bool get youTubeIsMuxed => youTubeConfiguration?.isMuxed ?? false;

  BetterPlayerDataSource(
    this.type,
    this.url, {
    this.bytes,
    this.subtitles,
    this.liveStream = false,
    this.headers,
    this.useAsmsSubtitles = true,
    this.useAsmsTracks = true,
    this.useAsmsAudioTracks = true,
    this.asmsTrackNames,
    this.resolutions,
    this.cacheConfiguration,
    this.notificationConfiguration =
        const BetterPlayerNotificationConfiguration(showNotification: false),
    this.overriddenDuration,
    this.videoFormat,
    this.videoExtension,
    this.drmConfiguration,
    this.placeholder,
    this.bufferingConfiguration = const BetterPlayerBufferingConfiguration(),
    this.isYouTube = false,
    this.youTubeConfiguration,
  }) : assert(
          (type == BetterPlayerDataSourceType.network ||
                  type == BetterPlayerDataSourceType.file) ||
              (type == BetterPlayerDataSourceType.memory &&
                  bytes?.isNotEmpty == true),
          "Url can't be null in network or file data source | bytes can't be null when using memory data source",
        );

  /// Factory method to build network data source which uses url as data source.
  factory BetterPlayerDataSource.network(
    String url, {
    List<BetterPlayerSubtitlesSource>? subtitles,
    bool? liveStream,
    Map<String, String>? headers,
    bool? useAsmsSubtitles,
    bool? useAsmsTracks,
    bool? useAsmsAudioTracks,
    Map<String, String>? qualities,
    BetterPlayerCacheConfiguration? cacheConfiguration,
    BetterPlayerNotificationConfiguration notificationConfiguration =
        const BetterPlayerNotificationConfiguration(showNotification: false),
    Duration? overriddenDuration,
    BetterPlayerVideoFormat? videoFormat,
    BetterPlayerDrmConfiguration? drmConfiguration,
    Widget? placeholder,
    BetterPlayerBufferingConfiguration bufferingConfiguration =
        const BetterPlayerBufferingConfiguration(),
  }) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      url,
      subtitles: subtitles,
      liveStream: liveStream,
      headers: headers,
      useAsmsSubtitles: useAsmsSubtitles,
      useAsmsTracks: useAsmsTracks,
      useAsmsAudioTracks: useAsmsAudioTracks,
      resolutions: qualities,
      cacheConfiguration: cacheConfiguration,
      notificationConfiguration: notificationConfiguration,
      overriddenDuration: overriddenDuration,
      videoFormat: videoFormat,
      drmConfiguration: drmConfiguration,
      placeholder: placeholder,
      bufferingConfiguration: bufferingConfiguration,
    );
  }

  /// Factory method to build file data source which uses url as data source.
  factory BetterPlayerDataSource.file(
    String url, {
    List<BetterPlayerSubtitlesSource>? subtitles,
    bool? useAsmsSubtitles,
    bool? useAsmsTracks,
    Map<String, String>? qualities,
    BetterPlayerCacheConfiguration? cacheConfiguration,
    BetterPlayerNotificationConfiguration? notificationConfiguration,
    Duration? overriddenDuration,
    Widget? placeholder,
  }) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.file,
      url,
      subtitles: subtitles,
      useAsmsSubtitles: useAsmsSubtitles,
      useAsmsTracks: useAsmsTracks,
      resolutions: qualities,
      cacheConfiguration: cacheConfiguration,
      notificationConfiguration: notificationConfiguration ??
          const BetterPlayerNotificationConfiguration(showNotification: false),
      overriddenDuration: overriddenDuration,
      placeholder: placeholder,
    );
  }

  /// Factory method to build memory data source which uses bytes as data source.
  factory BetterPlayerDataSource.memory(
    List<int> bytes, {
    String? videoExtension,
    List<BetterPlayerSubtitlesSource>? subtitles,
    bool? useAsmsSubtitles,
    bool? useAsmsTracks,
    Map<String, String>? qualities,
    BetterPlayerCacheConfiguration? cacheConfiguration,
    BetterPlayerNotificationConfiguration? notificationConfiguration,
    Duration? overriddenDuration,
    Widget? placeholder,
  }) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.memory,
      "",
      videoExtension: videoExtension,
      bytes: bytes,
      subtitles: subtitles,
      useAsmsSubtitles: useAsmsSubtitles,
      useAsmsTracks: useAsmsTracks,
      resolutions: qualities,
      cacheConfiguration: cacheConfiguration,
      notificationConfiguration: notificationConfiguration ??
          const BetterPlayerNotificationConfiguration(showNotification: false),
      overriddenDuration: overriddenDuration,
      placeholder: placeholder,
    );
  }

  BetterPlayerDataSource copyWith({
    BetterPlayerDataSourceType? type,
    String? url,
    List<int>? bytes,
    List<BetterPlayerSubtitlesSource>? subtitles,
    bool? liveStream,
    Map<String, String>? headers,
    bool? useAsmsSubtitles,
    bool? useAsmsTracks,
    bool? useAsmsAudioTracks,
    Map<String, String>? resolutions,
    BetterPlayerCacheConfiguration? cacheConfiguration,
    BetterPlayerNotificationConfiguration? notificationConfiguration,
    Duration? overriddenDuration,
    BetterPlayerVideoFormat? videoFormat,
    String? videoExtension,
    BetterPlayerDrmConfiguration? drmConfiguration,
    Widget? placeholder,
    BetterPlayerBufferingConfiguration? bufferingConfiguration,
    bool? isYouTube,
    BetterPlayerYouTubeConfiguration? youTubeConfiguration,
  }) {
    return BetterPlayerDataSource(
      type ?? this.type,
      url ?? this.url,
      bytes: bytes ?? this.bytes,
      subtitles: subtitles ?? this.subtitles,
      liveStream: liveStream ?? this.liveStream,
      headers: headers ?? this.headers,
      useAsmsSubtitles: useAsmsSubtitles ?? this.useAsmsSubtitles,
      useAsmsTracks: useAsmsTracks ?? this.useAsmsTracks,
      useAsmsAudioTracks: useAsmsAudioTracks ?? this.useAsmsAudioTracks,
      resolutions: resolutions ?? this.resolutions,
      cacheConfiguration: cacheConfiguration ?? this.cacheConfiguration,
      notificationConfiguration:
          notificationConfiguration ?? this.notificationConfiguration,
      overriddenDuration: overriddenDuration ?? this.overriddenDuration,
      videoFormat: videoFormat ?? this.videoFormat,
      videoExtension: videoExtension ?? this.videoExtension,
      drmConfiguration: drmConfiguration ?? this.drmConfiguration,
      placeholder: placeholder ?? this.placeholder,
      bufferingConfiguration:
          bufferingConfiguration ?? this.bufferingConfiguration,
      isYouTube: isYouTube ?? this.isYouTube,
      youTubeConfiguration: youTubeConfiguration ?? this.youTubeConfiguration,
    );
  }

  /// Factory method for YouTube streams.
  factory BetterPlayerDataSource.youtube(
    String videoOnlyUrl, {
    required String audioOnlyUrl,
    String? fallbackMuxedUrl,
    bool isHls = false,
    bool isMuxed = false,
  }) {
    return BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      videoOnlyUrl,
      isYouTube: true,
      youTubeConfiguration: BetterPlayerYouTubeConfiguration(
        videoOnlyUrl: videoOnlyUrl,
        audioOnlyUrl: audioOnlyUrl,
        fallbackMuxedUrl: fallbackMuxedUrl,
        isHls: isHls,
        isMuxed: isMuxed,
      ),
    );
  }
}
