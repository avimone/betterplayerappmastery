import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_buffering_configuration.dart';
import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_data_source_type.dart';
import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_drm_configuration.dart';
import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_notification_configuration.dart';
import 'package:gadgetspidy_player/src/configuration/gadgetspidy_player_video_format.dart';
import 'package:gadgetspidy_player/src/subtitles/gadgetspidy_player_subtitles_source.dart';
import 'package:flutter/widgets.dart';

import 'gadgetspidy_player_cache_configuration.dart';

///Representation of data source which will be played in Gadgetspidy Player. Allows
///to setup all necessary configuration connected to video source.
class GadgetspidyPlayerDataSource {
  ///Type of source of video
  final GadgetspidyPlayerDataSourceType type;

  ///Url of the video
  final String url;

  ///Subtitles configuration
  final List<GadgetspidyPlayerSubtitlesSource>? subtitles;

  ///Flag to determine if current data source is live stream
  final bool? liveStream;

  /// Custom headers for player
  final Map<String, String>? headers;

  ///Should player use hls / dash subtitles (ASMS - Adaptive Streaming Media Sources).
  final bool? useAsmsSubtitles;

  ///Should player use hls tracks
  final bool? useAsmsTracks;

  ///Should player use hls /das audio tracks
  final bool? useAsmsAudioTracks;

  ///List of strings that represents tracks names.
  ///If empty, then Gadgetspidy player will choose name based on track parameters
  final List<String>? asmsTrackNames;

  ///Optional, alternative resolutions for non-hls/dash video. Used to setup
  ///different qualities for video.
  ///Data should be in given format:
  ///{"360p": "url", "540p": "url2" }
  final Map<String, String>? resolutions;

  ///Optional cache configuration, used only for network data sources
  final GadgetspidyPlayerCacheConfiguration? cacheConfiguration;

  ///List of bytes, used only in memory player
  final List<int>? bytes;

  ///Configuration of remote controls notification
  final GadgetspidyPlayerNotificationConfiguration? notificationConfiguration;

  ///Duration which will be returned instead of original duration
  final Duration? overriddenDuration;

  ///Video format hint when data source url has not valid extension.
  final GadgetspidyPlayerVideoFormat? videoFormat;

  ///Extension of video without dot.
  final String? videoExtension;

  ///Configuration of content protection
  final GadgetspidyPlayerDrmConfiguration? drmConfiguration;

  ///Placeholder widget which will be shown until video load or play. This
  ///placeholder may be useful if you want to show placeholder before each video
  ///in playlist. Otherwise, you should use placeholder from
  /// GadgetspidyPlayerConfiguration.
  final Widget? placeholder;

  ///Configuration of video buffering. Currently only supported in Android
  ///platform.
  final GadgetspidyPlayerBufferingConfiguration bufferingConfiguration;

  GadgetspidyPlayerDataSource(
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
        const GadgetspidyPlayerNotificationConfiguration(
      showNotification: false,
    ),
    this.overriddenDuration,
    this.videoFormat,
    this.videoExtension,
    this.drmConfiguration,
    this.placeholder,
    this.bufferingConfiguration =
        const GadgetspidyPlayerBufferingConfiguration(),
  }) : assert(
            (type == GadgetspidyPlayerDataSourceType.network ||
                    type == GadgetspidyPlayerDataSourceType.file) ||
                (type == GadgetspidyPlayerDataSourceType.memory &&
                    bytes?.isNotEmpty == true),
            "Url can't be null in network or file data source | bytes can't be null when using memory data source");

  ///Factory method to build network data source which uses url as data source
  ///Bytes parameter is not used in this data source.
  factory GadgetspidyPlayerDataSource.network(
    String url, {
    List<GadgetspidyPlayerSubtitlesSource>? subtitles,
    bool? liveStream,
    Map<String, String>? headers,
    bool? useAsmsSubtitles,
    bool? useAsmsTracks,
    bool? useAsmsAudioTracks,
    Map<String, String>? qualities,
    GadgetspidyPlayerCacheConfiguration? cacheConfiguration,
    GadgetspidyPlayerNotificationConfiguration notificationConfiguration =
        const GadgetspidyPlayerNotificationConfiguration(
            showNotification: false),
    Duration? overriddenDuration,
    GadgetspidyPlayerVideoFormat? videoFormat,
    GadgetspidyPlayerDrmConfiguration? drmConfiguration,
    Widget? placeholder,
    GadgetspidyPlayerBufferingConfiguration bufferingConfiguration =
        const GadgetspidyPlayerBufferingConfiguration(),
  }) {
    return GadgetspidyPlayerDataSource(
      GadgetspidyPlayerDataSourceType.network,
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

  ///Factory method to build file data source which uses url as data source.
  ///Bytes parameter is not used in this data source.
  factory GadgetspidyPlayerDataSource.file(
    String url, {
    List<GadgetspidyPlayerSubtitlesSource>? subtitles,
    bool? useAsmsSubtitles,
    bool? useAsmsTracks,
    Map<String, String>? qualities,
    GadgetspidyPlayerCacheConfiguration? cacheConfiguration,
    GadgetspidyPlayerNotificationConfiguration? notificationConfiguration,
    Duration? overriddenDuration,
    Widget? placeholder,
  }) {
    return GadgetspidyPlayerDataSource(
      GadgetspidyPlayerDataSourceType.file,
      url,
      subtitles: subtitles,
      useAsmsSubtitles: useAsmsSubtitles,
      useAsmsTracks: useAsmsTracks,
      resolutions: qualities,
      cacheConfiguration: cacheConfiguration,
      notificationConfiguration: notificationConfiguration =
          const GadgetspidyPlayerNotificationConfiguration(
              showNotification: false),
      overriddenDuration: overriddenDuration,
      placeholder: placeholder,
    );
  }

  ///Factory method to build network data source which uses bytes as data source.
  ///Url parameter is not used in this data source.
  factory GadgetspidyPlayerDataSource.memory(
    List<int> bytes, {
    String? videoExtension,
    List<GadgetspidyPlayerSubtitlesSource>? subtitles,
    bool? useAsmsSubtitles,
    bool? useAsmsTracks,
    Map<String, String>? qualities,
    GadgetspidyPlayerCacheConfiguration? cacheConfiguration,
    GadgetspidyPlayerNotificationConfiguration? notificationConfiguration,
    Duration? overriddenDuration,
    Widget? placeholder,
  }) {
    return GadgetspidyPlayerDataSource(
      GadgetspidyPlayerDataSourceType.memory,
      "",
      videoExtension: videoExtension,
      bytes: bytes,
      subtitles: subtitles,
      useAsmsSubtitles: useAsmsSubtitles,
      useAsmsTracks: useAsmsTracks,
      resolutions: qualities,
      cacheConfiguration: cacheConfiguration,
      notificationConfiguration: notificationConfiguration =
          const GadgetspidyPlayerNotificationConfiguration(
              showNotification: false),
      overriddenDuration: overriddenDuration,
      placeholder: placeholder,
    );
  }

  GadgetspidyPlayerDataSource copyWith({
    GadgetspidyPlayerDataSourceType? type,
    String? url,
    List<int>? bytes,
    List<GadgetspidyPlayerSubtitlesSource>? subtitles,
    bool? liveStream,
    Map<String, String>? headers,
    bool? useAsmsSubtitles,
    bool? useAsmsTracks,
    bool? useAsmsAudioTracks,
    Map<String, String>? resolutions,
    GadgetspidyPlayerCacheConfiguration? cacheConfiguration,
    GadgetspidyPlayerNotificationConfiguration? notificationConfiguration =
        const GadgetspidyPlayerNotificationConfiguration(
            showNotification: false),
    Duration? overriddenDuration,
    GadgetspidyPlayerVideoFormat? videoFormat,
    String? videoExtension,
    GadgetspidyPlayerDrmConfiguration? drmConfiguration,
    Widget? placeholder,
    GadgetspidyPlayerBufferingConfiguration? bufferingConfiguration =
        const GadgetspidyPlayerBufferingConfiguration(),
  }) {
    return GadgetspidyPlayerDataSource(
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
    );
  }
}
