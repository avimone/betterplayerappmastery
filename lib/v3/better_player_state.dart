// better_player_state.dart
import 'dart:async';
import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';

/// Centralized state management for Better Player
class BetterPlayerState extends ChangeNotifier {
  // Video state
  VideoPlayerValue? _videoValue;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _isFullScreen = false;
  bool _controlsVisible = true;
  bool _controlsLocked = false;

  // Data source
  BetterPlayerDataSource? _dataSource;

  // Tracks and subtitles
  List<BetterPlayerAsmsTrack> _tracks = [];
  BetterPlayerAsmsTrack? _selectedTrack;
  List<BetterPlayerAsmsAudioTrack> _audioTracks = [];
  BetterPlayerAsmsAudioTrack? _selectedAudioTrack;
  List<BetterPlayerSubtitlesSource> _subtitlesSources = [];
  BetterPlayerSubtitlesSource? _selectedSubtitleSource;
  List<BetterPlayerSubtitle> _subtitles = [];

  // Playback settings
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _looping = false;

  // Error handling
  BetterPlayerError? _error;
  int _retryCount = 0;

  // Configuration
  final BetterPlayerConfiguration configuration;

  // Streams for reactive updates
  final _playerEventController =
      StreamController<BetterPlayerEvent>.broadcast();
  final _controlsVisibilityController = StreamController<bool>.broadcast();
  Timer? _controlsTimer;

  BetterPlayerState({required this.configuration}) {
    _looping = configuration.looping;
  }

  // Getters
  VideoPlayerValue? get videoValue => _videoValue;
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  bool get isBuffering => _isBuffering;
  bool get isFullScreen => _isFullScreen;
  bool get controlsVisible => _controlsVisible;
  bool get controlsLocked => _controlsLocked;
  BetterPlayerDataSource? get dataSource => _dataSource;
  List<BetterPlayerAsmsTrack> get tracks => _tracks;
  BetterPlayerAsmsTrack? get selectedTrack => _selectedTrack;
  List<BetterPlayerAsmsAudioTrack> get audioTracks => _audioTracks;
  BetterPlayerAsmsAudioTrack? get selectedAudioTrack => _selectedAudioTrack;
  List<BetterPlayerSubtitlesSource> get subtitlesSources => _subtitlesSources;
  BetterPlayerSubtitlesSource? get selectedSubtitleSource =>
      _selectedSubtitleSource;
  List<BetterPlayerSubtitle> get subtitles => _subtitles;
  double get playbackSpeed => _playbackSpeed;
  double get volume => _volume;
  bool get looping => _looping;
  BetterPlayerError? get error => _error;
  Duration get position => _videoValue?.position ?? Duration.zero;
  Duration get duration => _videoValue?.duration ?? Duration.zero;
  double get aspectRatio => _videoValue?.aspectRatio ?? 16 / 9;
  Stream<BetterPlayerEvent> get eventStream => _playerEventController.stream;
  Stream<bool> get controlsVisibilityStream =>
      _controlsVisibilityController.stream;

  // Computed properties
  bool get hasError => _error != null;
  bool get isLive => _dataSource?.liveStream ?? false;
  bool get canPlay => _isInitialized && !hasError;
  double get bufferPercent {
    if (_videoValue == null || _videoValue!.duration == null) return 0.0;
    if (_videoValue!.buffered.isEmpty) return 0.0;

    final buffered = _videoValue!.buffered.last.end.inMilliseconds;
    final total = _videoValue!.duration!.inMilliseconds;
    return (buffered / total).clamp(0.0, 1.0);
  }

  // Video state updates
  void updateVideoValue(VideoPlayerValue value) {
    _videoValue = value;
    _isPlaying = value.isPlaying;
    _isBuffering = value.isBuffering;

    if (value.hasError && value.errorDescription != null) {
      _error = BetterPlayerError(
        type: ErrorType.playback,
        message: value.errorDescription!,
      );
    }

    if (value.initialized && !_isInitialized) {
      _isInitialized = true;
      _emitEvent(BetterPlayerEventType.initialized);
    }

    notifyListeners();
  }

  // Data source management
  void setDataSource(BetterPlayerDataSource dataSource) {
    _dataSource = dataSource;
    _isInitialized = false;
    _error = null;
    _retryCount = 0;
    _subtitlesSources.clear();
    _tracks.clear();
    _audioTracks.clear();
    notifyListeners();
  }

  // Playback control
  void setPlaying(bool playing) {
    if (_isPlaying != playing) {
      _isPlaying = playing;
      _emitEvent(
          playing ? BetterPlayerEventType.play : BetterPlayerEventType.pause);
      notifyListeners();
    }
  }

  void setBuffering(bool buffering) {
    if (_isBuffering != buffering) {
      _isBuffering = buffering;
      _emitEvent(buffering
          ? BetterPlayerEventType.bufferingStart
          : BetterPlayerEventType.bufferingEnd);
      notifyListeners();
    }
  }

  void setFullScreen(bool fullScreen) {
    if (_isFullScreen != fullScreen) {
      _isFullScreen = fullScreen;
      _emitEvent(fullScreen
          ? BetterPlayerEventType.openFullscreen
          : BetterPlayerEventType.hideFullscreen);
      notifyListeners();
    }
  }

  // Controls management
  void setControlsVisible(bool visible, {bool userInteraction = false}) {
    _controlsVisible = visible;
    _controlsVisibilityController.add(visible);

    if (userInteraction && visible && !_controlsLocked) {
      _startControlsTimer();
    } else {
      _cancelControlsTimer();
    }

    _emitEvent(visible
        ? BetterPlayerEventType.controlsVisible
        : BetterPlayerEventType.controlsHiddenEnd);
    notifyListeners();
  }

  void lockControls(bool locked) {
    _controlsLocked = locked;
    if (locked) {
      _cancelControlsTimer();
    }
    notifyListeners();
  }

  void _startControlsTimer() {
    _cancelControlsTimer();
    if (configuration.controlsConfiguration.controlsHideTime.inMilliseconds >
        0) {
      _controlsTimer = Timer(
        Duration(seconds: 3), // Make this configurable
        () => setControlsVisible(false),
      );
    }
  }

  void _cancelControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  // Track management
  void setTracks(List<BetterPlayerAsmsTrack> tracks) {
    _tracks = tracks;
    if (tracks.isNotEmpty && _selectedTrack == null) {
      _selectedTrack = tracks.first;
    }
    notifyListeners();
  }

  void selectTrack(BetterPlayerAsmsTrack track) {
    if (_selectedTrack != track) {
      _selectedTrack = track;
      _emitEvent(BetterPlayerEventType.changedTrack);
      notifyListeners();
    }
  }

  // Audio track management
  void setAudioTracks(List<BetterPlayerAsmsAudioTrack> tracks) {
    _audioTracks = tracks;
    if (tracks.isNotEmpty && _selectedAudioTrack == null) {
      _selectedAudioTrack = tracks.first;
    }
    notifyListeners();
  }

  void selectAudioTrack(BetterPlayerAsmsAudioTrack track) {
    if (_selectedAudioTrack != track) {
      _selectedAudioTrack = track;
      notifyListeners();
    }
  }

  // Subtitle management
  void setSubtitlesSources(List<BetterPlayerSubtitlesSource> sources) {
    _subtitlesSources = sources;
    // Add "None" option
    if (!sources.any((s) => s.type == BetterPlayerSubtitlesSourceType.none)) {
      sources.add(BetterPlayerSubtitlesSource(
        type: BetterPlayerSubtitlesSourceType.none,
        name: "None",
      ));
    }
    notifyListeners();
  }

  void selectSubtitleSource(BetterPlayerSubtitlesSource? source) {
    if (_selectedSubtitleSource != source) {
      _selectedSubtitleSource = source;
      _emitEvent(BetterPlayerEventType.changedSubtitles);
      notifyListeners();
    }
  }

  void updateSubtitles(List<BetterPlayerSubtitle> subtitles) {
    _subtitles = subtitles;
    notifyListeners();
  }

  // Playback settings
  void setPlaybackSpeed(double speed) {
    if (_playbackSpeed != speed) {
      _playbackSpeed = speed;
      _emitEvent(BetterPlayerEventType.setSpeed);
      notifyListeners();
    }
  }

  void setVolume(double volume) {
    if (_volume != volume) {
      _volume = volume.clamp(0.0, 1.0);
      _emitEvent(BetterPlayerEventType.setVolume);
      notifyListeners();
    }
  }

  void setLooping(bool looping) {
    if (_looping != looping) {
      _looping = looping;
      notifyListeners();
    }
  }

  // Error handling
  void setError(BetterPlayerError error) {
    _error = error;
    _emitEvent(BetterPlayerEventType.exception);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void incrementRetryCount() {
    _retryCount++;
    notifyListeners();
  }

  void resetRetryCount() {
    _retryCount = 0;
    notifyListeners();
  }

  bool get canRetry => _retryCount < 5; // Make this configurable

  // Event emission
  void _emitEvent(BetterPlayerEventType type,
      {Map<String, dynamic>? parameters}) {
    final event = BetterPlayerEvent(type, parameters: parameters);
    _playerEventController.add(event);
  }

  // Cleanup
  @override
  void dispose() {
    _cancelControlsTimer();
    _playerEventController.close();
    _controlsVisibilityController.close();
    super.dispose();
  }
}

/// Enhanced error class with more information
class BetterPlayerError {
  final ErrorType type;
  final String message;
  final String? code;
  final dynamic details;
  final DateTime timestamp;

  BetterPlayerError({
    required this.type,
    required this.message,
    this.code,
    this.details,
  }) : timestamp = DateTime.now();

  bool get isRecoverable {
    switch (type) {
      case ErrorType.network:
      case ErrorType.timeout:
        return true;
      case ErrorType.codec:
      case ErrorType.drm:
      case ErrorType.format:
        return false;
      case ErrorType.playback:
      case ErrorType.unknown:
        return true;
    }
  }

  String get userFriendlyMessage {
    switch (type) {
      case ErrorType.network:
        return "Connection error. Please check your internet.";
      case ErrorType.timeout:
        return "Request timed out. Please try again.";
      case ErrorType.codec:
        return "This video format is not supported.";
      case ErrorType.drm:
        return "License error. Unable to play protected content.";
      case ErrorType.format:
        return "Invalid video format.";
      case ErrorType.playback:
        return "Playback error occurred.";
      case ErrorType.unknown:
        return "An unexpected error occurred.";
    }
  }
}

enum ErrorType {
  network,
  timeout,
  codec,
  drm,
  format,
  playback,
  unknown,
}
