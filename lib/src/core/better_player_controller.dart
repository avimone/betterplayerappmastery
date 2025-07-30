import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:better_player/better_player.dart';
import 'package:better_player/src/configuration/better_player_controller_event.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/subtitles/better_player_subtitle.dart';
import 'package:better_player/src/subtitles/better_player_subtitles_factory.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:better_player/src/video_player/video_player_platform_interface.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:ui' as ui;

// ===== THUMBNAIL SEEKING CONFIGURATION =====
class ThumbnailSeekingConfiguration {
  /// Enable/disable thumbnail seeking
  final bool enabled;

  /// Number of thumbnails to generate for seeking (default: 100)
  final int thumbnailCount;

  /// Quality of thumbnails (0-100, default: 80)
  final int thumbnailQuality;

  /// Cache thumbnails for offline use
  final bool cacheThumbnails;

  /// Thumbnail height in pixels (width auto-calculated to maintain aspect ratio)
  final int thumbnailHeight;

  /// Show thumbnail preview on hover/drag
  final bool showPreviewOnHover;

  /// Enable thumbnail generation for HLS segments
  final bool enableHlsThumbnails;

  const ThumbnailSeekingConfiguration({
    this.enabled = true,
    this.thumbnailCount = 100,
    this.thumbnailQuality = 80,
    this.cacheThumbnails = true,
    this.thumbnailHeight = 90,
    this.showPreviewOnHover = true,
    this.enableHlsThumbnails = true,
  });
}

// ===== THUMBNAIL DATA MODEL =====
class BetterPlayerVideoThumbnail {
  final Duration timePosition;
  final Uint8List imageData;
  final int width;
  final int height;
  final String? cacheKey;

  const BetterPlayerVideoThumbnail({
    required this.timePosition,
    required this.imageData,
    required this.width,
    required this.height,
    this.cacheKey,
  });
}

///Class used to control overall Better Player behavior. Main class to change
///state of Better Player.
class BetterPlayerController {
  static const String _durationParameter = "duration";
  static const String _progressParameter = "progress";
  static const String _bufferedParameter = "buffered";
  static const String _volumeParameter = "volume";
  static const String _speedParameter = "speed";
  static const String _dataSourceParameter = "dataSource";
  static const String _authorizationHeader = "Authorization";

  bool get thumbnailsReady => _thumbnailsGenerated;

  /// Stream for thumbnail preview
  Stream<BetterPlayerVideoThumbnail?> get thumbnailPreviewStream =>
      _thumbnailPreviewController.stream;

  ///General configuration used in controller instance.
  final BetterPlayerConfiguration betterPlayerConfiguration;

  ///Playlist configuration used in controller instance.
  final BetterPlayerPlaylistConfiguration? betterPlayerPlaylistConfiguration;

  /// Thumbnail seeking configuration
  final ThumbnailSeekingConfiguration? thumbnailSeekingConfiguration;

  ///List of event listeners, which listen to events.
  final List<Function(BetterPlayerEvent)?> _eventListeners = [];

  ///List of files to delete once player disposes.
  final List<File> _tempFiles = [];

  ///Stream controller which emits stream when control visibility changes.
  final StreamController<bool> _controlsVisibilityStreamController =
      StreamController.broadcast();

  ///Instance of video player controller which is adapter used to communicate
  ///between flutter high level code and lower level native code.
  VideoPlayerController? videoPlayerController;

  ///Controls configuration
  late BetterPlayerControlsConfiguration _betterPlayerControlsConfiguration;

  ///Controls configuration
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      _betterPlayerControlsConfiguration;

  ///Expose all active eventListeners
  List<Function(BetterPlayerEvent)?> get eventListeners =>
      _eventListeners.sublist(1);

  /// Defines a event listener where video player events will be send.
  Function(BetterPlayerEvent)? get eventListener =>
      betterPlayerConfiguration.eventListener;

  ///Flag used to store full screen mode state.
  bool _isFullScreen = false;

  ///Flag used to store full screen mode state.
  bool get isFullScreen => _isFullScreen;

  ///Time when last progress event was sent
  int _lastPositionSelection = 0;

  ///Currently used data source in player.
  BetterPlayerDataSource? _betterPlayerDataSource;

  ///Currently used data source in player.
  BetterPlayerDataSource? get betterPlayerDataSource => _betterPlayerDataSource;

  ///List of BetterPlayerSubtitlesSources.
  final List<BetterPlayerSubtitlesSource> _betterPlayerSubtitlesSourceList = [];

  ///List of BetterPlayerSubtitlesSources.
  List<BetterPlayerSubtitlesSource> get betterPlayerSubtitlesSourceList =>
      _betterPlayerSubtitlesSourceList;
  BetterPlayerSubtitlesSource? _betterPlayerSubtitlesSource;

  ///Currently used subtitles source.
  BetterPlayerSubtitlesSource? get betterPlayerSubtitlesSource =>
      _betterPlayerSubtitlesSource;

  ///Subtitles lines for current data source.
  List<BetterPlayerSubtitle> subtitlesLines = [];

  ///List of tracks available for current data source. Used only for HLS / DASH.
  List<BetterPlayerAsmsTrack> _betterPlayerAsmsTracks = [];

  ///List of tracks available for current data source. Used only for HLS / DASH.
  List<BetterPlayerAsmsTrack> get betterPlayerAsmsTracks =>
      _betterPlayerAsmsTracks;

  ///Currently selected player track. Used only for HLS / DASH.
  BetterPlayerAsmsTrack? _betterPlayerAsmsTrack;

  ///Currently selected player track. Used only for HLS / DASH.
  BetterPlayerAsmsTrack? get betterPlayerAsmsTrack => _betterPlayerAsmsTrack;

  ///Timer for next video. Used in playlist.
  Timer? _nextVideoTimer;

  ///Time for next video.
  int? _nextVideoTime;

  ///Stream controller which emits next video time.
  final StreamController<int?> _nextVideoTimeStreamController =
      StreamController.broadcast();

  Stream<int?> get nextVideoTimeStream => _nextVideoTimeStreamController.stream;

  ///Has player been disposed.
  bool _disposed = false;

  ///Was player playing before automatic pause.
  bool? _wasPlayingBeforePause;

  ///Currently used translations
  BetterPlayerTranslations translations = BetterPlayerTranslations();

  ///Has current data source started
  bool _hasCurrentDataSourceStarted = false;

  ///Has current data source initialized
  bool _hasCurrentDataSourceInitialized = false;

  ///Stream which sends flag whenever visibility of controls changes
  Stream<bool> get controlsVisibilityStream =>
      _controlsVisibilityStreamController.stream;

  ///Current app lifecycle state.
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  ///Flag which determines if controls (UI interface) is shown. When false,
  ///UI won't be shown (show only player surface).
  bool _controlsEnabled = true;

  ///Flag which determines if controls (UI interface) is shown. When false,
  ///UI won't be shown (show only player surface).
  bool get controlsEnabled => _controlsEnabled;

  ///Overridden aspect ratio which will be used instead of aspect ratio passed
  ///in configuration.
  double? _overriddenAspectRatio;

  ///Overridden fit which will be used instead of fit passed in configuration.
  BoxFit? _overriddenFit;

  ///Was Picture in Picture opened.
  bool _wasInPipMode = false;

  ///Was player in fullscreen before Picture in Picture opened.
  bool _wasInFullScreenBeforePiP = false;

  ///Was controls enabled before Picture in Picture opened.
  bool _wasControlsEnabledBeforePiP = false;

  ///GlobalKey of the BetterPlayer widget
  GlobalKey? _betterPlayerGlobalKey;

  ///Getter of the GlobalKey
  GlobalKey? get betterPlayerGlobalKey => _betterPlayerGlobalKey;

  ///StreamSubscription for VideoEvent listener
  StreamSubscription<VideoEvent>? _videoEventStreamSubscription;

  ///Are controls always visible
  bool _controlsAlwaysVisible = false;

  ///Are controls always visible
  bool get controlsAlwaysVisible => _controlsAlwaysVisible;

  ///List of all possible audio tracks returned from ASMS stream
  List<BetterPlayerAsmsAudioTrack>? _betterPlayerAsmsAudioTracks;

  ///List of all possible audio tracks returned from ASMS stream
  List<BetterPlayerAsmsAudioTrack>? get betterPlayerAsmsAudioTracks =>
      _betterPlayerAsmsAudioTracks;

  ///Selected ASMS audio track
  BetterPlayerAsmsAudioTrack? _betterPlayerAsmsAudioTrack;

  ///Selected ASMS audio track
  BetterPlayerAsmsAudioTrack? get betterPlayerAsmsAudioTrack =>
      _betterPlayerAsmsAudioTrack;

  ///Selected videoPlayerValue when error occurred.
  VideoPlayerValue? _videoPlayerValueOnError;

  ///Flag which holds information about player visibility
  bool _isPlayerVisible = true;

  final StreamController<BetterPlayerControllerEvent>
      _controllerEventStreamController = StreamController.broadcast();

  ///Stream of internal controller events. Shouldn't be used inside app. For
  ///normal events, use eventListener.
  Stream<BetterPlayerControllerEvent> get controllerEventStream =>
      _controllerEventStreamController.stream;

  ///Flag which determines whether are ASMS segments loading
  bool _asmsSegmentsLoading = false;

  ///List of loaded ASMS segments
  final List<String> _asmsSegmentsLoaded = [];

  ///Currently displayed [BetterPlayerSubtitle].
  BetterPlayerSubtitle? renderedSubtitle;

// Add this field to track fullscreen state before PiP
  bool _wasInFullscreenBeforePip = false;
  bool _isPipActive = false;
  bool get isPipActive => _isPipActive;
  // ===== THUMBNAIL SEEKING FIELDS =====
  /// Thumbnail cache for seeking
  final Map<Duration, BetterPlayerVideoThumbnail> _thumbnailCache = {};

  /// Stream controller for thumbnail preview
  final StreamController<BetterPlayerVideoThumbnail?>
      _thumbnailPreviewController =
      StreamController<BetterPlayerVideoThumbnail?>.broadcast();

  /// Flag to track if thumbnails are generated
  bool _thumbnailsGenerated = false;

  /// Flag to track if thumbnails are being generated
  bool _isGeneratingThumbnails = false;

  /// Current video URL for thumbnail cache key
  String? _currentVideoUrl;

  BetterPlayerController(
    this.betterPlayerConfiguration, {
    this.betterPlayerPlaylistConfiguration,
    this.thumbnailSeekingConfiguration,
    BetterPlayerDataSource? betterPlayerDataSource,
  }) {
    this._betterPlayerControlsConfiguration =
        betterPlayerConfiguration.controlsConfiguration;
    _eventListeners.add(eventListener);
    if (betterPlayerDataSource != null) {
      setupDataSource(betterPlayerDataSource);
    }
  }

  /// Generate thumbnails if needed (call this in your setupDataSource method)
  Future<void> _generateThumbnailsIfNeeded(
      BetterPlayerDataSource dataSource) async {
    if (thumbnailSeekingConfiguration?.enabled != true ||
        _isGeneratingThumbnails ||
        _thumbnailsGenerated) return;

    _isGeneratingThumbnails = true;

    try {
      // Wait for video initialization
      await _waitForVideoInitialization();

      final videoDuration = videoPlayerController?.value.duration;
      if (videoDuration == null || videoDuration.inMilliseconds <= 0) {
        print('Video duration not available for thumbnail generation');
        return;
      }

      // Check cache first
      if (thumbnailSeekingConfiguration?.cacheThumbnails == true) {
        final cachedThumbnails = await _loadCachedThumbnails(dataSource.url!);
        if (cachedThumbnails.isNotEmpty) {
          _thumbnailCache.addAll(cachedThumbnails);
          _thumbnailsGenerated = true;
          return;
        }
      }

      // Generate new thumbnails
      await _generateThumbnails(dataSource, videoDuration);
    } catch (e) {
      print('Error generating thumbnails: $e');
    } finally {
      _isGeneratingThumbnails = false;
    }
  }

  /// Wait for video initialization
  Future<void> _waitForVideoInitialization() async {
    int attempts = 0;
    const maxAttempts = 50;

    while (attempts < maxAttempts) {
      if (videoPlayerController?.value.initialized == true) {
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    throw Exception('Video failed to initialize within timeout period');
  }

  /// Generate thumbnails
  Future<void> _generateThumbnails(
      BetterPlayerDataSource dataSource, Duration videoDuration) async {
    final config = thumbnailSeekingConfiguration!;
    final List<Future<BetterPlayerVideoThumbnail?>> thumbnailFutures = [];

    final intervalMs = videoDuration.inMilliseconds / config.thumbnailCount;

    for (int i = 0; i < config.thumbnailCount; i++) {
      final timeMs = (i * intervalMs).round();
      final timePosition = Duration(milliseconds: timeMs);

      thumbnailFutures
          .add(_generateSingleThumbnail(dataSource.url!, timePosition));
    }

    const batchSize = 10;
    for (int i = 0; i < thumbnailFutures.length; i += batchSize) {
      final end = (i + batchSize < thumbnailFutures.length)
          ? i + batchSize
          : thumbnailFutures.length;
      final batch = thumbnailFutures.sublist(i, end);

      final results = await Future.wait(batch);

      for (final thumbnail in results) {
        if (thumbnail != null) {
          _thumbnailCache[thumbnail.timePosition] = thumbnail;
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    _thumbnailsGenerated = true;

    if (config.cacheThumbnails && _thumbnailCache.isNotEmpty) {
      await _saveThumbnailsToCache(dataSource.url!, _thumbnailCache);
    }
  }

  /// Generate single thumbnail
  Future<BetterPlayerVideoThumbnail?> _generateSingleThumbnail(
      String videoUrl, Duration timePosition) async {
    final config = thumbnailSeekingConfiguration!;

    try {
      final thumbnailData = await VideoThumbnail.thumbnailData(
        video: videoUrl,
        imageFormat: ImageFormat.PNG,
        maxHeight: config.thumbnailHeight,
        timeMs: timePosition.inMilliseconds,
        quality: config.thumbnailQuality,
      );

      if (thumbnailData != null) {
        final codec = await ui.instantiateImageCodec(thumbnailData);
        final frame = await codec.getNextFrame();
        final image = frame.image;

        return BetterPlayerVideoThumbnail(
          timePosition: timePosition,
          imageData: thumbnailData,
          width: image.width,
          height: image.height,
          cacheKey: _generateCacheKey(videoUrl, timePosition),
        );
      }
    } catch (e) {
      print(
          'Error generating thumbnail at ${timePosition.inMilliseconds}ms: $e');
    }

    return null;
  }

  /// Get thumbnail at specific position
  BetterPlayerVideoThumbnail? getThumbnailAtPosition(Duration position) {
    if (!_thumbnailsGenerated || _thumbnailCache.isEmpty) return null;

    Duration? closestTime;
    Duration minDiff = const Duration(hours: 1);

    for (final time in _thumbnailCache.keys) {
      final diff = Duration(
          milliseconds: (time.inMilliseconds - position.inMilliseconds).abs());
      if (diff < minDiff) {
        minDiff = diff;
        closestTime = time;
      }
    }

    return closestTime != null ? _thumbnailCache[closestTime] : null;
  }

  /// Show thumbnail preview
  void showThumbnailPreview(Duration position) {
    if (thumbnailSeekingConfiguration?.showPreviewOnHover != true) return;

    final thumbnail = getThumbnailAtPosition(position);
    _thumbnailPreviewController.add(thumbnail);
  }

  /// Hide thumbnail preview
  void hideThumbnailPreview() {
    _thumbnailPreviewController.add(null);
  }

  /// Generate cache key
  String _generateCacheKey(String videoUrl, Duration position) {
    final combined = '$videoUrl-${position.inMilliseconds}';
    return md5.convert(utf8.encode(combined)).toString();
  }

  /// Get cache directory
  Future<String> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/video_thumbnails');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  /// Save thumbnails to cache
  Future<void> _saveThumbnailsToCache(String videoUrl,
      Map<Duration, BetterPlayerVideoThumbnail> thumbnails) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final videoHash = md5.convert(utf8.encode(videoUrl)).toString();

      for (final entry in thumbnails.entries) {
        final thumbnail = entry.value;
        final fileName = '${videoHash}_${entry.key.inMilliseconds}.png';
        final file = File('$cacheDir/$fileName');
        await file.writeAsBytes(thumbnail.imageData);
      }
    } catch (e) {
      print('Error saving thumbnails to cache: $e');
    }
  }

  /// Load cached thumbnails
  Future<Map<Duration, BetterPlayerVideoThumbnail>> _loadCachedThumbnails(
      String videoUrl) async {
    final Map<Duration, BetterPlayerVideoThumbnail> cachedThumbnails = {};

    try {
      final cacheDir = await _getCacheDirectory();
      final videoHash = md5.convert(utf8.encode(videoUrl)).toString();
      final directory = Directory(cacheDir);

      await for (final entity in directory.list()) {
        if (entity is File && entity.path.contains(videoHash)) {
          final fileName = entity.path.split('/').last;
          final timeStr = fileName
              .replaceFirst('${videoHash}_', '')
              .replaceFirst('.png', '');

          try {
            final timeMs = int.parse(timeStr);
            final timePosition = Duration(milliseconds: timeMs);
            final imageData = await entity.readAsBytes();

            final codec = await ui.instantiateImageCodec(imageData);
            final frame = await codec.getNextFrame();
            final image = frame.image;

            cachedThumbnails[timePosition] = BetterPlayerVideoThumbnail(
              timePosition: timePosition,
              imageData: imageData,
              width: image.width,
              height: image.height,
              cacheKey: _generateCacheKey(videoUrl, timePosition),
            );
          } catch (e) {
            print('Error loading cached thumbnail: $e');
          }
        }
      }
    } catch (e) {
      print('Error loading cached thumbnails: $e');
    }

    return cachedThumbnails;
  }

  /// Clear thumbnail cache
  Future<void> clearThumbnailCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final directory = Directory(cacheDir);

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }

      _thumbnailCache.clear();
      _thumbnailsGenerated = false;
    } catch (e) {
      print('Error clearing thumbnail cache: $e');
    }
  }

  ///Get BetterPlayerController from context. Used in InheritedWidget.
  static BetterPlayerController of(BuildContext context) {
    final betterPLayerControllerProvider = context
        .dependOnInheritedWidgetOfExactType<BetterPlayerControllerProvider>()!;

    return betterPLayerControllerProvider.controller;
  }

  ///Setup new data source in Better Player.
  Future setupDataSource(BetterPlayerDataSource betterPlayerDataSource) async {
    postEvent(BetterPlayerEvent(BetterPlayerEventType.setupDataSource,
        parameters: <String, dynamic>{
          _dataSourceParameter: betterPlayerDataSource,
        }));
    _postControllerEvent(BetterPlayerControllerEvent.setupDataSource);
    _hasCurrentDataSourceStarted = false;
    _hasCurrentDataSourceInitialized = false;
    _betterPlayerDataSource = betterPlayerDataSource;
    _betterPlayerSubtitlesSourceList.clear();

    ///Build videoPlayerController if null
    if (videoPlayerController == null) {
      videoPlayerController = VideoPlayerController(
          bufferingConfiguration:
              betterPlayerDataSource.bufferingConfiguration);
      videoPlayerController?.addListener(_onVideoPlayerChanged);
    }

    ///Clear asms tracks
    betterPlayerAsmsTracks.clear();

    ///Setup subtitles
    final List<BetterPlayerSubtitlesSource>? betterPlayerSubtitlesSourceList =
        betterPlayerDataSource.subtitles;
    if (betterPlayerSubtitlesSourceList != null) {
      _betterPlayerSubtitlesSourceList
          .addAll(betterPlayerDataSource.subtitles!);
    }

    if (_isDataSourceAsms(betterPlayerDataSource)) {
      _setupAsmsDataSource(betterPlayerDataSource).then((dynamic value) {
        _setupSubtitles();
      });
    } else {
      _setupSubtitles();
    }

    ///Process data source
    await _setupDataSource(betterPlayerDataSource);
    setTrack(BetterPlayerAsmsTrack.defaultTrack());
    // ===== THUMBNAIL SEEKING INTEGRATION =====
    /// Generate thumbnails if enabled
    if (thumbnailSeekingConfiguration?.enabled == true) {
      _generateThumbnailsIfNeeded(betterPlayerDataSource);
    }
  }

  ///Configure subtitles based on subtitles source.
  void _setupSubtitles() {
    _betterPlayerSubtitlesSourceList.add(
      BetterPlayerSubtitlesSource(type: BetterPlayerSubtitlesSourceType.none),
    );
    final defaultSubtitle = _betterPlayerSubtitlesSourceList
        .firstWhereOrNull((element) => element.selectedByDefault == true);

    ///Setup subtitles (none is default)
    setupSubtitleSource(
        defaultSubtitle ?? _betterPlayerSubtitlesSourceList.last,
        sourceInitialize: true);
  }

  ///Check if given [betterPlayerDataSource] is HLS / DASH-type data source.
  bool _isDataSourceAsms(BetterPlayerDataSource betterPlayerDataSource) =>
      (BetterPlayerAsmsUtils.isDataSourceHls(betterPlayerDataSource.url) ||
          betterPlayerDataSource.videoFormat == BetterPlayerVideoFormat.hls) ||
      (BetterPlayerAsmsUtils.isDataSourceDash(betterPlayerDataSource.url) ||
          betterPlayerDataSource.videoFormat == BetterPlayerVideoFormat.dash);

  ///Configure HLS / DASH data source based on provided data source and configuration.
  ///This method configures tracks, subtitles and audio tracks from given
  ///master playlist.
  Future _setupAsmsDataSource(BetterPlayerDataSource source) async {
    final String? data = await BetterPlayerAsmsUtils.getDataFromUrl(
      betterPlayerDataSource!.url,
      _getHeaders(),
    );
    if (data != null) {
      final BetterPlayerAsmsDataHolder _response =
          await BetterPlayerAsmsUtils.parse(data, betterPlayerDataSource!.url);

      /// Load tracks
      if (_betterPlayerDataSource?.useAsmsTracks == true) {
        _betterPlayerAsmsTracks = _response.tracks ?? [];
      }

      /// Load subtitles
      if (betterPlayerDataSource?.useAsmsSubtitles == true) {
        final List<BetterPlayerAsmsSubtitle> asmsSubtitles =
            _response.subtitles ?? [];
        asmsSubtitles.forEach((BetterPlayerAsmsSubtitle asmsSubtitle) {
          _betterPlayerSubtitlesSourceList.add(
            BetterPlayerSubtitlesSource(
              type: BetterPlayerSubtitlesSourceType.network,
              name: asmsSubtitle.name,
              urls: asmsSubtitle.realUrls,
              asmsIsSegmented: asmsSubtitle.isSegmented,
              asmsSegmentsTime: asmsSubtitle.segmentsTime,
              asmsSegments: asmsSubtitle.segments,
              selectedByDefault: asmsSubtitle.isDefault,
            ),
          );
        });
      }

      ///Load audio tracks
      if (betterPlayerDataSource?.useAsmsAudioTracks == true &&
          _isDataSourceAsms(betterPlayerDataSource!)) {
        _betterPlayerAsmsAudioTracks = _response.audios ?? [];
        if (_betterPlayerAsmsAudioTracks?.isNotEmpty == true) {
          setAudioTrack(_betterPlayerAsmsAudioTracks!.first);
        }
      }
    }
  }

  ///Setup subtitles to be displayed from given subtitle source.
  ///If subtitles source is segmented then don't load videos at start. Videos
  ///will load with just in time policy.
  Future<void> setupSubtitleSource(BetterPlayerSubtitlesSource subtitlesSource,
      {bool sourceInitialize = false}) async {
    _betterPlayerSubtitlesSource = subtitlesSource;
    subtitlesLines.clear();
    _asmsSegmentsLoaded.clear();
    _asmsSegmentsLoading = false;

    if (subtitlesSource.type != BetterPlayerSubtitlesSourceType.none) {
      if (subtitlesSource.asmsIsSegmented == true) {
        return;
      }
      final subtitlesParsed =
          await BetterPlayerSubtitlesFactory.parseSubtitles(subtitlesSource);
      subtitlesLines.addAll(subtitlesParsed);
    }

    _postEvent(BetterPlayerEvent(BetterPlayerEventType.changedSubtitles));
    if (!_disposed && !sourceInitialize) {
      _postControllerEvent(BetterPlayerControllerEvent.changeSubtitles);
    }
  }

  ///Load ASMS subtitles segments for given [position].
  ///Segments are being loaded within range (current video position;endPosition)
  ///where endPosition is based on time segment detected in HLS playlist. If
  ///time segment is not present then 5000 ms will be used. Also time segment
  ///is multiplied by 5 to increase window of duration.
  ///Segments are also cached, so same segment won't load twice. Only one
  ///pack of segments can be load at given time.
  Future _loadAsmsSubtitlesSegments(Duration position) async {
    try {
      if (_asmsSegmentsLoading) {
        return;
      }
      _asmsSegmentsLoading = true;
      final BetterPlayerSubtitlesSource? source = _betterPlayerSubtitlesSource;
      final Duration loadDurationEnd = Duration(
          milliseconds: position.inMilliseconds +
              5 * (_betterPlayerSubtitlesSource?.asmsSegmentsTime ?? 5000));

      final segmentsToLoad = _betterPlayerSubtitlesSource?.asmsSegments
          ?.where((segment) {
            return segment.startTime > position &&
                segment.endTime < loadDurationEnd &&
                !_asmsSegmentsLoaded.contains(segment.realUrl);
          })
          .map((segment) => segment.realUrl)
          .toList();

      if (segmentsToLoad != null && segmentsToLoad.isNotEmpty) {
        final subtitlesParsed =
            await BetterPlayerSubtitlesFactory.parseSubtitles(
                BetterPlayerSubtitlesSource(
          type: _betterPlayerSubtitlesSource!.type,
          headers: _betterPlayerSubtitlesSource!.headers,
          urls: segmentsToLoad,
        ));

        ///Additional check if current source of subtitles is same as source
        ///used to start loading subtitles. It can be different when user
        ///changes subtitles and there was already pending load.
        if (source == _betterPlayerSubtitlesSource) {
          subtitlesLines.addAll(subtitlesParsed);
          _asmsSegmentsLoaded.addAll(segmentsToLoad);
        }
      }
      _asmsSegmentsLoading = false;
    } catch (exception) {
      BetterPlayerUtils.log("Load ASMS subtitle segments failed: $exception");
    }
  }

  ///Get VideoFormat from BetterPlayerVideoFormat (adapter method which translates
  ///to video_player supported format).
  VideoFormat? _getVideoFormat(
      BetterPlayerVideoFormat? betterPlayerVideoFormat) {
    if (betterPlayerVideoFormat == null) {
      return null;
    }
    switch (betterPlayerVideoFormat) {
      case BetterPlayerVideoFormat.dash:
        return VideoFormat.dash;
      case BetterPlayerVideoFormat.hls:
        return VideoFormat.hls;
      case BetterPlayerVideoFormat.ss:
        return VideoFormat.ss;
      case BetterPlayerVideoFormat.other:
        return VideoFormat.other;
    }
  }

  ///Internal method which invokes videoPlayerController source setup.
  Future _setupDataSource(BetterPlayerDataSource betterPlayerDataSource) async {
    switch (betterPlayerDataSource.type) {
      case BetterPlayerDataSourceType.network:
        await videoPlayerController?.setNetworkDataSource(
          betterPlayerDataSource.url,
          headers: _getHeaders(),
          useCache:
              _betterPlayerDataSource!.cacheConfiguration?.useCache ?? false,
          maxCacheSize:
              _betterPlayerDataSource!.cacheConfiguration?.maxCacheSize ?? 0,
          maxCacheFileSize:
              _betterPlayerDataSource!.cacheConfiguration?.maxCacheFileSize ??
                  0,
          cacheKey: _betterPlayerDataSource?.cacheConfiguration?.key,
          showNotification: _betterPlayerDataSource
              ?.notificationConfiguration?.showNotification,
          title: _betterPlayerDataSource?.notificationConfiguration?.title,
          author: _betterPlayerDataSource?.notificationConfiguration?.author,
          imageUrl:
              _betterPlayerDataSource?.notificationConfiguration?.imageUrl,
          notificationChannelName: _betterPlayerDataSource
              ?.notificationConfiguration?.notificationChannelName,
          overriddenDuration: _betterPlayerDataSource!.overriddenDuration,
          formatHint: _getVideoFormat(_betterPlayerDataSource!.videoFormat),
          licenseUrl: _betterPlayerDataSource?.drmConfiguration?.licenseUrl,
          certificateUrl:
              _betterPlayerDataSource?.drmConfiguration?.certificateUrl,
          drmHeaders: _betterPlayerDataSource?.drmConfiguration?.headers,
          activityName:
              _betterPlayerDataSource?.notificationConfiguration?.activityName,
          clearKey: _betterPlayerDataSource?.drmConfiguration?.clearKey,
          videoExtension: _betterPlayerDataSource!.videoExtension,
        );

        break;
      case BetterPlayerDataSourceType.file:
        final file = File(betterPlayerDataSource.url);
        if (!file.existsSync()) {
          BetterPlayerUtils.log(
              "File ${file.path} doesn't exists. This may be because "
              "you're acessing file from native path and Flutter doesn't "
              "recognize this path.");
        }

        await videoPlayerController?.setFileDataSource(
            File(betterPlayerDataSource.url),
            showNotification: _betterPlayerDataSource
                ?.notificationConfiguration?.showNotification,
            title: _betterPlayerDataSource?.notificationConfiguration?.title,
            author: _betterPlayerDataSource?.notificationConfiguration?.author,
            imageUrl:
                _betterPlayerDataSource?.notificationConfiguration?.imageUrl,
            notificationChannelName: _betterPlayerDataSource
                ?.notificationConfiguration?.notificationChannelName,
            overriddenDuration: _betterPlayerDataSource!.overriddenDuration,
            activityName: _betterPlayerDataSource
                ?.notificationConfiguration?.activityName,
            clearKey: _betterPlayerDataSource?.drmConfiguration?.clearKey);
        break;
      case BetterPlayerDataSourceType.memory:
        final file = await _createFile(_betterPlayerDataSource!.bytes!,
            extension: _betterPlayerDataSource!.videoExtension);

        if (file.existsSync()) {
          await videoPlayerController?.setFileDataSource(file,
              showNotification: _betterPlayerDataSource
                  ?.notificationConfiguration?.showNotification,
              title: _betterPlayerDataSource?.notificationConfiguration?.title,
              author:
                  _betterPlayerDataSource?.notificationConfiguration?.author,
              imageUrl:
                  _betterPlayerDataSource?.notificationConfiguration?.imageUrl,
              notificationChannelName: _betterPlayerDataSource
                  ?.notificationConfiguration?.notificationChannelName,
              overriddenDuration: _betterPlayerDataSource!.overriddenDuration,
              activityName: _betterPlayerDataSource
                  ?.notificationConfiguration?.activityName,
              clearKey: _betterPlayerDataSource?.drmConfiguration?.clearKey);
          _tempFiles.add(file);
        } else {
          throw ArgumentError("Couldn't create file from memory.");
        }
        break;

      default:
        throw UnimplementedError(
            "${betterPlayerDataSource.type} is not implemented");
    }
    await _initializeVideo();
  }

  ///Create file from provided list of bytes. File will be created in temporary
  ///directory.
  Future<File> _createFile(List<int> bytes,
      {String? extension = "temp"}) async {
    final String dir = (await getTemporaryDirectory()).path;
    final File temp = File(
        '$dir/better_player_${DateTime.now().millisecondsSinceEpoch}.$extension');
    await temp.writeAsBytes(bytes);
    return temp;
  }

  ///Initializes video based on configuration. Invoke actions which need to be
  ///run on player start.
  Future _initializeVideo() async {
    setLooping(betterPlayerConfiguration.looping);
    _videoEventStreamSubscription?.cancel();
    _videoEventStreamSubscription = null;

    _videoEventStreamSubscription = videoPlayerController
        ?.videoEventStreamController.stream
        .listen(_handleVideoEvent);

    final fullScreenByDefault = betterPlayerConfiguration.fullScreenByDefault;
    if (betterPlayerConfiguration.autoPlay) {
      if (fullScreenByDefault && !isFullScreen) {
        enterFullScreen();
      }
      if (_isAutomaticPlayPauseHandled()) {
        if (_appLifecycleState == AppLifecycleState.resumed &&
            _isPlayerVisible) {
          await play();
        } else {
          _wasPlayingBeforePause = true;
        }
      } else {
        await play();
      }
    } else {
      if (fullScreenByDefault) {
        enterFullScreen();
      }
    }

    final startAt = betterPlayerConfiguration.startAt;
    if (startAt != null) {
      seekTo(startAt);
    }
  }

  ///Method which is invoked when full screen changes.
  Future<void> _onFullScreenStateChanged() async {
    if (videoPlayerController?.value.isPlaying == true && !_isFullScreen) {
      enterFullScreen();
      videoPlayerController?.removeListener(_onFullScreenStateChanged);
    }
  }

  ///Enables full screen mode in player. This will trigger route change.
  void enterFullScreen() {
    _isFullScreen = true;
    _postControllerEvent(BetterPlayerControllerEvent.openFullscreen);
  }

  ///Disables full screen mode in player. This will trigger route change.
  void exitFullScreen() {
    _isFullScreen = false;
    _postControllerEvent(BetterPlayerControllerEvent.hideFullscreen);
  }

  ///Enables/disables full screen mode based on current fullscreen state.
  void toggleFullScreen() {
    //if (_betterPlayerDataSource!.liveStream!) {
    _isFullScreen = !_isFullScreen;
    if (_isFullScreen) {
      _postControllerEvent(BetterPlayerControllerEvent.openFullscreen);
    } else {
      _postControllerEvent(BetterPlayerControllerEvent.hideFullscreen);
    }
    //  } else {}
  }

  ///Enables/disables full screen mode based on current fullscreen state.
  void exitPlayer() {
    if (_isFullScreen) {
      _postControllerEvent(BetterPlayerControllerEvent.exit);
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.exit));
    } else {
      _postControllerEvent(BetterPlayerControllerEvent.exit);
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.exit));
    }
  }

  ///Start video playback. Play will be triggered only if current lifecycle state
  ///is resumed.
  Future<void> play() async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    if (_appLifecycleState == AppLifecycleState.resumed) {
      await videoPlayerController!.play();
      _hasCurrentDataSourceStarted = true;
      _wasPlayingBeforePause = null;
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.play));
      _postControllerEvent(BetterPlayerControllerEvent.play);
    }
  }

  ///Enables/disables looping (infinity playback) mode.
  Future<void> setLooping(bool looping) async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    await videoPlayerController!.setLooping(looping);
  }

  ///Stop video playback.
  Future<void> pause() async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    await videoPlayerController!.pause();
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.pause));
  }

  ///Move player to specific position/moment of the video.
  Future<void> seekTo(Duration moment) async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    if (videoPlayerController?.value.duration == null) {
      throw StateError("The video has not been initialized yet.");
    }

    await videoPlayerController!.seekTo(moment);

    _postEvent(BetterPlayerEvent(BetterPlayerEventType.seekTo,
        parameters: <String, dynamic>{_durationParameter: moment}));

    final Duration? currentDuration = videoPlayerController!.value.duration;
    if (currentDuration == null) {
      return;
    }
    if (moment > currentDuration) {
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.finished));
    } else {
      cancelNextVideoTimer();
    }
  }

  ///Set volume of player. Allows values from 0.0 to 1.0.
  Future<void> setVolume(double volume) async {
    if (volume < 0.0 || volume > 1.0) {
      BetterPlayerUtils.log("Volume must be between 0.0 and 1.0");
      throw ArgumentError("Volume must be between 0.0 and 1.0");
    }
    if (videoPlayerController == null) {
      BetterPlayerUtils.log("The data source has not been initialized");
      throw StateError("The data source has not been initialized");
    }
    await videoPlayerController!.setVolume(volume);
    _postEvent(BetterPlayerEvent(
      BetterPlayerEventType.setVolume,
      parameters: <String, dynamic>{_volumeParameter: volume},
    ));
  }

  ///Set playback speed of video. Allows to set speed value between 0 and 2.
  Future<void> setSpeed(double speed) async {
    if (speed <= 0 || speed > 2) {
      BetterPlayerUtils.log("Speed must be between 0 and 2");
      throw ArgumentError("Speed must be between 0 and 2");
    }
    if (videoPlayerController == null) {
      BetterPlayerUtils.log("The data source has not been initialized");
      throw StateError("The data source has not been initialized");
    }
    await videoPlayerController?.setSpeed(speed);
    _postEvent(
      BetterPlayerEvent(
        BetterPlayerEventType.setSpeed,
        parameters: <String, dynamic>{
          _speedParameter: speed,
        },
      ),
    );
  }

  ///Flag which determines whenever player is playing or not.
  bool? isPlaying() {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    return videoPlayerController!.value.isPlaying;
  }

  ///Flag which determines whenever player is loading video data or not.
  bool? isBuffering() {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    return videoPlayerController!.value.isBuffering;
  }

  ///Show or hide controls manually
  void setControlsVisibility(bool isVisible) {
    _controlsVisibilityStreamController.add(isVisible);
  }

  ///Enable/disable controls (when enabled = false, controls will be always hidden)
  void setControlsEnabled(bool enabled) {
    if (!enabled) {
      _controlsVisibilityStreamController.add(false);
    }
    _controlsEnabled = enabled;
  }

  ///Internal method, used to trigger CONTROLS_VISIBLE or CONTROLS_HIDDEN event
  ///once controls state changed.
  void toggleControlsVisibility(bool isVisible) {
    _postEvent(isVisible
        ? BetterPlayerEvent(BetterPlayerEventType.controlsVisible)
        : BetterPlayerEvent(BetterPlayerEventType.controlsHiddenEnd));
  }

  ///Send player event. Shouldn't be used manually.
  void postEvent(BetterPlayerEvent betterPlayerEvent) {
    _postEvent(betterPlayerEvent);
  }

  ///Send player event to all listeners.
  void _postEvent(BetterPlayerEvent betterPlayerEvent) {
    for (final Function(BetterPlayerEvent)? eventListener in _eventListeners) {
      if (eventListener != null) {
        eventListener(betterPlayerEvent);
      }
    }
  }

  int _retryCount = 0;
  final int _maxRetryCount = 5; // Or 5 times
  ///Listener used to handle video player changes.
  void _onVideoPlayerChanged() async {
    final VideoPlayerValue currentVideoPlayerValue =
        videoPlayerController?.value ??
            VideoPlayerValue(duration: const Duration());

    if (currentVideoPlayerValue.hasError) {
      _videoPlayerValueOnError ??= currentVideoPlayerValue;
      _postEvent(
        BetterPlayerEvent(
          BetterPlayerEventType.exception,
          parameters: <String, dynamic>{
            "exception": currentVideoPlayerValue.errorDescription
          },
        ),
      );
      // 🚀 Automatically retry after short delay
      if (_retryCount < _maxRetryCount) {
        _retryCount++;
        Future.delayed(const Duration(seconds: 2), () {
          if (!_disposed) {
            retryDataSource();
          }
        });
      } else {
        print("Max retry attempts reached, not retrying further.");
      }
    }
    if (currentVideoPlayerValue.initialized &&
        !_hasCurrentDataSourceInitialized) {
      _hasCurrentDataSourceInitialized = true;
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.initialized));
    }
    if (currentVideoPlayerValue.isPip) {
      _wasInPipMode = true;
    } else if (_wasInPipMode) {
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.pipStop));
      _wasInPipMode = false;
      if (!_wasInFullScreenBeforePiP) {
        exitFullScreen();
      }
      if (_wasControlsEnabledBeforePiP) {
        setControlsEnabled(true);
      }
      videoPlayerController?.refresh();
    }

    if (_betterPlayerSubtitlesSource?.asmsIsSegmented == true) {
      _loadAsmsSubtitlesSegments(currentVideoPlayerValue.position);
    }

    final int now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPositionSelection > 500) {
      _lastPositionSelection = now;
      _postEvent(
        BetterPlayerEvent(
          BetterPlayerEventType.progress,
          parameters: <String, dynamic>{
            _progressParameter: currentVideoPlayerValue.position,
            _durationParameter: currentVideoPlayerValue.duration
          },
        ),
      );
    }
  }

  ///Add event listener which listens to player events.
  void addEventsListener(Function(BetterPlayerEvent) eventListener) {
    _eventListeners.add(eventListener);
  }

  ///Remove event listener. This method should be called once you're disposing
  ///Better Player.
  void removeEventsListener(Function(BetterPlayerEvent) eventListener) {
    _eventListeners.remove(eventListener);
  }

  ///Flag which determines whenever player is playing live data source.
  bool isLiveStream() {
    if (_betterPlayerDataSource == null) {
      BetterPlayerUtils.log("The data source has not been initialized");
      throw StateError("The data source has not been initialized");
    }
    return _betterPlayerDataSource!.liveStream == true;
  }

  ///Flag which determines whenever player data source has been initialized.
  bool? isVideoInitialized() {
    if (videoPlayerController == null) {
      BetterPlayerUtils.log("The data source has not been initialized");
      throw StateError("The data source has not been initialized");
    }
    return videoPlayerController?.value.initialized;
  }

  ///Start timer which will trigger next video. Used in playlist. Do not use
  ///manually.
  void startNextVideoTimer() {
    if (_nextVideoTimer == null) {
      if (betterPlayerPlaylistConfiguration == null) {
        BetterPlayerUtils.log(
            "BettterPlayerPlaylistConifugration has not been set!");
        throw StateError(
            "BettterPlayerPlaylistConifugration has not been set!");
      }

      _nextVideoTime =
          betterPlayerPlaylistConfiguration!.nextVideoDelay.inSeconds;
      _nextVideoTimeStreamController.add(_nextVideoTime);
      if (_nextVideoTime == 0) {
        return;
      }

      _nextVideoTimer =
          Timer.periodic(const Duration(milliseconds: 1000), (_timer) async {
        if (_nextVideoTime == 1) {
          _timer.cancel();
          _nextVideoTimer = null;
        }
        if (_nextVideoTime != null) {
          _nextVideoTime = _nextVideoTime! - 1;
        }
        _nextVideoTimeStreamController.add(_nextVideoTime);
      });
    }
  }

  ///Cancel next video timer. Used in playlist. Do not use manually.
  void cancelNextVideoTimer() {
    _nextVideoTime = null;
    _nextVideoTimeStreamController.add(_nextVideoTime);
    _nextVideoTimer?.cancel();
    _nextVideoTimer = null;
  }

  ///Play next video form playlist. Do not use manually.
  void playNextVideo() {
    _nextVideoTime = 0;
    _nextVideoTimeStreamController.add(_nextVideoTime);
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.changedPlaylistItem));
    cancelNextVideoTimer();
  }

  ///Setup track parameters for currently played video. Can be only used for HLS or DASH
  ///data source.
  void setTrack(BetterPlayerAsmsTrack track) {
    if (videoPlayerController == null) {
      print("failed changed Track ");

      throw StateError("The data source has not been initialized");
    }
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.changedTrack,
        parameters: <String, dynamic>{
          "id": track.id,
          "width": track.width,
          "height": track.height,
          "bitrate": track.bitrate,
          "frameRate": track.frameRate,
          "codecs": track.codecs,
          "mimeType": track.mimeType,
        }));

    videoPlayerController!
        .setTrackParameters(track.width, track.height, track.bitrate);
    _betterPlayerAsmsTrack = track;
    print("changed Track ${track.width}, ${track.height}");
  }

  ///Check if player can be played/paused automatically
  bool _isAutomaticPlayPauseHandled() {
    return !(_betterPlayerDataSource
                ?.notificationConfiguration?.showNotification ==
            true) &&
        betterPlayerConfiguration.handleLifecycle;
  }

  ///Listener which handles state of player visibility. If player visibility is
  ///below 0.0 then video will be paused. When value is greater than 0, video
  ///will play again. If there's different handler of visibility then it will be
  ///used. If showNotification is set in data source or handleLifecycle is false
  /// then this logic will be ignored.
  void onPlayerVisibilityChanged(double visibilityFraction) async {
    _isPlayerVisible = visibilityFraction > 0;
    if (_disposed) {
      return;
    }
    _postEvent(
        BetterPlayerEvent(BetterPlayerEventType.changedPlayerVisibility));

    if (_isAutomaticPlayPauseHandled()) {
      if (betterPlayerConfiguration.playerVisibilityChangedBehavior != null) {
        betterPlayerConfiguration
            .playerVisibilityChangedBehavior!(visibilityFraction);
      } else {
        if (visibilityFraction == 0) {
          _wasPlayingBeforePause ??= isPlaying();
          pause();
        } else {
          if (_wasPlayingBeforePause == true && !isPlaying()!) {
            play();
          }
        }
      }
    }
  }

  ///Set different resolution (quality) for video
  void setResolution(String url) async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    final position = await videoPlayerController!.position;
    final wasPlayingBeforeChange = isPlaying()!;
    pause();
    await setupDataSource(betterPlayerDataSource!.copyWith(url: url));
    seekTo(position!);
    if (wasPlayingBeforeChange) {
      play();
    }
    _postEvent(BetterPlayerEvent(
      BetterPlayerEventType.changedResolution,
      parameters: <String, dynamic>{"url": url},
    ));
  }

  ///Setup translations for given locale. In normal use cases it shouldn't be
  ///called manually.
  void setupTranslations(Locale locale) {
    // ignore: unnecessary_null_comparison
    if (locale != null) {
      final String languageCode = locale.languageCode;
      translations = betterPlayerConfiguration.translations?.firstWhereOrNull(
              (translations) => translations.languageCode == languageCode) ??
          _getDefaultTranslations(locale);
    } else {
      BetterPlayerUtils.log("Locale is null. Couldn't setup translations.");
    }
  }

  ///Setup default translations for selected user locale. These translations
  ///are pre-build in.
  BetterPlayerTranslations _getDefaultTranslations(Locale locale) {
    final String languageCode = locale.languageCode;
    switch (languageCode) {
      case "pl":
        return BetterPlayerTranslations.polish();
      case "zh":
        return BetterPlayerTranslations.chinese();
      case "hi":
        return BetterPlayerTranslations.hindi();
      case "tr":
        return BetterPlayerTranslations.turkish();
      case "vi":
        return BetterPlayerTranslations.vietnamese();
      case "es":
        return BetterPlayerTranslations.spanish();
      default:
        return BetterPlayerTranslations();
    }
  }

  ///Flag which determines whenever current data source has started.
  bool get hasCurrentDataSourceStarted => _hasCurrentDataSourceStarted;

  ///Set current lifecycle state. If state is [AppLifecycleState.resumed] then
  ///player starts playing again. if lifecycle is in [AppLifecycleState.paused]
  ///state, then video playback will stop. If showNotification is set in data
  ///source or handleLifecycle is false then this logic will be ignored.
  void setAppLifecycleState(AppLifecycleState appLifecycleState) {
    if (_isAutomaticPlayPauseHandled()) {
      _appLifecycleState = appLifecycleState;

      // NEW: Don't pause video if PiP is active
      final isPipActive = _wasInPipMode; // Add this tracking variable

      if (appLifecycleState == AppLifecycleState.resumed) {
        if (_wasPlayingBeforePause == true &&
            _isPlayerVisible &&
            !isPipActive) {
          play();
        }
      }
      if (appLifecycleState == AppLifecycleState.paused) {
        // NEW: Only pause if NOT in PiP mode
        if (!isPipActive) {
          _wasPlayingBeforePause ??= isPlaying();
          pause();
        }
      }
    }
  }

  // ignore: use_setters_to_change_properties
  ///Setup overridden aspect ratio.
  void setOverriddenAspectRatio(double aspectRatio) {
    _overriddenAspectRatio = aspectRatio;
  }

  ///Get aspect ratio used in current video. If aspect ratio is null, then
  ///aspect ratio from BetterPlayerConfiguration will be used. Otherwise
  ///[_overriddenAspectRatio] will be used.
  double? getAspectRatio() {
    return _overriddenAspectRatio ?? betterPlayerConfiguration.aspectRatio;
  }

  // ignore: use_setters_to_change_properties
  ///Setup overridden fit.
  void setOverriddenFit(BoxFit fit) {
    _overriddenFit = fit;
  }

  ///Get fit used in current video. If fit is null, then fit from
  ///BetterPlayerConfiguration will be used. Otherwise [_overriddenFit] will be
  ///used.
  BoxFit getFit() {
    return _overriddenFit ?? betterPlayerConfiguration.fit;
  }

  ///Enable Picture in Picture mode. Requires a global key of BetterPlayer widget.
  ///Supported on iOS 14.0+ and Android 8.0+ with sufficient system requirements.
  ///Works with all video formats including HLS/m3u8.
  ///Now supports PiP activation from both normal and fullscreen modes.
  Future<void> enablePictureInPicture(GlobalKey betterPlayerGlobalKey) async {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    _betterPlayerGlobalKey = betterPlayerGlobalKey;

    final bool isPipSupported = await isPictureInPictureSupported();
    if (isPipSupported) {
      BetterPlayerUtils.log("Hiding controls before PiP activation");
      setControlsVisibility(false);
      // NEW: Set PiP state BEFORE enabling
      _isPipActive = true;
      _wasInPipMode = true;
      // Add small delay to ensure controls are fully hidden before PiP capture
      await Future.delayed(Duration(milliseconds: 100));
      if (Platform.isAndroid) {
        // Android implementation - supports PiP from any mode
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.pipStart));
        return videoPlayerController?.enablePictureInPicture();
      }

      if (Platform.isIOS) {
        // iOS implementation for both iPhone and iPad - supports PiP from any mode
        final RenderBox? renderBox = betterPlayerGlobalKey.currentContext!
            .findRenderObject() as RenderBox?;
        if (renderBox == null) {
          BetterPlayerUtils.log(
              "Can't show PiP. RenderBox is null. Did you provide valid global key?");
          return;
        }

        final Offset position = renderBox.localToGlobal(Offset.zero);
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.pipStart));

        return videoPlayerController?.enablePictureInPicture(
          left: position.dx,
          top: position.dy,
          width: renderBox.size.width,
          height: renderBox.size.height,
        );
      } else {
        BetterPlayerUtils.log(
            "Unsupported PiP in current platform."); // Restore controls if platform not supported
        setControlsVisibility(true);
      }
    } else {
      BetterPlayerUtils.log(
          "Picture in picture is not supported in this device. "
          "Requirements: iOS 14.0+ or Android 8.0+ with sufficient RAM and v2 embedding.");
      // Restore controls if PiP not supported
      setControlsVisibility(true);
    }
  }

  ///Disable Picture in Picture mode if it's enabled.
  Future<void>? disablePictureInPicture() {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }
    // NEW: Reset PiP state
    _isPipActive = false;
    _wasInPipMode = false;
    // 🚀 SOLUTION: Show controls when PiP is manually disabled
    BetterPlayerUtils.log("Showing controls after PiP disable");
    setControlsVisibility(true);
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.pipStop));
    return videoPlayerController!.disablePictureInPicture();
  }

  // ignore: use_setters_to_change_properties
  ///Set GlobalKey of BetterPlayer. Used in PiP methods called from controls.
  void setBetterPlayerGlobalKey(GlobalKey betterPlayerGlobalKey) {
    _betterPlayerGlobalKey = betterPlayerGlobalKey;
  }

  ///Check if picture in picture mode is supported in this device.
  ///Now supports PiP in both normal and fullscreen modes.
  Future<bool> isPictureInPictureSupported() async {
    if (videoPlayerController == null) {
      return false;
    }

    final bool isPipSupported =
        (await videoPlayerController!.isPictureInPictureSupported()) ?? false;

    // PiP is now supported in both fullscreen and normal modes
    return isPipSupported;
  }

  ///Enhanced method to handle PiP state changes and cleanup
  ///Now properly handles fullscreen transitions when PiP is enabled/disabled
  void _handlePictureInPictureStateChange(bool isInPip) {
    if (isInPip) {
      // Store current fullscreen state before entering PiP
      _wasInFullscreenBeforePip = _isFullScreen;
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.pipStart));
    } else {
      _postEvent(BetterPlayerEvent(BetterPlayerEventType.pipStop));

      // On Android, handle fullscreen state restoration based on previous state
      if (Platform.isAndroid) {
        // If PiP was started from normal mode and we want to return to normal mode
        if (!_wasInFullscreenBeforePip && _isFullScreen) {
          exitFullScreen();
        }
        // If PiP was started from fullscreen mode, remain in fullscreen
        // This preserves user's original viewing preference
      }
    }
  }

  ///Handle VideoEvent when remote controls notification / PiP is shown
  void _handleVideoEvent(VideoEvent event) async {
    switch (event.eventType) {
      case VideoEventType.play:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.play));
        break;
      case VideoEventType.pause:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.pause));
        break;
      case VideoEventType.seek:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.seekTo));
        break;
      case VideoEventType.completed:
        final VideoPlayerValue? videoValue = videoPlayerController?.value;
        _postEvent(
          BetterPlayerEvent(
            BetterPlayerEventType.finished,
            parameters: <String, dynamic>{
              _progressParameter: videoValue?.position,
              _durationParameter: videoValue?.duration
            },
          ),
        );
        break;
      case VideoEventType.bufferingStart:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.bufferingStart));
        break;
      case VideoEventType.bufferingUpdate:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.bufferingUpdate,
            parameters: <String, dynamic>{
              _bufferedParameter: event.buffered,
            }));
        break;
      case VideoEventType.bufferingEnd:
        _postEvent(BetterPlayerEvent(BetterPlayerEventType.bufferingEnd));
        break;
      default:

        ///TODO: Handle when needed
        break;
    }
  }

  ///Setup controls always visible mode
  void setControlsAlwaysVisible(bool controlsAlwaysVisible) {
    _controlsAlwaysVisible = controlsAlwaysVisible;
    _controlsVisibilityStreamController.add(controlsAlwaysVisible);
  }

  ///Retry data source if playback failed.
  Future retryDataSource() async {
    await _setupDataSource(_betterPlayerDataSource!);
    if (_videoPlayerValueOnError != null) {
      final position = _videoPlayerValueOnError!.position;
      await seekTo(position);
      await play();
      _videoPlayerValueOnError = null;
    }
  }

  ///Set [audioTrack] in player. Works only for HLS or DASH streams.
  void setAudioTrack(BetterPlayerAsmsAudioTrack audioTrack) {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    if (audioTrack.language == null) {
      _betterPlayerAsmsAudioTrack = null;
      return;
    }

    _betterPlayerAsmsAudioTrack = audioTrack;
    videoPlayerController!.setAudioTrack(audioTrack.label, audioTrack.id);
  }

  ///Enable or disable audio mixing with other sound within device.
  void setMixWithOthers(bool mixWithOthers) {
    if (videoPlayerController == null) {
      throw StateError("The data source has not been initialized");
    }

    videoPlayerController!.setMixWithOthers(mixWithOthers);
  }

  ///Clear all cached data. Video player controller must be initialized to
  ///clear the cache.
  Future<void> clearCache() async {
    return VideoPlayerController.clearCache();
  }

  ///Build headers map that will be used to setup video player controller. Apply
  ///DRM headers if available.
  Map<String, String?> _getHeaders() {
    final headers = betterPlayerDataSource!.headers ?? {};
    if (betterPlayerDataSource?.drmConfiguration?.drmType ==
            BetterPlayerDrmType.token &&
        betterPlayerDataSource?.drmConfiguration?.token != null) {
      headers[_authorizationHeader] =
          betterPlayerDataSource!.drmConfiguration!.token!;
    }
    return headers;
  }

  ///PreCache a video. On Android, the future succeeds when
  ///the requested size, specified in
  ///[BetterPlayerCacheConfiguration.preCacheSize], is downloaded or when the
  ///complete file is downloaded if the file is smaller than the requested size.
  ///On iOS, the whole file will be downloaded, since [maxCacheFileSize] is
  ///currently not supported on iOS. On iOS, the video format must be in this
  ///list: https://github.com/sendyhalim/Swime/blob/master/Sources/MimeType.swift
  Future<void> preCache(BetterPlayerDataSource betterPlayerDataSource) async {
    final cacheConfig = betterPlayerDataSource.cacheConfiguration ??
        const BetterPlayerCacheConfiguration(useCache: true);

    final dataSource = DataSource(
      sourceType: DataSourceType.network,
      uri: betterPlayerDataSource.url,
      useCache: true,
      headers: betterPlayerDataSource.headers,
      maxCacheSize: cacheConfig.maxCacheSize,
      maxCacheFileSize: cacheConfig.maxCacheFileSize,
      cacheKey: cacheConfig.key,
      videoExtension: betterPlayerDataSource.videoExtension,
    );

    return VideoPlayerController.preCache(dataSource, cacheConfig.preCacheSize);
  }

  ///Stop pre cache for given [betterPlayerDataSource]. If there was no pre
  ///cache started for given [betterPlayerDataSource] then it will be ignored.
  Future<void> stopPreCache(
      BetterPlayerDataSource betterPlayerDataSource) async {
    return VideoPlayerController.stopPreCache(betterPlayerDataSource.url,
        betterPlayerDataSource.cacheConfiguration?.key);
  }

  /// Sets the new [betterPlayerControlsConfiguration] instance in the
  /// controller.
  void setBetterPlayerControlsConfiguration(
      BetterPlayerControlsConfiguration betterPlayerControlsConfiguration) {
    this._betterPlayerControlsConfiguration = betterPlayerControlsConfiguration;
  }

  ///////////////////
  /// Add controller internal event.
  void _postControllerEvent(BetterPlayerControllerEvent event) {
    if (!_controllerEventStreamController.isClosed) {
      _controllerEventStreamController.add(event);
    }
  }

  ///Dispose BetterPlayerController. When [forceDispose] parameter is true, then
  ///autoDispose parameter will be overridden and controller will be disposed
  ///(if it wasn't disposed before).
  void dispose({bool forceDispose = false}) {
    if (!betterPlayerConfiguration.autoDispose && !forceDispose) {
      return;
    }
    if (!_disposed) {
      if (videoPlayerController != null) {
        pause();
        videoPlayerController!.removeListener(_onFullScreenStateChanged);
        videoPlayerController!.removeListener(_onVideoPlayerChanged);
        videoPlayerController!.dispose();
      }
      _eventListeners.clear();
      _nextVideoTimer?.cancel();
      _nextVideoTimeStreamController.close();
      _controlsVisibilityStreamController.close();
      _videoEventStreamSubscription?.cancel();
      _disposed = true;
      _controllerEventStreamController.close();
      _thumbnailPreviewController.close();

      ///Delete files async
      _tempFiles.forEach((file) => file.delete());
    }
  }
}

// ===== ENHANCED VIDEO PROGRESS INDICATOR WITH THUMBNAILS =====
class ThumbnailVideoProgressIndicator extends StatefulWidget {
  final BetterPlayerController controller;
  final VideoProgressColors? colors;
  final EdgeInsets padding;
  final bool allowScrubbing;
  final double? height;

  const ThumbnailVideoProgressIndicator(
    this.controller, {
    Key? key,
    this.colors,
    this.padding = const EdgeInsets.only(top: 5.0),
    this.allowScrubbing = true,
    this.height,
  }) : super(key: key);

  @override
  State<ThumbnailVideoProgressIndicator> createState() =>
      _ThumbnailVideoProgressIndicatorState();
}

class _ThumbnailVideoProgressIndicatorState
    extends State<ThumbnailVideoProgressIndicator> {
  BetterPlayerVideoThumbnail? _currentThumbnail;
  OverlayEntry? _overlayEntry;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    widget.controller.videoPlayerController?.addListener(_updateState);
    widget.controller.thumbnailPreviewStream.listen(_onThumbnailPreview);
  }

  @override
  void dispose() {
    widget.controller.videoPlayerController?.removeListener(_updateState);
    _removeOverlay();
    super.dispose();
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onThumbnailPreview(BetterPlayerVideoThumbnail? thumbnail) {
    _currentThumbnail = thumbnail;
    if (thumbnail != null && _isDragging) {
      _showThumbnailOverlay(thumbnail);
    } else {
      _removeOverlay();
    }
  }

  void _showThumbnailOverlay(BetterPlayerVideoThumbnail thumbnail) {
    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.memory(
                    thumbnail.imageData,
                    width: thumbnail.width.toDouble(),
                    height: thumbnail.height.toDouble(),
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(thumbnail.timePosition),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)?.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    } else {
      return '${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? 20,
      child: GestureDetector(
        onPanStart: (details) {
          if (!widget.allowScrubbing) return;
          _isDragging = true;
          _handleSeekGesture(details.localPosition);
        },
        onPanUpdate: (details) {
          if (!widget.allowScrubbing || !_isDragging) return;
          _handleSeekGesture(details.localPosition);
        },
        onPanEnd: (details) {
          _isDragging = false;
          widget.controller.hideThumbnailPreview();
        },
        onTapDown: (details) {
          if (!widget.allowScrubbing) return;
          _handleSeekGesture(details.localPosition);
        },
        child: _buildProgressBar(),
      ),
    );
  }

  void _handleSeekGesture(Offset localPosition) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final double relative = localPosition.dx / renderBox.size.width;
    final double clampedRelative = relative.clamp(0.0, 1.0);

    final duration = widget.controller.videoPlayerController?.value.duration;
    if (duration != null) {
      final position = duration * clampedRelative;

      if (_isDragging) {
        // Show thumbnail preview while dragging
        widget.controller.showThumbnailPreview(position);
      }

      // Seek to position
      widget.controller.seekTo(position);
    }
  }

  Widget _buildProgressBar() {
    final controller = widget.controller.videoPlayerController;
    final colors = widget.colors ?? VideoProgressColors();

    if (controller?.value.initialized != true) {
      return Container(
        decoration: BoxDecoration(
          color: colors.backgroundColor,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    final duration = controller!.value.duration!.inMilliseconds.toDouble();
    final position = controller.value.position.inMilliseconds.toDouble();

    double bufferedPosition = 0.0;
    for (final range in controller.value.buffered) {
      final end = range.end.inMilliseconds.toDouble();
      if (end > bufferedPosition) {
        bufferedPosition = end;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          // Background
          Container(
            width: double.infinity,
            height: widget.height ?? 20,
            decoration: BoxDecoration(
              color: colors.backgroundColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Buffered progress
          FractionallySizedBox(
            widthFactor: bufferedPosition / duration,
            child: Container(
              height: widget.height ?? 20,
              decoration: BoxDecoration(
                color: colors.bufferedColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Played progress
          FractionallySizedBox(
            widthFactor: position / duration,
            child: Container(
              height: widget.height ?? 20,
              decoration: BoxDecoration(
                color: colors.playedColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Thumbnail markers (if thumbnails are ready)
          if (widget.controller.thumbnailsReady)
            _buildThumbnailMarkers(duration),
        ],
      ),
    );
  }

  Widget _buildThumbnailMarkers(double duration) {
    return Positioned.fill(
      child: Row(
        children: List.generate(
          10, // Show 10 markers
          (index) {
            final progress = (index + 1) / 11; // Avoid 0 and 1
            return Expanded(
              child: Container(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 1,
                  height: (widget.height ?? 20) * 0.5,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
