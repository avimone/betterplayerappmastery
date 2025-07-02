// better_player_controller_v2.dart
import 'dart:async';
import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

/// Improved BetterPlayerController with clean separation of concerns
class BetterPlayerController extends ChangeNotifier {
  /// Configuration
  final BetterPlayerConfiguration betterPlayerConfiguration;
  final BetterPlayerPlaylistConfiguration? betterPlayerPlaylistConfiguration;

  /// State management
  late final BetterPlayerState _state;
  late final BetterPlayerBusinessLogic _logic;

  /// Event listeners
  final List<Function(BetterPlayerEvent)?> _eventListeners = [];

  /// Global key for player widget
  GlobalKey? _betterPlayerGlobalKey;

  /// Lifecycle
  bool _isDisposed = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  /// Previous state for lifecycle management
  bool? _wasPlayingBeforePause;
  bool _isPlayerVisible = true;

  /// Playlist support
  Timer? _nextVideoTimer;
  int? _nextVideoTime;
  final _nextVideoTimeController = StreamController<int?>.broadcast();

  BetterPlayerController(
    this.betterPlayerConfiguration, {
    this.betterPlayerPlaylistConfiguration,
    BetterPlayerDataSource? betterPlayerDataSource,
  }) {
    // Initialize state
    _state = BetterPlayerState(configuration: betterPlayerConfiguration);

    // Initialize business logic
    _logic = BetterPlayerBusinessLogic(
      state: _state,
      configuration: betterPlayerConfiguration,
      onEvent: _handleBusinessLogicEvent,
    );

    // Add default event listener
    if (betterPlayerConfiguration.eventListener != null) {
      _eventListeners.add(betterPlayerConfiguration.eventListener);
    }

    // Setup initial data source if provided
    if (betterPlayerDataSource != null) {
      setupDataSource(betterPlayerDataSource);
    }

    // Listen to state changes
    _state.addListener(_onStateChanged);
  }

  // Public getters - delegate to state
  BetterPlayerState get state => _state;
  VideoPlayerController? get videoPlayerController => _logic.videoController;
  bool get isFullScreen => _state.isFullScreen;
  BetterPlayerDataSource? get betterPlayerDataSource => _state.dataSource;
  List<BetterPlayerAsmsTrack> get betterPlayerAsmsTracks => _state.tracks;
  BetterPlayerAsmsTrack? get betterPlayerAsmsTrack => _state.selectedTrack;
  List<BetterPlayerAsmsAudioTrack>? get betterPlayerAsmsAudioTracks =>
      _state.audioTracks;
  BetterPlayerAsmsAudioTrack? get betterPlayerAsmsAudioTrack =>
      _state.selectedAudioTrack;
  List<BetterPlayerSubtitlesSource> get betterPlayerSubtitlesSourceList =>
      _state.subtitlesSources;
  BetterPlayerSubtitlesSource? get betterPlayerSubtitlesSource =>
      _state.selectedSubtitleSource;
  List<BetterPlayerSubtitle> get subtitlesLines => _state.subtitles;
  GlobalKey? get betterPlayerGlobalKey => _betterPlayerGlobalKey;
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration =>
      betterPlayerConfiguration.controlsConfiguration;
  bool get controlsEnabled => !_state.controlsLocked;
  bool get controlsAlwaysVisible =>
      _state.controlsLocked && _state.controlsVisible;
  Stream<int?> get nextVideoTimeStream => _nextVideoTimeController.stream;
  Stream<BetterPlayerEvent> get eventStream => _state.eventStream;
  Stream<bool> get controlsVisibilityStream => _state.controlsVisibilityStream;
  BetterPlayerTranslations translations = BetterPlayerTranslations();
  BetterPlayerSubtitle? renderedSubtitle;

  // New convenience getters
  bool get isPlaying => _state.isPlaying;
  bool get isBuffering => _state.isBuffering;
  bool get hasError => _state.hasError;
  Duration get position => _state.position;
  Duration get duration => _state.duration;
  double get volume => _state.volume;
  double get playbackSpeed => _state.playbackSpeed;

  /// Setup data source
  Future<void> setupDataSource(BetterPlayerDataSource dataSource) async {
    await _logic.setupDataSource(dataSource);
  }

  /// Play video
  Future<void> play() async {
    if (_shouldHandleLifecycle() &&
        _appLifecycleState != AppLifecycleState.resumed) {
      _wasPlayingBeforePause = true;
      return;
    }
    await _logic.play();
  }

  /// Pause video
  Future<void> pause() async {
    await _logic.pause();
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _logic.seekTo(position);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    await _logic.setVolume(volume);
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _logic.setSpeed(speed);
  }

  /// Toggle fullscreen
  void toggleFullScreen() {
    _logic.toggleFullScreen();
  }

  /// Enter fullscreen
  void enterFullScreen() {
    _state.setFullScreen(true);
  }

  /// Exit fullscreen
  void exitFullScreen() {
    _state.setFullScreen(false);
  }

  /// Set looping
  Future<void> setLooping(bool looping) async {
    _state.setLooping(looping);
    await videoPlayerController?.setLooping(looping);
  }

  /// Is video playing
  bool? isVideoPlaying() => _state.isPlaying;

  /// Is video buffering
  bool? isVideoBuffering() => _state.isBuffering;

  /// Is video initialized
  bool? isVideoInitialized() => _state.isInitialized;

  /// Is live stream
  bool isLiveStream() => _state.isLive;

  /// Show/hide controls
  void setControlsVisibility(bool visible) {
    _state.setControlsVisible(visible, userInteraction: true);
  }

  /// Lock/unlock controls
  void setControlsEnabled(bool enabled) {
    _state.lockControls(!enabled);
  }

  /// Always show controls
  void setControlsAlwaysVisible(bool alwaysVisible) {
    _state.lockControls(alwaysVisible);
    if (alwaysVisible) {
      _state.setControlsVisible(true);
    }
  }

  /// Set track (quality)
  void setTrack(BetterPlayerAsmsTrack track) {
    _logic.setTrack(track);
  }

  /// Set audio track
  void setAudioTrack(BetterPlayerAsmsAudioTrack track) {
    _logic.setAudioTrack(track);
  }

  /// Setup subtitle source
  Future<void> setupSubtitleSource(
    BetterPlayerSubtitlesSource source, {
    bool sourceInitialize = false,
  }) async {
    await _logic.setupSubtitleSource(source);
  }

  /// Set resolution
  Future<void> setResolution(String url) async {
    final currentPosition = position;
    final wasPlaying = isPlaying;

    await pause();
    await setupDataSource(betterPlayerDataSource!.copyWith(url: url));
    await seekTo(currentPosition);

    if (wasPlaying) {
      await play();
    }

    _postEvent(BetterPlayerEvent(
      BetterPlayerEventType.changedResolution,
      parameters: {"url": url},
    ));
  }

  /// Retry data source
  Future<void> retryDataSource() async {
    await _logic.retry();
  }

  /// Enable PiP
  Future<void> enablePictureInPicture(GlobalKey playerKey) async {
    await _logic.enablePictureInPicture(playerKey);
  }

  /// Check PiP support
  Future<bool> isPictureInPictureSupported() async {
    final controller = videoPlayerController;
    if (controller == null) return false;
    return await controller.isPictureInPictureSupported() ?? false;
  }

  /// Lifecycle management
  void setAppLifecycleState(AppLifecycleState state) {
    if (!_shouldHandleLifecycle()) return;

    _appLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause == true && _isPlayerVisible) {
        play();
      }
    } else if (state == AppLifecycleState.paused) {
      _wasPlayingBeforePause ??= isPlaying;
      pause();
    }
  }

  /// Player visibility changed
  void onPlayerVisibilityChanged(double visibilityFraction) {
    _isPlayerVisible = visibilityFraction > 0;

    if (_shouldHandleLifecycle()) {
      if (betterPlayerConfiguration.playerVisibilityChangedBehavior != null) {
        betterPlayerConfiguration
            .playerVisibilityChangedBehavior!(visibilityFraction);
      } else {
        if (visibilityFraction == 0) {
          _wasPlayingBeforePause ??= isPlaying;
          pause();
        } else {
          if (_wasPlayingBeforePause == true && !isPlaying) {
            play();
          }
        }
      }
    }

    _postEvent(
        BetterPlayerEvent(BetterPlayerEventType.changedPlayerVisibility));
  }

  /// Add event listener
  void addEventsListener(Function(BetterPlayerEvent) listener) {
    _eventListeners.add(listener);
  }

  /// Remove event listener
  void removeEventsListener(Function(BetterPlayerEvent) listener) {
    _eventListeners.remove(listener);
  }

  /// Setup translations
  void setupTranslations(Locale locale) {
    final languageCode = locale.languageCode;
    translations = betterPlayerConfiguration.translations?.firstWhere(
          (t) => t.languageCode == languageCode,
          orElse: () => _getDefaultTranslations(locale),
        ) ??
        _getDefaultTranslations(locale);
  }

  /// Exit player
  void exitPlayer() {
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.exit));
  }

  /// Post event
  void postEvent(BetterPlayerEvent event) {
    _postEvent(event);
  }

  /// Playlist support
  void startNextVideoTimer() {
    if (betterPlayerPlaylistConfiguration == null) {
      throw StateError("Playlist configuration not set");
    }

    _nextVideoTime =
        betterPlayerPlaylistConfiguration!.nextVideoDelay.inSeconds;
    _nextVideoTimeController.add(_nextVideoTime);

    if (_nextVideoTime == 0) {
      return;
    }

    _nextVideoTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_nextVideoTime == 1) {
        _nextVideoTimer?.cancel();
        _nextVideoTimer = null;
      }
      _nextVideoTime = (_nextVideoTime ?? 0) - 1;
      _nextVideoTimeController.add(_nextVideoTime);
    });
  }

  void cancelNextVideoTimer() {
    _nextVideoTime = null;
    _nextVideoTimeController.add(null);
    _nextVideoTimer?.cancel();
    _nextVideoTimer = null;
  }

  void playNextVideo() {
    _nextVideoTime = 0;
    _nextVideoTimeController.add(0);
    _postEvent(BetterPlayerEvent(BetterPlayerEventType.changedPlaylistItem));
    cancelNextVideoTimer();
  }

  // Utility methods
  void setBetterPlayerGlobalKey(GlobalKey key) {
    _betterPlayerGlobalKey = key;
  }

  double? getAspectRatio() => _state.aspectRatio;

  void setMixWithOthers(bool mix) {
    videoPlayerController?.setMixWithOthers(mix);
  }

  Future<void> clearCache() async {
    await VideoPlayerController.clearCache();
  }

  Future<void> preCache(BetterPlayerDataSource dataSource) async {
    await videoPlayerController?.preCache(
      DataSource(
        sourceType: DataSourceType.network,
        uri: dataSource.url,
        headers: dataSource.headers,
        maxCacheSize: dataSource.cacheConfiguration?.maxCacheSize ?? 0,
        maxCacheFileSize: dataSource.cacheConfiguration?.maxCacheFileSize ?? 0,
        cacheKey: dataSource.cacheConfiguration?.key,
      ),
      dataSource.cacheConfiguration?.preCacheSize ?? 0,
    );
  }

  Future<void> stopPreCache(BetterPlayerDataSource dataSource) async {
    await VideoPlayerController.stopPreCache(
      dataSource.url,
      dataSource.cacheConfiguration?.key,
    );
  }

  // Private methods
  void _onStateChanged() {
    notifyListeners();
  }

  void _handleBusinessLogicEvent(BetterPlayerEvent event) {
    _postEvent(event);

    // Handle specific events
    if (event.betterPlayerEventType == BetterPlayerEventType.finished) {
      if (betterPlayerPlaylistConfiguration != null && _hasNextVideo()) {
        startNextVideoTimer();
      }
    }
  }

  bool _hasNextVideo() {
    // Implement based on playlist logic
    return false;
  }

  void _postEvent(BetterPlayerEvent event) {
    for (final listener in _eventListeners) {
      listener?.call(event);
    }
  }

  bool _shouldHandleLifecycle() {
    return betterPlayerConfiguration.handleLifecycle &&
        _state.dataSource?.notificationConfiguration?.showNotification != true;
  }

  BetterPlayerTranslations _getDefaultTranslations(Locale locale) {
    switch (locale.languageCode) {
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

  // Deprecated methods for backward compatibility
  bool get hasCurrentDataSourceStarted => _state.isInitialized;

  /// Dispose
  @override
  void dispose({bool forceDispose = false}) {
    if (!betterPlayerConfiguration.autoDispose && !forceDispose) {
      return;
    }

    if (!_isDisposed) {
      _isDisposed = true;
      _state.removeListener(_onStateChanged);
      _nextVideoTimer?.cancel();
      _nextVideoTimeController.close();
      _logic.dispose();
      _state.dispose();
      super.dispose();
    }
  }
}
