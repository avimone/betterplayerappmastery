// better_player_business_logic.dart
import 'dart:async';
import 'dart:io';
import 'package:better_player/better_player.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Business logic layer for Better Player
/// Handles all complex operations and keeps them separate from UI
class BetterPlayerBusinessLogic {
  final BetterPlayerState state;
  final BetterPlayerConfiguration configuration;

  VideoPlayerController? _videoController;
  StreamSubscription? _videoEventSubscription;
  Timer? _positionTimer;
  Timer? _retryTimer;
  final List<File> _tempFiles = [];

  // Callbacks
  Function(BetterPlayerEvent)? onEvent;

  BetterPlayerBusinessLogic({
    required this.state,
    required this.configuration,
    this.onEvent,
  });

  VideoPlayerController? get videoController => _videoController;

  /// Initialize a data source
  Future<void> setupDataSource(BetterPlayerDataSource dataSource) async {
    try {
      // Clean up previous source
      await _cleanup();

      // Update state
      state.setDataSource(dataSource);

      // Initialize video controller if needed
      _videoController ??= VideoPlayerController(
        bufferingConfiguration: dataSource.bufferingConfiguration,
      );

      // Set up listeners
      _setupVideoControllerListeners();

      // Handle different source types
      if (_isAsmsSource(dataSource)) {
        await _setupAsmsDataSource(dataSource);
      }

      // Setup subtitles
      await _setupSubtitles(dataSource);

      // Initialize the video source
      await _initializeVideoSource(dataSource);

      // Apply initial configuration
      await _applyInitialConfiguration();
    } catch (e) {
      _handleError(e, ErrorType.playback);
    }
  }

  /// Play video
  Future<void> play() async {
    if (_videoController == null || !state.canPlay) return;

    try {
      await _videoController!.play();
      state.setPlaying(true);
      _startPositionTimer();
    } catch (e) {
      _handleError(e, ErrorType.playback);
    }
  }

  /// Pause video
  Future<void> pause() async {
    if (_videoController == null) return;

    try {
      await _videoController!.pause();
      state.setPlaying(false);
      _stopPositionTimer();
    } catch (e) {
      _handleError(e, ErrorType.playback);
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    if (_videoController == null) return;

    try {
      await _videoController!.seekTo(position);

      // Emit seek event
      onEvent?.call(BetterPlayerEvent(
        BetterPlayerEventType.seekTo,
        parameters: {"duration": position},
      ));

      // Cancel next video timer if seeking backwards
      if (position < state.position) {
        _cancelNextVideoTimer();
      }
    } catch (e) {
      _handleError(e, ErrorType.playback);
    }
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    if (_videoController == null) return;

    try {
      await _videoController!.setVolume(volume);
      state.setVolume(volume);
    } catch (e) {
      _handleError(e, ErrorType.playback);
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    if (_videoController == null) return;

    try {
      await _videoController!.setSpeed(speed);
      state.setPlaybackSpeed(speed);
    } catch (e) {
      _handleError(e, ErrorType.playback);
    }
  }

  /// Toggle fullscreen
  void toggleFullScreen() {
    state.setFullScreen(!state.isFullScreen);
  }

  /// Set track (quality)
  Future<void> setTrack(BetterPlayerAsmsTrack track) async {
    if (_videoController == null) return;

    try {
      await _videoController!.setTrackParameters(
        track.width,
        track.height,
        track.bitrate,
      );
      state.selectTrack(track);
    } catch (e) {
      _handleError(e, ErrorType.playback);
    }
  }

  /// Set audio track
  Future<void> setAudioTrack(BetterPlayerAsmsAudioTrack track) async {
    if (_videoController == null) return;

    try {
      _videoController!.setAudioTrack(track.label, track.id);
      state.selectAudioTrack(track);
    } catch (e) {
      _handleError(e, ErrorType.playback);
    }
  }

  /// Setup subtitle source
  Future<void> setupSubtitleSource(BetterPlayerSubtitlesSource source) async {
    try {
      state.selectSubtitleSource(source);

      if (source.type != BetterPlayerSubtitlesSourceType.none) {
        // Parse subtitles based on source type
        final subtitles =
            await BetterPlayerSubtitlesFactory.parseSubtitles(source);
        state.updateSubtitles(subtitles);
      } else {
        state.updateSubtitles([]);
      }
    } catch (e) {
      _handleError(e, ErrorType.format);
    }
  }

  /// Retry failed playback
  Future<void> retry() async {
    if (!state.canRetry || state.dataSource == null) return;

    state.incrementRetryCount();
    state.clearError();

    // Wait before retrying
    _retryTimer = Timer(const Duration(seconds: 2), () async {
      await setupDataSource(state.dataSource!);

      // Restore position if available
      if (state.videoValue?.position != null) {
        await seekTo(state.videoValue!.position);
      }

      // Resume playback if was playing
      if (state.isPlaying) {
        await play();
      }
    });
  }

  /// Enable picture in picture
  Future<void> enablePictureInPicture(GlobalKey playerKey) async {
    if (_videoController == null) return;

    try {
      final renderBox =
          playerKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;

      final position = renderBox.localToGlobal(Offset.zero);
      await _videoController!.enablePictureInPicture(
        top: position.dy,
        left: position.dx,
        width: renderBox.size.width,
        height: renderBox.size.height,
      );
    } catch (e) {
      BetterPlayerUtils.log("PiP error: $e");
    }
  }

  /// Dispose and cleanup
  Future<void> dispose() async {
    await _cleanup();
    _retryTimer?.cancel();
    await _videoController?.dispose();

    // Delete temp files
    for (final file in _tempFiles) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  // Private methods

  void _setupVideoControllerListeners() {
    _videoController!.addListener(_onVideoControllerUpdate);

    _videoEventSubscription?.cancel();
    _videoEventSubscription = _videoController!
        .videoEventStreamController.stream
        .listen(_handleVideoEvent);
  }

  void _onVideoControllerUpdate() {
    final value = _videoController!.value;
    state.updateVideoValue(value);

    // Check if video finished
    if (value.position >= value.duration && value.duration != Duration.zero) {
      onEvent?.call(BetterPlayerEvent(BetterPlayerEventType.finished));
    }
  }

  void _handleVideoEvent(VideoEvent event) {
    switch (event.eventType) {
      case VideoEventType.initialized:
        state.setBuffering(false);
        break;
      case VideoEventType.bufferingStart:
        state.setBuffering(true);
        break;
      case VideoEventType.bufferingEnd:
        state.setBuffering(false);
        break;
      case VideoEventType.completed:
        onEvent?.call(BetterPlayerEvent(BetterPlayerEventType.finished));
        break;
      default:
        break;
    }
  }

  bool _isAsmsSource(BetterPlayerDataSource dataSource) {
    return BetterPlayerAsmsUtils.isDataSourceAsms(dataSource.url) ||
        dataSource.videoFormat == BetterPlayerVideoFormat.hls ||
        dataSource.videoFormat == BetterPlayerVideoFormat.dash;
  }

  Future<void> _setupAsmsDataSource(BetterPlayerDataSource dataSource) async {
    try {
      final data = await BetterPlayerAsmsUtils.getDataFromUrl(
        dataSource.url,
        dataSource.headers,
      );

      if (data != null) {
        final asmsData =
            await BetterPlayerAsmsUtils.parse(data, dataSource.url);

        // Set tracks
        if (dataSource.useAsmsTracks == true) {
          state.setTracks(asmsData.tracks ?? []);
        }

        // Set audio tracks
        if (dataSource.useAsmsAudioTracks == true) {
          state.setAudioTracks(asmsData.audios ?? []);
        }

        // Add ASMS subtitles
        if (dataSource.useAsmsSubtitles == true) {
          final subtitleSources = <BetterPlayerSubtitlesSource>[];
          for (final subtitle
              in asmsData.subtitles ?? <BetterPlayerAsmsSubtitle>[]) {
            subtitleSources.add(BetterPlayerSubtitlesSource(
              type: BetterPlayerSubtitlesSourceType.network,
              name: subtitle.name,
              urls: subtitle.realUrls,
              selectedByDefault: subtitle.isDefault,
            ));
          }
          state.setSubtitlesSources(subtitleSources);
        }
      }
    } catch (e) {
      BetterPlayerUtils.log("ASMS setup error: $e");
    }
  }

  Future<void> _setupSubtitles(BetterPlayerDataSource dataSource) async {
    final sources = <BetterPlayerSubtitlesSource>[];

    // Add data source subtitles
    if (dataSource.subtitles != null) {
      sources.addAll(dataSource.subtitles!);
    }

    // Add existing ASMS subtitles
    sources.addAll(state.subtitlesSources);

    state.setSubtitlesSources(sources);

    // Select default subtitle
    final defaultSubtitle = sources.firstWhere(
      (s) => s.selectedByDefault == true,
      orElse: () => sources.last, // None option
    );

    await setupSubtitleSource(defaultSubtitle);
  }

  Future<void> _initializeVideoSource(BetterPlayerDataSource dataSource) async {
    switch (dataSource.type) {
      case BetterPlayerDataSourceType.network:
        await _videoController!.setNetworkDataSource(
          dataSource.url,
          headers: dataSource.headers,
          useCache: dataSource.cacheConfiguration?.useCache ?? false,
          maxCacheSize: dataSource.cacheConfiguration?.maxCacheSize ?? 0,
          maxCacheFileSize:
              dataSource.cacheConfiguration?.maxCacheFileSize ?? 0,
          cacheKey: dataSource.cacheConfiguration?.key,
          showNotification:
              dataSource.notificationConfiguration?.showNotification,
          title: dataSource.notificationConfiguration?.title,
          author: dataSource.notificationConfiguration?.author,
          imageUrl: dataSource.notificationConfiguration?.imageUrl,
          notificationChannelName:
              dataSource.notificationConfiguration?.notificationChannelName,
          overriddenDuration: dataSource.overriddenDuration,
          formatHint: _getVideoFormat(dataSource.videoFormat),
          licenseUrl: dataSource.drmConfiguration?.licenseUrl,
          certificateUrl: dataSource.drmConfiguration?.certificateUrl,
          drmHeaders: dataSource.drmConfiguration?.headers,
          clearKey: dataSource.drmConfiguration?.clearKey,
          videoExtension: dataSource.videoExtension,
        );
        break;

      case BetterPlayerDataSourceType.file:
        final file = File(dataSource.url);
        if (!file.existsSync()) {
          throw Exception("File not found: ${dataSource.url}");
        }
        await _videoController!.setFileDataSource(
          file,
          showNotification:
              dataSource.notificationConfiguration?.showNotification,
          title: dataSource.notificationConfiguration?.title,
          author: dataSource.notificationConfiguration?.author,
          imageUrl: dataSource.notificationConfiguration?.imageUrl,
          notificationChannelName:
              dataSource.notificationConfiguration?.notificationChannelName,
          overriddenDuration: dataSource.overriddenDuration,
        );
        break;

      case BetterPlayerDataSourceType.memory:
        final file =
            await _createTempFile(dataSource.bytes!, dataSource.videoExtension);
        _tempFiles.add(file);
        await _videoController!.setFileDataSource(file);
        break;
    }
  }

  Future<void> _applyInitialConfiguration() async {
    // Set looping
    await _videoController!.setLooping(configuration.looping);

    // Auto play if configured
    if (configuration.autoPlay) {
      await play();
    }

    // Seek to start position if configured
    if (configuration.startAt != null) {
      await seekTo(configuration.startAt!);
    }
  }

  Future<File> _createTempFile(List<int> bytes, String? extension) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/bp_${DateTime.now().millisecondsSinceEpoch}.${extension ?? "tmp"}');
    await file.writeAsBytes(bytes);
    return file;
  }

  VideoFormat? _getVideoFormat(BetterPlayerVideoFormat? format) {
    if (format == null) return null;
    switch (format) {
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

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      // Position updates are handled by video controller listener
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _cancelNextVideoTimer() {
    // Implement if using playlist
  }

  void _handleError(dynamic error, ErrorType type) {
    String message = error.toString();
    String? code;

    if (error is PlatformException) {
      message = error.message ?? error.toString();
      code = error.code;
    }

    final playerError = BetterPlayerError(
      type: type,
      message: message,
      code: code,
      details: error,
    );

    state.setError(playerError);

    // Auto retry for recoverable errors
    if (playerError.isRecoverable && state.canRetry) {
      retry();
    }
  }

  Future<void> _cleanup() async {
    _stopPositionTimer();
    _videoEventSubscription?.cancel();
    _videoController?.removeListener(_onVideoControllerUpdate);
  }
}
