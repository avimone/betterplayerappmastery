// better_player_controls_base.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:better_player/better_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Base class for Better Player controls
/// Provides common functionality and reduces code duplication
abstract class BetterPlayerControlsBase<T extends StatefulWidget>
    extends State<T> {
  BetterPlayerController? _controller;
  late StreamSubscription _stateSubscription;
  late StreamSubscription _visibilitySubscription;
  Timer? _hideTimer;

  /// Subclasses must implement this to build their specific UI
  Widget buildControls(BuildContext context);

  @override
  void initState() {
    super.initState();
    _controller = BetterPlayerController.of(context);
    _setupListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newController = BetterPlayerController.of(context);
    if (_controller != newController) {
      _controller = newController;
      _setupListeners();
    }
  }

  @override
  void dispose() {
    _stateSubscription.cancel();
    _visibilitySubscription.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _setupListeners() {
    _stateSubscription.cancel();
    _visibilitySubscription.cancel();

    _stateSubscription = _controller!.state.addListener(() {
      if (mounted) setState(() {});
    }) as StreamSubscription;

    _visibilitySubscription =
        _controller!.controlsVisibilityStream.listen((visible) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildControls(context);
  }

  // Common getters
  BetterPlayerController get controller => _controller!;
  BetterPlayerState get state => controller.state;
  BetterPlayerConfiguration get config => controller.betterPlayerConfiguration;
  BetterPlayerControlsConfiguration get controlsConfig =>
      config.controlsConfiguration;
  BetterPlayerTranslations get translations => controller.translations;

  // Common control actions
  void onPlayPause() {
    if (state.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    _restartHideTimer();
  }

  void skipBack() {
    final currentPosition = state.position;
    final skipDuration = Duration(
      milliseconds: controlsConfig.backwardSkipTimeInMilliseconds,
    );
    final newPosition = currentPosition - skipDuration;
    controller
        .seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
    _restartHideTimer();
  }

  void skipForward() {
    final currentPosition = state.position;
    final skipDuration = Duration(
      milliseconds: controlsConfig.forwardSkipTimeInMilliseconds,
    );
    final newPosition = currentPosition + skipDuration;
    final maxPosition = state.duration;
    controller.seekTo(newPosition > maxPosition ? maxPosition : newPosition);
    _restartHideTimer();
  }

  void toggleFullscreen() {
    controller.toggleFullScreen();
    _restartHideTimer();
  }

  void toggleMute() {
    final currentVolume = state.volume;
    controller.setVolume(currentVolume > 0 ? 0.0 : 1.0);
    _restartHideTimer();
  }

  void onControlsTap() {
    if (state.controlsVisible) {
      controller.setControlsVisibility(false);
    } else {
      controller.setControlsVisibility(true);
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    if (!state.controlsLocked && state.controlsVisible) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          controller.setControlsVisibility(false);
        }
      });
    }
  }

  // Menu helpers
  void showOverflowMenu() {
    _showBottomSheet(_buildOverflowMenu());
  }

  void showQualitySelection() {
    if (state.tracks.isNotEmpty) {
      _showBottomSheet(_buildQualitySelection());
    }
  }

  void showAudioTrackSelection() {
    if (state.audioTracks.isNotEmpty) {
      _showBottomSheet(_buildAudioTrackSelection());
    }
  }

  void showSubtitlesSelection() {
    _showBottomSheet(_buildSubtitleSelection());
  }

  void showPlaybackSpeedSelection() {
    _showBottomSheet(_buildSpeedSelection());
  }

  // Menu builders
  Widget _buildOverflowMenu() {
    final items = <Widget>[];

    if (controlsConfig.enablePlaybackSpeed) {
      items.add(_buildMenuRow(
        icon: controlsConfig.playbackSpeedIcon,
        title: translations.overflowMenuPlaybackSpeed,
        onTap: () {
          Navigator.pop(context);
          showPlaybackSpeedSelection();
        },
      ));
    }

    if (controlsConfig.enableSubtitles) {
      items.add(_buildMenuRow(
        icon: controlsConfig.subtitlesIcon,
        title: translations.overflowMenuSubtitles,
        onTap: () {
          Navigator.pop(context);
          showSubtitlesSelection();
        },
      ));
    }

    if (controlsConfig.enableQualities && state.tracks.isNotEmpty) {
      items.add(_buildMenuRow(
        icon: controlsConfig.qualitiesIcon,
        title: translations.overflowMenuQuality,
        onTap: () {
          Navigator.pop(context);
          showQualitySelection();
        },
      ));
    }

    if (controlsConfig.enableAudioTracks && state.audioTracks.isNotEmpty) {
      items.add(_buildMenuRow(
        icon: controlsConfig.audioTracksIcon,
        title: translations.overflowMenuAudioTracks,
        onTap: () {
          Navigator.pop(context);
          showAudioTrackSelection();
        },
      ));
    }

    // Add custom items
    for (final item in controlsConfig.overflowMenuCustomItems) {
      items.add(_buildMenuRow(
        icon: item.icon,
        title: item.title,
        onTap: () {
          Navigator.pop(context);
          item.onClicked();
        },
      ));
    }

    return _buildMenuContainer(items);
  }

  Widget _buildQualitySelection() {
    final items = <Widget>[];

    for (final track in state.tracks) {
      final isSelected = track == state.selectedTrack;
      final name = _getTrackName(track);

      items.add(_buildMenuRow(
        title: name,
        isSelected: isSelected,
        onTap: () {
          Navigator.pop(context);
          controller.setTrack(track);
        },
      ));
    }

    return _buildMenuContainer(items);
  }

  Widget _buildAudioTrackSelection() {
    final items = <Widget>[];

    for (final track in state.audioTracks) {
      final isSelected = track == state.selectedAudioTrack;

      items.add(_buildMenuRow(
        title: track.label ?? translations.generalDefault,
        isSelected: isSelected,
        onTap: () {
          Navigator.pop(context);
          controller.setAudioTrack(track);
        },
      ));
    }

    return _buildMenuContainer(items);
  }

  Widget _buildSubtitleSelection() {
    final items = <Widget>[];

    for (final source in state.subtitlesSources) {
      final isSelected = source == state.selectedSubtitleSource;
      final name = source.type == BetterPlayerSubtitlesSourceType.none
          ? translations.generalNone
          : (source.name ?? translations.generalDefault);

      items.add(_buildMenuRow(
        title: name,
        isSelected: isSelected,
        onTap: () {
          Navigator.pop(context);
          controller.setupSubtitleSource(source);
        },
      ));
    }

    return _buildMenuContainer(items);
  }

  Widget _buildSpeedSelection() {
    final speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    final items = <Widget>[];

    for (final speed in speeds) {
      final isSelected = (state.playbackSpeed - speed).abs() < 0.01;

      items.add(_buildMenuRow(
        title: "${speed}x",
        isSelected: isSelected,
        onTap: () {
          Navigator.pop(context);
          controller.setSpeed(speed);
        },
      ));
    }

    return _buildMenuContainer(items);
  }

  Widget _buildMenuRow({
    IconData? icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: controlsConfig.overflowMenuIconsColor,
                size: 20,
              ),
              const SizedBox(width: 16),
            ] else if (isSelected) ...[
              const Icon(
                Icons.check,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 16),
            ] else ...[
              const SizedBox(width: 36),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : controlsConfig.overflowModalTextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuContainer(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: controlsConfig.overflowModalColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items,
      ),
    );
  }

  void _showBottomSheet(Widget content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: content,
      ),
    );
  }

  String _getTrackName(BetterPlayerAsmsTrack track) {
    if (track.height == 0 && track.width == 0 && track.bitrate == 0) {
      return translations.qualityAuto;
    }

    final width = track.width ?? 0;
    final height = track.height ?? 0;
    final bitrate = track.bitrate ?? 0;

    if (height > 0) {
      return "${height}p";
    } else if (width > 0 && height > 0) {
      return "${width}x${height}";
    } else if (bitrate > 0) {
      return BetterPlayerUtils.formatBitrate(bitrate);
    } else {
      return translations.generalDefault;
    }
  }

  // Common UI builders
  Widget buildPlayPauseButton({
    double? size,
    Color? color,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed ?? onPlayPause,
      icon: Icon(
        state.isPlaying ? controlsConfig.pauseIcon : controlsConfig.playIcon,
        size: size ?? controlsConfig.iconSize,
        color: color ?? controlsConfig.iconsColor,
      ),
    );
  }

  Widget buildFullscreenButton({
    double? size,
    Color? color,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed ?? toggleFullscreen,
      icon: Icon(
        state.isFullScreen
            ? controlsConfig.fullscreenDisableIcon
            : controlsConfig.fullscreenEnableIcon,
        size: size ?? controlsConfig.iconSize,
        color: color ?? controlsConfig.iconsColor,
      ),
    );
  }

  Widget buildMuteButton({
    double? size,
    Color? color,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      onPressed: onPressed ?? toggleMute,
      icon: Icon(
        state.volume > 0 ? controlsConfig.muteIcon : controlsConfig.unMuteIcon,
        size: size ?? controlsConfig.iconSize,
        color: color ?? controlsConfig.iconsColor,
      ),
    );
  }

  Widget buildProgressText() {
    final position = state.position;
    final duration = state.duration;

    return Text(
      "${BetterPlayerUtils.formatDuration(position)} / ${BetterPlayerUtils.formatDuration(duration)}",
      style: controlsConfig.timeBarStyle,
    );
  }

  Widget buildLoadingIndicator() {
    if (controlsConfig.loadingWidget != null) {
      return controlsConfig.loadingWidget!;
    }

    return CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(controlsConfig.loadingColor),
    );
  }

  Widget buildErrorWidget() {
    if (config.errorBuilder != null && state.hasError) {
      return config.errorBuilder!(context, state.error!.message);
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Platform.isIOS
                ? CupertinoIcons.exclamationmark_triangle
                : Icons.error,
            color: controlsConfig.iconsColor,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            state.error?.userFriendlyMessage ??
                translations.generalDefaultError,
            style: TextStyle(color: controlsConfig.textColor),
            textAlign: TextAlign.center,
          ),
          if (controlsConfig.enableRetry &&
              state.error?.isRecoverable == true) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => controller.retryDataSource(),
              child: Text(translations.generalRetry),
            ),
          ],
        ],
      ),
    );
  }
}
